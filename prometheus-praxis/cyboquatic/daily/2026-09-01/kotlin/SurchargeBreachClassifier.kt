import kotlin.math.max

data class Event(
    val eventId: String,
    val canalNode: String,
    val flowLps: Double,
    val designLps: Double,
    val headM: Double,
    val freeboardM: Double,
    val bodMgL: Double,
    val tssMgL: Double,
    val cecMeq100g: Double,
    val downstreamM: Double
)

fun ranged(value: String, label: String, minimum: Double, maximum: Double): Double {
    val parsed = value.toDoubleOrNull() ?: throw IllegalArgumentException("invalid $label")
    require(parsed.isFinite() && parsed in minimum..maximum) { "invalid $label" }
    return parsed
}

fun parse(line: String): Event {
    val fields = line.split(',')
    require(fields.size == 10 && fields[0].isNotBlank() && fields[1].isNotBlank()) {
        "expected 10 non-empty CSV fields"
    }
    return Event(
        fields[0],
        fields[1],
        ranged(fields[2], "flow_lps", 0.0, 100000.0),
        ranged(fields[3], "design_lps", 0.001, 100000.0),
        ranged(fields[4], "head_m", 0.0, 100.0),
        ranged(fields[5], "freeboard_m", 0.0, 20.0),
        ranged(fields[6], "bod_mg_l", 0.0, 100000.0),
        ranged(fields[7], "tss_mg_l", 0.0, 100000.0),
        ranged(fields[8], "cec_meq_100g", 0.0, 500.0),
        ranged(fields[9], "downstream_m", 0.001, 100000.0)
    )
}

fun main() {
    try {
        val event = parse(readln())
        val surchargeRatio = event.flowLps / event.designLps
        val hydraulicScore = surchargeRatio + max(0.0, 0.50 - event.freeboardM)
        val ecologicalScore =
            event.bodMgL / 30.0 +
            event.tssMgL / 100.0 +
            max(0.0, 20.0 - event.cecMeq100g) / 20.0
        val blastRadiusM = event.downstreamM * (hydraulicScore / 2.0).coerceIn(0.10, 1.00)

        val status = when {
            surchargeRatio >= 1.30 || event.freeboardM <= 0.20 || ecologicalScore >= 3.00 -> "critical"
            surchargeRatio >= 1.10 || ecologicalScore >= 1.75 -> "elevated"
            else -> "contained"
        }

        val action = when (status) {
            "critical" -> "notify human operator; preserve safe flow and isolate only under approved local procedure"
            "elevated" -> "increase observation frequency; notify designated restoration operator"
            else -> "continue normal monitored operation"
        }

        println("event_id=${event.eventId}")
        println("canal_node=${event.canalNode}")
        println("surcharge_ratio=${"%.2f".format(surchargeRatio)}")
        println("hydraulic_score=${"%.2f".format(hydraulicScore)}")
        println("ecological_score=${"%.2f".format(ecologicalScore)}")
        println("blast_radius_m=${"%.2f".format(blastRadiusM)}")
        println("containment_status=$status")
        println("operator_action=$action")
    } catch (exception: Exception) {
        System.err.println("input_error=${exception.message ?: "invalid input"}")
    }
}
