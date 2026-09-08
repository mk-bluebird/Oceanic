#![forbid(unsafe_code)]

use serde::Serialize;

pub const SCALE: u32 = 10_000;
pub const EVIDENCE_MAX: u32 = SCALE;
pub const RISK_MAX: u32 = SCALE;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
pub struct KerInput {
    pub evidence: u32,
    pub risk: u32,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
pub struct KerScore {
    pub scaled: u32,
}

impl KerScore {
    pub const fn zero() -> Self {
        Self { scaled: 0 }
    }

    pub const fn one() -> Self {
        Self { scaled: SCALE }
    }

    pub const fn as_ratio(self) -> f64 {
        self.scaled as f64 / SCALE as f64
    }
}

pub const fn clamp_to_scale(value: u32) -> u32 {
    if value > SCALE {
        SCALE
    } else {
        value
    }
}

pub const fn score(input: KerInput) -> KerScore {
    let evidence = clamp_to_scale(input.evidence);
    let risk = clamp_to_scale(input.risk);
    let safety_factor = SCALE - risk;
    let product = evidence as u64 * safety_factor as u64;

    KerScore {
        scaled: (product / SCALE as u64) as u32,
    }
}

pub const fn evidence_monotone(evidence_low: u32, evidence_high: u32, risk: u32) -> bool {
    evidence_low > evidence_high
        || score(KerInput {
            evidence: evidence_low,
            risk,
        })
        .scaled
            <= score(KerInput {
                evidence: evidence_high,
                risk,
            })
            .scaled
}

pub const fn risk_antitone(evidence: u32, risk_low: u32, risk_high: u32) -> bool {
    risk_low > risk_high
        || score(KerInput {
            evidence,
            risk: risk_high,
        })
        .scaled
            <= score(KerInput {
                evidence,
                risk: risk_low,
            })
            .scaled
}

pub const fn score_is_bounded(evidence: u32, risk: u32) -> bool {
    score(KerInput { evidence, risk }).scaled <= SCALE
}

pub const fn evidence_saturates(evidence: u32, risk: u32) -> bool {
    evidence <= SCALE
        || score(KerInput { evidence, risk })
            == score(KerInput {
                evidence: SCALE,
                risk,
            })
}

pub const fn risk_saturates(evidence: u32, risk: u32) -> bool {
    risk <= SCALE
        || score(KerInput { evidence, risk }) == KerScore::zero()
}

pub const fn favorable_composition_monotone(
    evidence_low: u32,
    evidence_high: u32,
    risk_low: u32,
    risk_high: u32,
) -> bool {
    evidence_low > evidence_high
        || risk_low > risk_high
        || score(KerInput {
            evidence: evidence_low,
            risk: risk_high,
        })
        .scaled
            <= score(KerInput {
                evidence: evidence_high,
                risk: risk_low,
            })
            .scaled
}

#[cfg(kani)]
mod proofs {
    use super::*;

    #[kani::proof]
    fn score_never_exceeds_scale() {
        let evidence: u32 = kani::any();
        let risk: u32 = kani::any();

        kani::assert(
            score_is_bounded(evidence, risk),
            "K-E-R score must remain in [0, SCALE].",
        );
    }

    #[kani::proof]
    fn evidence_is_monotone() {
        let evidence_low: u32 = kani::any();
        let evidence_high: u32 = kani::any();
        let risk: u32 = kani::any();

        kani::assert(
            evidence_monotone(evidence_low, evidence_high, risk),
            "Increasing evidence must not lower K when risk is fixed.",
        );
    }

    #[kani::proof]
    fn risk_is_antitone() {
        let evidence: u32 = kani::any();
        let risk_low: u32 = kani::any();
        let risk_high: u32 = kani::any();

        kani::assert(
            risk_antitone(evidence, risk_low, risk_high),
            "Increasing risk must not raise K when evidence is fixed.",
        );
    }

    #[kani::proof]
    fn evidence_input_saturates() {
        let evidence: u32 = kani::any();
        let risk: u32 = kani::any();

        kani::assert(
            evidence_saturates(evidence, risk),
            "Evidence values beyond SCALE must saturate.",
        );
    }

    #[kani::proof]
    fn risk_input_saturates() {
        let evidence: u32 = kani::any();
        let risk: u32 = kani::any();

        kani::assert(
            risk_saturates(evidence, risk),
            "Risk values beyond SCALE must produce the zero score.",
        );
    }

    #[kani::proof]
    fn favorable_composition_is_monotone() {
        let evidence_low: u32 = kani::any();
        let evidence_high: u32 = kani::any();
        let risk_low: u32 = kani::any();
        let risk_high: u32 = kani::any();

        kani::assert(
            favorable_composition_monotone(evidence_low, evidence_high, risk_low, risk_high),
            "More evidence plus no more risk must not lower K.",
        );
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn known_score_is_deterministic() {
        let result = score(KerInput {
            evidence: 8_000,
            risk: 2_500,
        });

        assert_eq!(result.scaled, 6_000);
        assert_eq!(result.as_ratio(), 0.6);
    }

    #[test]
    fn saturation_is_deterministic() {
        assert_eq!(
            score(KerInput {
                evidence: SCALE + 1,
                risk: 0,
            }),
            KerScore::one()
        );

        assert_eq!(
            score(KerInput {
                evidence: SCALE,
                risk: SCALE + 1,
            }),
            KerScore::zero()
        );
    }
}
