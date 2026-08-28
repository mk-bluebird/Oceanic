from __future__ import annotations

from dataclasses import dataclass
from math import exp, isfinite, log
from random import Random
from typing import Sequence


def _finite_nonnegative(name: str, value: float) -> None:
    if not isfinite(value) or value < 0.0:
        raise ValueError(f"{name} must be finite and non-negative.")


def _unit_interval(name: str, value: float) -> None:
    if not isfinite(value) or not 0.0 <= value <= 1.0:
        raise ValueError(f"{name} must be within [0, 1].")


@dataclass(frozen=True)
class HeatNeedIndicator:
    """
    An aggregate, non-identifying planning-area indicator.

    normalized_value must be independently documented before participation:
    the data source, time period, aggregation geography, normalization method,
    uncertainty, and known limitations are all part of the evidence record.
    """

    indicator_name: str
    normalized_value: float
    community_weight: float
    uncertainty: float

    def __post_init__(self) -> None:
        if not self.indicator_name.strip():
            raise ValueError("indicator_name must not be empty.")
        _unit_interval("normalized_value", self.normalized_value)
        _finite_nonnegative("community_weight", self.community_weight)
        _unit_interval("uncertainty", self.uncertainty)


@dataclass(frozen=True)
class HeatNeedProfile:
    """
    A planning-area heat-need profile.

    planning_area_id is an aggregate public-planning identifier only. It must
    not contain household, resident, device, complaint, or individual location
    data.
    """

    planning_area_id: str
    indicators: tuple[HeatNeedIndicator, ...]

    def __post_init__(self) -> None:
        if not self.planning_area_id.strip():
            raise ValueError("planning_area_id must not be empty.")
        if not self.indicators:
            raise ValueError("At least one indicator is required.")

    @property
    def raw_heat_need(self) -> float:
        total_weight = sum(item.community_weight for item in self.indicators)
        if total_weight <= 0.0:
            raise ValueError("Indicator weights must sum to more than zero.")
        return sum(
            item.normalized_value * item.community_weight
            for item in self.indicators
        ) / total_weight

    @property
    def knowledge_factor(self) -> float:
        total_weight = sum(item.community_weight for item in self.indicators)
        if total_weight <= 0.0:
            return 0.0
        weighted_uncertainty = sum(
            item.uncertainty * item.community_weight
            for item in self.indicators
        ) / total_weight
        return max(0.0, min(1.0, 1.0 - weighted_uncertainty))


def equity_weights(
    profiles: Sequence[HeatNeedProfile],
    equity_sensitivity_p: float,
) -> dict[str, float]:
    """
    Compute transparent planning weights:

      w_i(p) = V_i^p / sum_j V_j^p

    At p=0, every valid planning area receives equal weight. The function
    supports transparent scenario comparison; it does not determine any
    person's eligibility for public cooling or services.
    """
    _finite_nonnegative("equity_sensitivity_p", equity_sensitivity_p)
    if not profiles:
        raise ValueError("At least one heat-need profile is required.")

    if equity_sensitivity_p == 0.0:
        equal = 1.0 / len(profiles)
        return {
            profile.planning_area_id: equal
            for profile in profiles
        }

    raw = {
        profile.planning_area_id: profile.raw_heat_need ** equity_sensitivity_p
        for profile in profiles
    }
    total = sum(raw.values())
    if total <= 0.0:
        raise ValueError("Heat-need values must contain a positive total.")
    return {
        planning_area_id: value / total
        for planning_area_id, value in raw.items()
    }


@dataclass(frozen=True)
class PrivacyPolicy:
    """
    Differential privacy release policy.

    epsilon_per_release controls pure epsilon-DP privacy loss for each
    protected aggregate release. The policy uses basic sequential composition:

      epsilon_spent = sum(epsilon_release)

    The policy is intended for bounded aggregate counts only. Exact operational
    environmental metrics that have no person-linked contribution are released
    without DP noise so public oversight remains meaningful.
    """

    epsilon_per_release: float
    epsilon_period_budget: float
    minimum_aggregation_count: int
    contribution_limit_per_person: int

    def __post_init__(self) -> None:
        if not isfinite(self.epsilon_per_release) or self.epsilon_per_release <= 0.0:
            raise ValueError("epsilon_per_release must be finite and greater than zero.")
        if (
            not isfinite(self.epsilon_period_budget)
            or self.epsilon_period_budget <= 0.0
        ):
            raise ValueError(
                "epsilon_period_budget must be finite and greater than zero."
            )
        if self.epsilon_per_release > self.epsilon_period_budget:
            raise ValueError(
                "epsilon_per_release cannot exceed epsilon_period_budget."
            )
        if self.minimum_aggregation_count < 1:
            raise ValueError("minimum_aggregation_count must be at least one.")
        if self.contribution_limit_per_person < 1:
            raise ValueError("contribution_limit_per_person must be at least one.")

    @property
    def likelihood_ratio_bound(self) -> float:
        return exp(self.epsilon_per_release)

    @property
    def laplace_scale(self) -> float:
        return self.contribution_limit_per_person / self.epsilon_per_release


@dataclass(frozen=True)
class PrivacyRelease:
    metric_name: str
    raw_aggregate_count: int
    released_aggregate_count: float | None
    epsilon_spent_for_release: float
    epsilon_spent_total: float
    epsilon_remaining: float
    sensitivity: int
    minimum_aggregation_count: int
    suppressed: bool
    suppression_reason: str | None
    likelihood_ratio_bound: float

    def __post_init__(self) -> None:
        if not self.metric_name.strip():
            raise ValueError("metric_name must not be empty.")
        if self.raw_aggregate_count < 0:
            raise ValueError("raw_aggregate_count must be non-negative.")
        _finite_nonnegative(
            "epsilon_spent_for_release",
            self.epsilon_spent_for_release,
        )
        _finite_nonnegative("epsilon_spent_total", self.epsilon_spent_total)
        _finite_nonnegative("epsilon_remaining", self.epsilon_remaining)
        if self.sensitivity < 1:
            raise ValueError("sensitivity must be at least one.")
        if self.minimum_aggregation_count < 1:
            raise ValueError("minimum_aggregation_count must be at least one.")


def _laplace_noise(scale: float, generator: Random) -> float:
    if scale <= 0.0:
        raise ValueError("scale must be greater than zero.")
    value = generator.random() - 0.5
    sign = -1.0 if value < 0.0 else 1.0
    return -scale * sign * log(1.0 - 2.0 * abs(value))


def release_bounded_dp_count(
    metric_name: str,
    raw_aggregate_count: int,
    cumulative_epsilon_spent: float,
    policy: PrivacyPolicy,
    seed: int,
) -> PrivacyRelease:
    """
    Release a contribution-bounded aggregate count.

      M(D) = f(D) + Laplace(Delta_f / epsilon)

    Before release:
      - verify the period privacy budget;
      - suppress groups below the minimum aggregation count;
      - do not publish exact individual locations, text, or identities.

    Suppression uses the same privacy budget accounting as a release decision to
    keep reporting cadence and policy execution visible to the public.
    """
    if not metric_name.strip():
        raise ValueError("metric_name must not be empty.")
    if raw_aggregate_count < 0:
        raise ValueError("raw_aggregate_count must be non-negative.")
    _finite_nonnegative(
        "cumulative_epsilon_spent",
        cumulative_epsilon_spent,
    )

    next_spent = (
        cumulative_epsilon_spent
        + policy.epsilon_per_release
    )
    if next_spent > policy.epsilon_period_budget + 1e-12:
        raise ValueError("Differential privacy period budget exhausted.")

    remaining = max(0.0, policy.epsilon_period_budget - next_spent)

    if raw_aggregate_count < policy.minimum_aggregation_count:
        return PrivacyRelease(
            metric_name=metric_name,
            raw_aggregate_count=raw_aggregate_count,
            released_aggregate_count=None,
            epsilon_spent_for_release=policy.epsilon_per_release,
            epsilon_spent_total=next_spent,
            epsilon_remaining=remaining,
            sensitivity=policy.contribution_limit_per_person,
            minimum_aggregation_count=policy.minimum_aggregation_count,
            suppressed=True,
            suppression_reason="below_minimum_aggregation_count",
            likelihood_ratio_bound=policy.likelihood_ratio_bound,
        )

    generator = Random(seed)
    released_count = max(
        0.0,
        raw_aggregate_count + _laplace_noise(policy.laplace_scale, generator),
    )

    return PrivacyRelease(
        metric_name=metric_name,
        raw_aggregate_count=raw_aggregate_count,
        released_aggregate_count=released_count,
        epsilon_spent_for_release=policy.epsilon_per_release,
        epsilon_spent_total=next_spent,
        epsilon_remaining=remaining,
        sensitivity=policy.contribution_limit_per_person,
        minimum_aggregation_count=policy.minimum_aggregation_count,
        suppressed=False,
        suppression_reason=None,
        likelihood_ratio_bound=policy.likelihood_ratio_bound,
    )


@dataclass(frozen=True)
class GovernanceReadiness:
    vulnerability_method_published: bool
    participation_record_published: bool
    dissent_record_published: bool
    accessibility_supports_available: bool
    grievance_channel_available: bool
    privacy_policy_published: bool
    privacy_budget_within_limit: bool
    dashboard_excludes_person_linked_fields: bool
    review_date_published: bool
    uncertainty_statement_published: bool

    @property
    def rights_alignment(self) -> float:
        values = (
            self.vulnerability_method_published,
            self.participation_record_published,
            self.dissent_record_published,
            self.accessibility_supports_available,
            self.grievance_channel_available,
            self.privacy_policy_published,
            self.privacy_budget_within_limit,
            self.dashboard_excludes_person_linked_fields,
            self.review_date_published,
            self.uncertainty_statement_published,
        )
        return sum(values) / len(values)

    @property
    def ready_for_public_decision_support(self) -> bool:
        return self.rights_alignment == 1.0
