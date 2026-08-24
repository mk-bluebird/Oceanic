-- Repository: mk-bluebird/Prometheus-Praxis
-- Filename: lua/tools/corridor_sensor_safety_metrics.lua
-- Destination: lua/tools/

local Metrics = {}

local DEFAULT_HUBER_K = 1.345

local function is_finite_number(value)
    return type(value) == "number"
        and value == value
        and value ~= math.huge
        and value ~= -math.huge
end

local function clamp(value, minimum, maximum)
    if value < minimum then
        return minimum
    end

    if value > maximum then
        return maximum
    end

    return value
end

local function require_table(value, name)
    assert(type(value) == "table", name .. " must be a table")
end

local function require_finite(value, name)
    assert(is_finite_number(value), name .. " must be a finite number")
end

local function require_nonnegative(value, name)
    require_finite(value, name)
    assert(value >= 0, name .. " must be non-negative")
end

local function require_positive(value, name)
    require_finite(value, name)
    assert(value > 0, name .. " must be greater than zero")
end

local function require_vector3(value, name)
    require_table(value, name)
    assert(#value == 3, name .. " must contain exactly three coordinates")

    for index = 1, 3 do
        require_finite(value[index], name .. "[" .. index .. "]")
    end
end

local function dot(left, right)
    return left[1] * right[1]
        + left[2] * right[2]
        + left[3] * right[3]
end

local function subtract(left, right)
    return {
        left[1] - right[1],
        left[2] - right[2],
        left[3] - right[3],
    }
end

local function add(left, right)
    return {
        left[1] + right[1],
        left[2] + right[2],
        left[3] + right[3],
    }
end

local function scale(vector, scalar)
    return {
        vector[1] * scalar,
        vector[2] * scalar,
        vector[3] * scalar,
    }
end

local function squared_norm(vector)
    return dot(vector, vector)
end

local function euclidean_distance(left, right)
    return math.sqrt(squared_norm(subtract(left, right)))
end

local function matrix_vector_multiply(matrix, vector)
    return {
        matrix[1][1] * vector[1] + matrix[1][2] * vector[2] + matrix[1][3] * vector[3],
        matrix[2][1] * vector[1] + matrix[2][2] * vector[2] + matrix[2][3] * vector[3],
        matrix[3][1] * vector[1] + matrix[3][2] * vector[2] + matrix[3][3] * vector[3],
    }
end

local function identity_matrix3()
    return {
        { 1.0, 0.0, 0.0 },
        { 0.0, 1.0, 0.0 },
        { 0.0, 0.0, 1.0 },
    }
end

local function copy_matrix3(matrix)
    return {
        { matrix[1][1], matrix[1][2], matrix[1][3] },
        { matrix[2][1], matrix[2][2], matrix[2][3] },
        { matrix[3][1], matrix[3][2], matrix[3][3] },
    }
end

local function require_matrix3(matrix, name)
    require_table(matrix, name)
    assert(#matrix == 3, name .. " must have three rows")

    for row = 1, 3 do
        require_table(matrix[row], name .. "[" .. row .. "]")
        assert(#matrix[row] == 3, name .. "[" .. row .. "] must have three columns")

        for column = 1, 3 do
            require_finite(
                matrix[row][column],
                name .. "[" .. row .. "][" .. column .. "]"
            )
        end
    end
end

local function frobenius_identity_deviation(rotation)
    local total = 0.0

    for row = 1, 3 do
        for column = 1, 3 do
            local identity_value = row == column and 1.0 or 0.0
            local difference = rotation[row][column] - identity_value
            total = total + difference * difference
        end
    end

    return total
end

local function weighted_centroid(points, weights)
    local total_weight = 0.0
    local weighted_sum = { 0.0, 0.0, 0.0 }

    for index, point in ipairs(points) do
        local weight = weights[index]

        total_weight = total_weight + weight
        weighted_sum = add(weighted_sum, scale(point, weight))
    end

    assert(total_weight > 0, "sum of weights must be greater than zero")

    return scale(weighted_sum, 1.0 / total_weight), total_weight
end

local function estimate_translation(source_points, target_points, weights, rotation)
    local source_centroid = weighted_centroid(source_points, weights)
    local target_centroid = weighted_centroid(target_points, weights)
    local rotated_source_centroid = matrix_vector_multiply(rotation, source_centroid)

    return subtract(target_centroid, rotated_source_centroid)
end

--- SC-013: Evaluates normalized residuals under Huber loss. Callers provide
--- calibration parameters; this utility deliberately does not self-calibrate
--- or modify sensor configuration.
---@param input table
---@param huber_k number|nil
---@return table
function Metrics.corridor_calibration_model(input, huber_k)
    require_table(input, "corridor_calibration_input")

    local y = input.y
    local a = input.a
    local b = input.b
    local x_ref = input.x_ref
    local c = input.c
    local z_env = input.z_env
    local sigma = input.sigma

    require_finite(y, "corridor_calibration_input.y")
    require_finite(a, "corridor_calibration_input.a")
    require_finite(b, "corridor_calibration_input.b")
    require_finite(x_ref, "corridor_calibration_input.x_ref")
    require_finite(c, "corridor_calibration_input.c")
    require_finite(z_env, "corridor_calibration_input.z_env")
    require_positive(sigma, "corridor_calibration_input.sigma")

    huber_k = huber_k or DEFAULT_HUBER_K
    require_positive(huber_k, "huber_k")

    local predicted = a + b * x_ref + c * z_env
    local residual = y - predicted
    local normalized_residual = residual / sigma
    local absolute_normalized_residual = math.abs(normalized_residual)

    local huber_loss

    if absolute_normalized_residual <= huber_k then
        huber_loss = 0.5 * normalized_residual * normalized_residual
    else
        huber_loss = huber_k * (absolute_normalized_residual - 0.5 * huber_k)
    end

    return {
        object_id = "sc-013",
        name = "CorridorCalibrationModel",
        predicted_value = predicted,
        residual = residual,
        normalized_residual = normalized_residual,
        huber_loss = huber_loss,
        huber_k = huber_k,
        gross_fault_indicator = absolute_normalized_residual > huber_k,
        knowledge_factor = 0.70,
        eco_impact_value = 0.0,
        harm_risk = clamp(absolute_normalized_residual / (huber_k * 5.0), 0.0, 1.0),
        authority_effect = "none",
        interpretation =
            "Read-only residual assessment. A gross-fault indicator requests review; "
            .. "it does not automatically recalibrate, disable, or control any sensor.",
    }
end

--- SC-014: Evaluates a caller-supplied rigid transform and estimates the
--- centroid-aligned translation for the supplied rotation. The full optimal
--- rotation problem requires a robust SVD or quaternion eigensolver; this
--- module therefore reports objective value and validation diagnostics rather
--- than claiming unsupported rotation optimization.
---@param input table
---@return table
function Metrics.sensor_alignment_solver(input)
    require_table(input, "sensor_alignment_input")

    local source_points = input.source_points
    local target_points = input.target_points
    local weights = input.weights
    local rotation = input.rotation or identity_matrix3()
    local lambda = input.lambda or 0.0

    require_table(source_points, "sensor_alignment_input.source_points")
    require_table(target_points, "sensor_alignment_input.target_points")
    require_table(weights, "sensor_alignment_input.weights")
    require_matrix3(rotation, "sensor_alignment_input.rotation")
    require_nonnegative(lambda, "sensor_alignment_input.lambda")

    assert(#source_points >= 3, "at least three point pairs are required")
    assert(#source_points == #target_points, "source_points and target_points must match")
    assert(#source_points == #weights, "weights must match point count")

    for index = 1, #source_points do
        require_vector3(source_points[index], "source_points[" .. index .. "]")
        require_vector3(target_points[index], "target_points[" .. index .. "]")
        require_nonnegative(weights[index], "weights[" .. index .. "]")
    end

    local translation = estimate_translation(
        source_points,
        target_points,
        weights,
        rotation
    )

    local weighted_error_sum = 0.0
    local total_weight = 0.0

    for index = 1, #source_points do
        local transformed = add(
            matrix_vector_multiply(rotation, source_points[index]),
            translation
        )
        local distance = euclidean_distance(transformed, target_points[index])

        weighted_error_sum =
            weighted_error_sum + weights[index] * distance * distance
        total_weight = total_weight + weights[index]
    end

    assert(total_weight > 0, "at least one positive weight is required")

    local smoothness_penalty = lambda * frobenius_identity_deviation(rotation)
    local objective = weighted_error_sum + smoothness_penalty
    local weighted_rmse = math.sqrt(weighted_error_sum / total_weight)

    return {
        object_id = "sc-014",
        name = "SensorAlignmentSolver",
        rotation = copy_matrix3(rotation),
        translation = translation,
        weighted_rmse = weighted_rmse,
        weighted_error_sum = weighted_error_sum,
        smoothness_penalty = smoothness_penalty,
        objective = objective,
        point_pair_count = #source_points,
        knowledge_factor = #source_points >= 6 and 0.70 or 0.45,
        eco_impact_value = 0.0,
        harm_risk = clamp(weighted_rmse, 0.0, 1.0),
        authority_effect = "none",
        interpretation =
            "Evaluates a supplied rotation with centroid-aligned translation. "
            .. "It does not claim a globally optimal rotation; use a reviewed SVD or "
            .. "quaternion solver for production registration and independently verify residuals.",
    }
end

--- SC-015: Calculates a simplified average probability-of-failure-on-demand
--- scenario. All time values must use the same unit and the failure rate must
--- be expressed per that unit. This is decision support, not a safety case.
---@param input table
---@return table
function Metrics.automation_safety_pfd(input)
    require_table(input, "automation_safety_pfd_input")

    local failure_rate = input.failure_rate
    local proof_test_interval = input.proof_test_interval
    local mean_time_to_repair = input.mean_time_to_repair

    require_nonnegative(failure_rate, "automation_safety_pfd_input.failure_rate")
    require_nonnegative(
        proof_test_interval,
        "automation_safety_pfd_input.proof_test_interval"
    )
    require_nonnegative(
        mean_time_to_repair,
        "automation_safety_pfd_input.mean_time_to_repair"
    )

    local pfd_average =
        failure_rate * (proof_test_interval / 2.0 + mean_time_to_repair)

    local bounded_pfd = clamp(pfd_average, 0.0, 1.0)

    return {
        object_id = "sc-015",
        name = "AutomationSafetyPFD",
        pfd_average = bounded_pfd,
        unbounded_formula_result = pfd_average,
        failure_rate = failure_rate,
        proof_test_interval = proof_test_interval,
        mean_time_to_repair = mean_time_to_repair,
        required_unit_invariant =
            "failure_rate must be per the same time unit used by proof_test_interval and mean_time_to_repair",
        knowledge_factor = 0.50,
        eco_impact_value = 0.0,
        harm_risk = bounded_pfd,
        authority_effect = "none",
        interpretation =
            "Simplified PFD-average screening estimate. It omits diagnostic coverage, common-cause failure, "
            .. "test effectiveness, demand rate, redundancy, and systematic faults; do not use it as certification evidence.",
    }
end

return Metrics
