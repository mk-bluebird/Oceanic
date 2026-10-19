// src/environment/urban-heat-contrast.mjs
// SPDX-License-Identifier: MIT OR Apache-2.0
// Runtime target: Node.js 22+ or a modern ES-module browser environment.
//
// Pure calculation over bounded primitive JSON text.
// No sensing, municipal control, location tracking, or personal-data intake.
// JSON.parse collapses duplicate keys; raw duplicate auditing is out of scope.
// Temperature bounds are input limits, not safety or comfort thresholds.

export const LIMITS = Object.freeze({
  input_characters: 8192,
  minimum_temperature_c: -100,
  maximum_temperature_c: 100
});

const MEASUREMENT_KINDS = Object.freeze([
  "AIR_TEMPERATURE",
  "SURFACE_TEMPERATURE"
]);

function exactFields(value, fields) {
  return (
    value !== null &&
    typeof value === "object" &&
    !Array.isArray(value) &&
    Object.keys(value).length === fields.length &&
    fields.every((field) => Object.hasOwn(value, field))
  );
}

function validTemperature(value) {
  return (
    typeof value === "number" &&
    Number.isFinite(value) &&
    value >= LIMITS.minimum_temperature_c &&
    value <= LIMITS.maximum_temperature_c
  );
}

function freezeOwned(value) {
  if (value !== null && typeof value === "object") {
    for (const nested of Object.values(value)) {
      freezeOwned(nested);
    }
    Object.freeze(value);
  }

  return value;
}

export function testUrbanHeatContrast(json_text) {
  const issues = [];

  let measurementKind = null;
  let heatIslandContrast = null;
  let interventionContrast = null;

  function add(code, path) {
    issues.push({ code, path });
  }

  function finish() {
    return freezeOwned({
      record_kind: "UrbanHeatContrastReport",
      report_version: 1,
      record_id: null,
      recorded_at_utc: null,
      assessment_status:
        issues.length === 0 ? "CHECKS_PASSED" : "REJECTED",
      calculation_status:
        issues.length === 0 ? "COMPUTED" : "NOT_COMPUTED",
      measurement_kind: measurementKind,
      temperature_unit: "CELSIUS",
      heat_island_contrast: heatIslandContrast,
      intervention_contrast: interventionContrast,
      input_authenticity_verified: false,
      measurement_comparability_verified: false,
      uncertainty_propagated: false,
      causal_effect_established: false,
      exposure_safety_assessed: false,
      action_dispatched: false,
      issues
    });
  }

  if (
    typeof json_text !== "string" ||
    json_text.length === 0 ||
    json_text.length > LIMITS.input_characters
  ) {
    add("INPUT_TEXT_INVALID", "$");
    return finish();
  }

  let input;

  try {
    input = JSON.parse(json_text);
  } catch {
    add("JSON_PARSE_FAILED", "$");
    return finish();
  }

  if (
    !exactFields(input, [
      "protocol_version",
      "measurement_kind",
      "heat_island",
      "intervention"
    ]) ||
    input.protocol_version !== 1 ||
    !MEASUREMENT_KINDS.includes(input.measurement_kind) ||
    (input.heat_island === null && input.intervention === null)
  ) {
    add("REQUEST_SHAPE_INVALID", "$");
    return finish();
  }

  const definitions = [
    ["heat_island", ["urban_c", "rural_c"]],
    ["intervention", [
      "treated_before_c",
      "treated_after_c",
      "comparison_before_c",
      "comparison_after_c"
    ]]
  ];

  for (const [section, fields] of definitions) {
    const values = input[section];

    if (values === null) continue;

    if (!exactFields(values, fields)) {
      add("MEASUREMENT_SHAPE_INVALID", `$.${section}`);
      continue;
    }

    for (const field of fields) {
      if (!validTemperature(values[field])) {
        add("TEMPERATURE_INVALID", `$.${section}.${field}`);
      }
    }
  }

  if (issues.length > 0) return finish();

  measurementKind = input.measurement_kind;

  if (input.heat_island !== null) {
    heatIslandContrast = {
      urban_minus_rural_c:
        input.heat_island.urban_c - input.heat_island.rural_c,
      interpretation: "SUPPLIED_URBAN_REFERENCE_CONTRAST"
    };
  }

  if (input.intervention !== null) {
    const values = input.intervention;

    const treatedChange =
      values.treated_after_c - values.treated_before_c;

    const comparisonChange =
      values.comparison_after_c - values.comparison_before_c;

    const differenceInDifferences =
      treatedChange - comparisonChange;

    interventionContrast = {
      treated_change_c: treatedChange,
      comparison_change_c: comparisonChange,
      difference_in_differences_c: differenceInDifferences,
      positive_for_cooling_contrast_c: -differenceInDifferences,
      interpretation:
        "ARITHMETIC_COMPARISON_NOT_CAUSAL_ATTRIBUTION"
    };
  }

  return finish();
}

export function runSelfTests() {
  const checks = [];

  function evaluate(intervention, heat_island = null) {
    return testUrbanHeatContrast(JSON.stringify({
      protocol_version: 1,
      measurement_kind: "AIR_TEMPERATURE",
      heat_island,
      intervention
    }));
  }

  function check(name, expected, action) {
    let state = "NOT_EXECUTED";
    let observed = null;
    let error = null;

    try {
      state = "EXECUTED";
      const value = action();

      if (typeof value !== "boolean") {
        error = "OBSERVATION_TYPE_UNSUPPORTED";
      } else {
        observed = value;
      }
    } catch {
      error = "CHECK_THREW";
    }

    checks.push({
      name,
      execution_state: state,
      expected,
      observed,
      error,
      assessment_status:
        error === null && observed === expected
          ? "CHECKS_PASSED"
          : "REJECTED"
    });
  }

  check("urban-reference-contrast", true, () => {
    const report = evaluate(null, { urban_c: 38, rural_c: 34 });
    return report.heat_island_contrast.urban_minus_rural_c === 4;
  });

  check("control-adjusted-cooling", true, () => {
    const report = evaluate({
      treated_before_c: 40,
      treated_after_c: 36,
      comparison_before_c: 38,
      comparison_after_c: 37
    });

    return (
      report.intervention_contrast
        .positive_for_cooling_contrast_c === 3 &&
      report.causal_effect_established === false
    );
  });

  check("comparison-cools-more", true, () => {
    const report = evaluate({
      treated_before_c: 40,
      treated_after_c: 39,
      comparison_before_c: 38,
      comparison_after_c: 35
    });

    return report.intervention_contrast
      .positive_for_cooling_contrast_c === -2;
  });

  check("unknown-temperature-not-coerced", true, () => {
    const report = evaluate(null, { urban_c: null, rural_c: 34 });
    return report.issues[0]?.code === "TEMPERATURE_INVALID";
  });

  check("unsupported-mixed-kind-rejected", true, () => {
    const report = testUrbanHeatContrast(JSON.stringify({
      protocol_version: 1,
      measurement_kind: "MIXED_AIR_AND_SURFACE",
      heat_island: { urban_c: 40, rural_c: 34 },
      intervention: null
    }));

    return report.issues[0]?.code === "REQUEST_SHAPE_INVALID";
  });

  const executedCount = checks.filter(
    (entry) => entry.execution_state === "EXECUTED"
  ).length;

  return freezeOwned({
    record_kind: "UrbanHeatContrastSelfTestReport",
    execution_state:
      executedCount === 0
        ? "NOT_EXECUTED"
        : executedCount === checks.length
          ? "EXECUTED"
          : "PARTIAL",
    assessment_status: checks.every(
      (entry) => entry.assessment_status === "CHECKS_PASSED"
    ) ? "CHECKS_PASSED" : "REJECTED",
    limits: LIMITS,
    checks,
    scope: "TEMPERATURE_CONTRAST_ARITHMETIC_ONLY"
  });
}
