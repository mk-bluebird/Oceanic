// src/security/temporal-capability.mjs
// SPDX-License-Identifier: MIT OR Apache-2.0
// Runtime target: Node.js 22+ or a modern ES-module browser environment.
//
// Pure point-in-time assessment over bounded primitive JSON text.
// All timestamps and bounds use the same externally defined epoch and unit.
// No clock synchronization, authorization grant, dispatch, or persistence.
// JSON.parse collapses duplicate keys; raw duplicate auditing is out of scope.

const MAX_INPUT_CHARACTERS = 8192;
const MAX_TIMESTAMP = Number.MAX_SAFE_INTEGER;
const IDENTIFIER = /^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$/;

function exactFields(value, fields) {
  return (
    value !== null &&
    typeof value === "object" &&
    !Array.isArray(value) &&
    Object.keys(value).length === fields.length &&
    fields.every((field) => Object.hasOwn(value, field))
  );
}

function timestamp(value) {
  return (
    Number.isSafeInteger(value) &&
    !Object.is(value, -0) &&
    value >= 0 &&
    value <= MAX_TIMESTAMP
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

export function testTemporalCapability(json_text) {
  const issues = [];
  let capabilityId = null;
  let temporalClearance = null;
  let assessmentStatus = "REJECTED";

  function add(code, path) {
    issues.push({ code, path });
  }

  function finish() {
    return freezeOwned({
      record_kind: "TemporalCapabilityReport",
      report_version: 1,
      record_id: null,
      recorded_at_utc: null,
      capability_id: capabilityId,
      assessment_status: assessmentStatus,
      temporal_clearance: temporalClearance,
      validity_semantics: "HALF_OPEN_INTERVAL",
      assessment_scope: "POINT_IN_TIME_FROM_SUPPLIED_BOUNDS",
      clock_soundness_verified: false,
      consent_authenticity_verified: false,
      consent_freshness_verified: false,
      permission_granted: false,
      operation_dispatched: false,
      issues
    });
  }

  if (
    typeof json_text !== "string" ||
    json_text.length === 0 ||
    json_text.length > MAX_INPUT_CHARACTERS
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
      "capability",
      "clock",
      "maximum_uncertainty"
    ]) ||
    input.protocol_version !== 1 ||
    !timestamp(input.maximum_uncertainty)
  ) {
    add("REQUEST_SHAPE_INVALID", "$");
    return finish();
  }

  const cap = input.capability;
  const clock = input.clock;

  if (
    !exactFields(cap, [
      "id", "granted", "consent_current", "not_before", "expires_at"
    ]) ||
    typeof cap.id !== "string" ||
    !IDENTIFIER.test(cap.id) ||
    typeof cap.granted !== "boolean" ||
    ![true, false, null].includes(cap.consent_current) ||
    !timestamp(cap.not_before) ||
    !timestamp(cap.expires_at) ||
    cap.not_before >= cap.expires_at
  ) {
    add("CAPABILITY_SHAPE_INVALID", "$.capability");
    return finish();
  }

  if (
    !exactFields(clock, ["status", "earliest", "latest"]) ||
    !["BOUNDED", "UNAVAILABLE"].includes(clock.status)
  ) {
    add("CLOCK_SHAPE_INVALID", "$.clock");
    return finish();
  }

  if (clock.status === "UNAVAILABLE") {
    if (clock.earliest !== null || clock.latest !== null) {
      add("UNAVAILABLE_CLOCK_REQUIRES_NULL_BOUNDS", "$.clock");
      return finish();
    }
  } else if (
    !timestamp(clock.earliest) ||
    !timestamp(clock.latest) ||
    clock.earliest > clock.latest
  ) {
    add("CLOCK_BOUNDS_INVALID", "$.clock");
    return finish();
  }

  capabilityId = cap.id;

  if (!cap.granted || cap.consent_current === false) {
    temporalClearance = false;
    add("GRANT_OR_CONSENT_NOT_ACTIVE", "$.capability");
    return finish();
  }

  if (
    cap.consent_current === null ||
    clock.status === "UNAVAILABLE"
  ) {
    assessmentStatus = "REVIEW_REQUIRED";
    add("REQUIRED_TEMPORAL_EVIDENCE_UNAVAILABLE", "$");
    return finish();
  }

  const width = clock.latest - clock.earliest;

  if (width > input.maximum_uncertainty) {
    assessmentStatus = "REVIEW_REQUIRED";
    add("CLOCK_UNCERTAINTY_EXCEEDS_POLICY", "$.clock");
    return finish();
  }

  temporalClearance =
    clock.earliest >= cap.not_before &&
    clock.latest < cap.expires_at;

  if (temporalClearance) {
    assessmentStatus = "CHECKS_PASSED";
  } else {
    add("VALIDITY_NOT_ESTABLISHED_FOR_ENTIRE_BOUND", "$.clock");
  }

  return finish();
}

export function runSelfTests() {
  const checks = [];

  function fixture() {
    return {
      protocol_version: 1,
      maximum_uncertainty: 4,
      capability: {
        id: "capability-A",
        granted: true,
        consent_current: true,
        not_before: 100,
        expires_at: 200
      },
      clock: {
        status: "BOUNDED",
        earliest: 150,
        latest: 154
      }
    };
  }

  function check(name, expected, mutate) {
    let observed = null;
    let error = null;
    let state = "NOT_EXECUTED";

    try {
      state = "EXECUTED";
      const input = fixture();
      mutate(input);

      const report = testTemporalCapability(JSON.stringify(input));
      observed = report.issues[0]?.code ?? report.assessment_status;
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

  check("bounded-validity", "CHECKS_PASSED", (input) => {
    input.clock.earliest = 150;
  });

  check(
    "expiry-boundary-is-exclusive",
    "VALIDITY_NOT_ESTABLISHED_FOR_ENTIRE_BOUND",
    (input) => {
      input.clock.earliest = 198;
      input.clock.latest = 200;
    }
  );

  check(
    "not-before-uses-earliest",
    "VALIDITY_NOT_ESTABLISHED_FOR_ENTIRE_BOUND",
    (input) => {
      input.clock.earliest = 99;
      input.clock.latest = 101;
    }
  );

  check(
    "unknown-consent-requires-review",
    "REQUIRED_TEMPORAL_EVIDENCE_UNAVAILABLE",
    (input) => {
      input.capability.consent_current = null;
    }
  );

  check(
    "logical-order-cannot-replace-clock",
    "REQUIRED_TEMPORAL_EVIDENCE_UNAVAILABLE",
    (input) => {
      input.clock = {
        status: "UNAVAILABLE",
        earliest: null,
        latest: null
      };
    }
  );

  check(
    "uncertainty-bound-enforced",
    "CLOCK_UNCERTAINTY_EXCEEDS_POLICY",
    (input) => {
      input.clock.latest = 155;
    }
  );

  const executedCount = checks.filter(
    (entry) => entry.execution_state === "EXECUTED"
  ).length;

  return freezeOwned({
    record_kind: "TemporalCapabilitySelfTestReport",
    execution_state:
      executedCount === 0
        ? "NOT_EXECUTED"
        : executedCount === checks.length
          ? "EXECUTED"
          : "PARTIAL",
    assessment_status: checks.every(
      (entry) => entry.assessment_status === "CHECKS_PASSED"
    ) ? "CHECKS_PASSED" : "REJECTED",
    checks,
    scope: "SUPPLIED_BOUND_CALCULATIONS_ONLY"
  });
}
