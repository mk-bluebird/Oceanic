package augmented_hub.honey_bee_colony_stress_non_ranking

default allow := false

prohibited_fields := {
    "beekeeper_name",
    "beekeeper_id",
    "beekeeper_email",
    "beekeeper_phone",
    "beekeeper_address",
    "apiary_address",
    "hive_serial_number",
    "precise_latitude",
    "precise_longitude",
    "device_id",
    "advertising_id",
    "ip_address",
    "insurance_status",
    "buyer_score",
    "certification_score",
    "regulatory_score",
    "enforcement_priority",
    "beekeeper_ranking",
    "apiary_ranking",
    "colony_ranking",
    "pesticide_authorization",
    "diagnosis",
    "disease_determination",
    "colony_health_certification",
    "individual_hive_tracking",
    "individual_apiary_publication"
}

allowed_purposes := {
    "managed_pollinator_support_planning",
    "ecological_restoration",
    "sustainable_agriculture_planning",
    "beekeeper_voluntary_decision_support",
    "public_ecological_education"
}

allowed_output_kinds := {
    "component_conditions",
    "component_confidence",
    "interaction_watch_flag",
    "voluntary_support_actions",
    "limitations",
    "aggregate_stewardship_summary"
}

contains_prohibited_field(value) if {
    is_object(value)
    some key
    value[key]
    prohibited_fields[key]
}

contains_prohibited_field(value) if {
    is_object(value)
    some key
    contains_prohibited_field(value[key])
}

contains_prohibited_field(value) if {
    is_array(value)
    some index
    contains_prohibited_field(value[index])
}

has_required_constraints if {
    input.rights_and_stewardship_constraints.beekeeper_identity_collection == false
    input.rights_and_stewardship_constraints.precise_hive_location_collection == false
    input.rights_and_stewardship_constraints.individual_hive_tracking == false
    input.rights_and_stewardship_constraints.pesticide_authorization == false
    input.rights_and_stewardship_constraints.enforcement_use == false
    input.rights_and_stewardship_constraints.automated_colony_management == false
    input.rights_and_stewardship_constraints.voluntary_input_only == true
    input.rights_and_stewardship_constraints.human_or_beekeeper_review_required == true
}

has_component_first_output if {
    input.stress_components.heat_stress
    input.stress_components.forage_gap
    input.stress_components.water_stress
    input.stress_components.pesticide_exposure_context
    input.stress_components.pest_and_pathogen_context
    input.honey_bee_colony_stress_index.confidence_0_to_1 >= 0
}

has_required_non_diagnostic_flags if {
    input.honey_bee_colony_stress_index.not_a_veterinary_diagnosis == true
    input.honey_bee_colony_stress_index.not_a_colony_certification == true
    input.honey_bee_colony_stress_index.not_a_pesticide_authorization == true
}

has_allowed_purpose if {
    allowed_purposes[input.purpose]
}

has_aggregate_publication_safeguard if {
    input.publication_controls.minimum_independent_reporting_units >= 5
    input.publication_controls.precise_location_disclosure == false
    input.publication_controls.raw_observation_release == false
    input.publication_controls.ranking_output == false
}

all_actions_require_review if {
    every action in input.recommended_support_actions {
        action.human_or_beekeeper_review_required == true
        action.non_disturbance_check == true
        action.label_compliance_required == true
    }
}

allow if {
    has_allowed_purpose
    not contains_prohibited_field(input)
    has_required_constraints
    has_component_first_output
    has_required_non_diagnostic_flags
    has_aggregate_publication_safeguard
    all_actions_require_review
}

deny_reasons contains "beekeeper identity, precise apiary location, ranking, certification, insurance, enforcement, diagnosis, or individual tracking data is prohibited" if {
    contains_prohibited_field(input)
}

deny_reasons contains "purpose is outside voluntary pollinator support, restoration, sustainable agriculture, or public education" if {
    not has_allowed_purpose
}

deny_reasons contains "required privacy, voluntary-input, non-enforcement, and human-review constraints are incomplete" if {
    not has_required_constraints
}

deny_reasons contains "assessment must expose component-level conditions and confidence before any summary score" if {
    not has_component_first_output
}

deny_reasons contains "assessment must state that it is not a diagnosis, certification, or pesticide authorization" if {
    not has_required_non_diagnostic_flags
}

deny_reasons contains "public aggregate release requires k-anonymity, no precise locations, no raw observations, and no rankings" if {
    not has_aggregate_publication_safeguard
}

deny_reasons contains "every suggested action requires human or beekeeper review, non-disturbance protection, and product-label compliance" if {
    not all_actions_require_review
}
