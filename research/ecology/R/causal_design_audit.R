# SPDX-License-Identifier: MIT OR Apache-2.0
# SOVEREIGN-ATTRIBUTION:
# bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
#
# Version: 0.4.0
# Dependency: dagitty, installed separately by the user.
# No automatic installation, network access, or file writes.
#
# This module audits graph assumptions. It does not estimate causal effects.

cd_abort <- function(code, message) {
  stop(structure(
    list(message = message, call = NULL, code = code),
    class = c("causal_design_error", "error", "condition")
  ))
}

cd_require <- function(condition, code, message) {
  if (length(condition) != 1L ||
      is.na(condition) || !condition) {
    cd_abort(code, message)
  }
}

cd_text <- function(value, label, scalar = FALSE, empty = FALSE) {
  cd_require(
    is.character(value) &&
      !anyNA(value) &&
      (empty || length(value) > 0L) &&
      all(nzchar(trimws(value))) &&
      (!scalar || length(value) == 1L),
    "invalid_text",
    paste("Invalid", label)
  )
}

cd_dependency <- function() {
  cd_require(
    requireNamespace("dagitty", quietly = TRUE),
    "missing_dependency",
    "Install dagitty separately before running this module."
  )
}

cd_plan <- function(question, exposure, outcome, target_population,
                    endpoint_definition, horizon_value, horizon_unit,
                    estimand, assumptions, provenance) {
  fields <- list(
    question = question,
    exposure = exposure,
    outcome = outcome,
    target_population = target_population,
    endpoint_definition = endpoint_definition,
    horizon_unit = horizon_unit,
    estimand = estimand,
    provenance = provenance
  )
  for (name in names(fields)) {
    cd_text(fields[[name]], name, scalar = TRUE)
  }

  cd_require(
    is.numeric(horizon_value) &&
      length(horizon_value) == 1L &&
      is.finite(horizon_value) &&
      horizon_value > 0,
    "invalid_horizon",
    "The endpoint horizon must be a positive finite number."
  )
  cd_require(
    horizon_unit %in% c("days", "months", "years"),
    "invalid_horizon_unit",
    "Use days, months, or years."
  )
  cd_require(
    estimand == "total_effect",
    "unsupported_estimand",
    "This release audits total-effect adjustment only."
  )
  cd_require(
    exposure != outcome,
    "invalid_endpoints",
    "Exposure and outcome must differ."
  )
  cd_text(assumptions, "assumptions")

  structure(
    c(fields, list(
      horizon_value = horizon_value,
      assumptions = assumptions,
      schema_version = "0.4.0"
    )),
    class = "causal_design_plan"
  )
}

cd_variable_table <- function(variables, graph_names) {
  fields <- c(
    "variable", "time_role", "data_role", "definition", "source"
  )
  cd_require(
    is.data.frame(variables) &&
      nrow(variables) > 0L &&
      all(fields %in% names(variables)),
    "invalid_variable_schema",
    "Variable metadata are incomplete."
  )
  for (name in fields) cd_text(variables[[name]], name)

  cd_require(
    !anyDuplicated(variables$variable) &&
      setequal(variables$variable, graph_names),
    "variable_mismatch",
    "Metadata must declare every graph variable exactly once."
  )
  cd_require(
    all(variables$time_role %in%
          c("baseline", "intervention", "post", "outcome")),
    "invalid_time_role",
    "Unrecognized temporal role."
  )
  cd_require(
    all(variables$data_role %in%
          c("observed", "latent", "observation_process")),
    "invalid_data_role",
    "Unrecognized data role."
  )
  invisible(TRUE)
}

cd_audit <- function(graph_text, plan, variables,
                     adjustment = character(),
                     maximum_sets = 100L) {
  cd_dependency()
  cd_text(graph_text, "graph_text", scalar = TRUE)
  cd_require(
    inherits(plan, "causal_design_plan"),
    "invalid_plan",
    "Create the research plan with cd_plan()."
  )
  cd_text(adjustment, "adjustment", empty = TRUE)
  cd_require(
    !anyDuplicated(adjustment),
    "duplicate_adjustment",
    "Adjustment variables must be unique."
  )
  cd_require(
    is.numeric(maximum_sets) &&
      length(maximum_sets) == 1L &&
      is.finite(maximum_sets) &&
      maximum_sets >= 1 &&
      maximum_sets <= 1000 &&
      maximum_sets == floor(maximum_sets),
    "invalid_limit",
    "maximum_sets must be an integer between 1 and 1000."
  )

  graph <- dagitty::dagitty(graph_text, layout = FALSE)
  cd_require(
    identical(dagitty::graphType(graph), "dag"),
    "unsupported_graph",
    "This release accepts DAGs only."
  )
  cd_require(
    isTRUE(dagitty::isAcyclic(graph)),
    "directed_cycle",
    "A causal DAG cannot contain a directed cycle; time-index feedback."
  )

  graph_names <- names(graph)
  cd_variable_table(variables, graph_names)
  cd_require(
    all(c(plan$exposure, plan$outcome, adjustment) %in% graph_names),
    "unknown_variable",
    "Exposure, outcome, and adjustment variables must exist in the graph."
  )
  cd_require(
    !any(adjustment %in% c(plan$exposure, plan$outcome)),
    "invalid_adjustment",
    "Do not include exposure or outcome in the adjustment set."
  )

  latent_names <- variables$variable[variables$data_role == "latent"]
  marked_latent <- dagitty::latents(graph)
  cd_require(
    setequal(latent_names, marked_latent),
    "latent_metadata_mismatch",
    "Graph latent markings and metadata must agree."
  )
  cd_require(
    !any(adjustment %in% latent_names),
    "unobserved_adjustment",
    "The proposed adjustment set contains an unobserved variable."
  )

  exposure_role <- variables$time_role[
    match(plan$exposure, variables$variable)
  ]
  outcome_role <- variables$time_role[
    match(plan$outcome, variables$variable)
  ]
  cd_require(
    exposure_role == "intervention" && outcome_role == "outcome",
    "endpoint_time_mismatch",
    "Exposure must have intervention role and outcome outcome role."
  )

  sufficient <- dagitty::isAdjustmentSet(
    graph,
    Z = adjustment,
    exposure = plan$exposure,
    outcome = plan$outcome
  )

  sets <- dagitty::adjustmentSets(
    graph,
    exposure = plan$exposure,
    outcome = plan$outcome,
    type = "minimal",
    effect = "total",
    max.results = maximum_sets
  )

  set_table <- if (!length(sets)) {
    data.frame(
      candidate = integer(),
      variables = character(),
      stringsAsFactors = FALSE
    )
  } else {
    data.frame(
      candidate = seq_along(sets),
      variables = vapply(
        sets,
        function(z) {
          if (!length(z)) "(empty set)" else paste(sort(z), collapse = ", ")
        },
        character(1)
      ),
      stringsAsFactors = FALSE
    )
  }

  descendants <- dagitty::descendants(
    graph, plan$exposure, proper = TRUE
  )
  outcome_ancestors <- dagitty::ancestors(
    graph, plan$outcome, proper = TRUE
  )
  causal_intermediates <- setdiff(
    intersect(descendants, outcome_ancestors),
    c(plan$exposure, plan$outcome)
  )

  adjusted_intermediates <- intersect(adjustment, causal_intermediates)
  adjusted_descendants <- intersect(adjustment, descendants)
  nonbaseline_adjustment <- adjustment[
    variables$time_role[match(adjustment, variables$variable)] != "baseline"
  ]

  warnings <- c(
    if (length(adjusted_intermediates)) {
      paste(
        "Adjusted causal intermediates:",
        paste(adjusted_intermediates, collapse = ", ")
      )
    },
    if (length(adjusted_descendants)) {
      paste(
        "Adjusted exposure descendants:",
        paste(adjusted_descendants, collapse = ", ")
      )
    },
    if (length(nonbaseline_adjustment)) {
      "Nonbaseline adjustment requires estimand-specific scientific review."
    },
    if (!length(sets)) {
      "No covariate adjustment set was returned for the declared graph."
    },
    if (length(sets) >= maximum_sets) {
      "Candidate-set listing may be truncated at the declared limit."
    }
  )

  structure(list(
    schema_version = "0.4.0",
    status = if (isTRUE(sufficient)) {
      "graphically_valid_under_declared_assumptions"
    } else {
      "not_graphically_valid_for_total_effect"
    },
    intervention_authorized = FALSE,
    causal_effect_estimated = FALSE,
    plan = plan,
    graph_text = graph_text,
    graph = graph,
    variable_metadata = variables,
    adjustment = adjustment,
    candidate_adjustment_sets = set_table,
    warnings = warnings,
    limitations = c(
      "The graph is a scientific assumption, not a verified causal mechanism.",
      "Graphical validity does not establish positivity or measurement quality.",
      "Observed and latent ecological outcomes must not be conflated.",
      "This audit does not correct selection or detection bias automatically.",
      "No direct-effect or mediation estimator is implemented.",
      "No medical recommendation or environmental action is authorized."
    ),
    reproducibility = list(
      R_version = R.version.string,
      platform = R.version$platform,
      dagitty_version = as.character(utils::packageVersion("dagitty"))
    )
  ), class = "causal_design_audit")
}

print.causal_design_audit <- function(x, ...) {
  cat("Causal-design audit\n")
  cat("Status:", x$status, "\n")
  cat("Effect estimated: FALSE\n")
  cat("Intervention authorized: FALSE\n")
  cat(
    "Proposed adjustment:",
    if (length(x$adjustment)) {
      paste(x$adjustment, collapse = ", ")
    } else "(empty set)",
    "\n"
  )
  print(x$candidate_adjustment_sets, row.names = FALSE)
  if (length(x$warnings)) {
    cat("Review notes:\n")
    cat(paste0("- ", x$warnings, collapse = "\n"), "\n")
  }
  invisible(x)
}

cd_restoration_example <- function() {
  plan <- cd_plan(
    question = "What is the total effect of intervention on later persistence?",
    exposure = "Intervention",
    outcome = "Persistence",
    target_population = "Sites eligible under the prespecified study protocol",
    endpoint_definition = paste(
      "A protocol-defined persistence measure;",
      "not a universal ecological recovery classification"
    ),
    horizon_value = 2,
    horizon_unit = "years",
    estimand = "total_effect",
    assumptions = c(
      "Baseline damage and habitat precede intervention.",
      "No omitted common causes beyond those represented.",
      "Chemical availability and metabolism are post-intervention.",
      "Outcome collection does not select sites on unmodelled causes."
    ),
    provenance = "Proposed ecological hypothesis; not environmental evidence."
  )

  graph_text <- paste(
    "dag {",
    "Intervention [exposure]",
    "Persistence [outcome]",
    "Damage -> Intervention",
    "Damage -> Persistence",
    "Habitat -> Intervention",
    "Habitat -> Persistence",
    "Intervention -> Chemistry",
    "Chemistry -> Metabolism",
    "Metabolism -> Persistence",
    "Intervention -> Persistence",
    "}"
  )

  variables <- data.frame(
    variable = c(
      "Intervention", "Persistence", "Damage",
      "Habitat", "Chemistry", "Metabolism"
    ),
    time_role = c(
      "intervention", "outcome", "baseline",
      "baseline", "post", "post"
    ),
    data_role = rep("observed", 6),
    definition = c(
      "Prespecified intervention exposure",
      "Persistence at the declared horizon",
      "Pre-intervention damage severity",
      "Pre-intervention habitat conditions",
      "Post-intervention chemical availability",
      "Post-intervention metabolic activity"
    ),
    source = rep("Proposed study variable; no observed values supplied", 6),
    stringsAsFactors = FALSE
  )

  cd_audit(
    graph_text, plan, variables,
    adjustment = c("Damage", "Habitat")
  )
}

cd_tests <- function() {
  cd_dependency()

  confounding <- dagitty::dagitty(
    "dag { A [exposure] Y [outcome] C -> A C -> Y A -> Y }"
  )
  stopifnot(
    !dagitty::isAdjustmentSet(confounding, character(), "A", "Y"),
    dagitty::isAdjustmentSet(confounding, "C", "A", "Y")
  )

  mediation <- dagitty::dagitty(
    "dag { A [exposure] Y [outcome] A -> M -> Y A -> Y }"
  )
  stopifnot(
    dagitty::isAdjustmentSet(mediation, character(), "A", "Y"),
    !dagitty::isAdjustmentSet(mediation, "M", "A", "Y")
  )

  selection <- dagitty::dagitty(
    "dag { A -> S <- U -> Y }"
  )
  stopifnot(
    dagitty::dseparated(selection, "A", "Y", character()),
    !dagitty::dseparated(selection, "A", "Y", "S")
  )

  descendant_selection <- dagitty::dagitty(
    "dag { A -> S <- U -> Y S -> R }"
  )
  stopifnot(
    dagitty::dseparated(descendant_selection, "A", "Y", character()),
    !dagitty::dseparated(descendant_selection, "A", "Y", "R")
  )

  latent_confounding <- dagitty::dagitty(
    "dag { A [exposure] Y [outcome] U [unobserved] U -> A U -> Y A -> Y }"
  )
  stopifnot(
    length(dagitty::adjustmentSets(
      latent_confounding, "A", "Y", type = "minimal"
    )) == 0L
  )

  example <- cd_restoration_example()
  stopifnot(
    example$status == "graphically_valid_under_declared_assumptions",
    !example$intervention_authorized,
    !example$causal_effect_estimated
  )

  invisible(TRUE)
}
