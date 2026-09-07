package eco_restoration.soil;

import java.util.List;
import java.util.Objects;

public final class SoilCarbonDecayPools {
    private SoilCarbonDecayPools() {
    }

    public record Pool(
        String poolId,
        double initialCarbonKgM2,
        double baseRatePerDay,
        double transformedRatePerDay,
        double lowerRateBoundPerDay,
        double upperRateBoundPerDay
    ) {
        public Pool {
            if (poolId == null || poolId.isBlank()) {
                throw new IllegalArgumentException("poolId must not be blank.");
            }
            requireFiniteNonNegative(initialCarbonKgM2, "initialCarbonKgM2");
            requireFiniteNonNegative(baseRatePerDay, "baseRatePerDay");
            requireFiniteNonNegative(transformedRatePerDay, "transformedRatePerDay");
            requireFiniteNonNegative(lowerRateBoundPerDay, "lowerRateBoundPerDay");
            requireFiniteNonNegative(upperRateBoundPerDay, "upperRateBoundPerDay");

            if (lowerRateBoundPerDay > upperRateBoundPerDay) {
                throw new IllegalArgumentException("Rate bounds are not ordered.");
            }

            if (transformedRatePerDay < lowerRateBoundPerDay ||
                transformedRatePerDay > upperRateBoundPerDay) {
                throw new IllegalArgumentException(
                    "The transformed rate must remain inside the source-bound interval."
                );
            }
        }
    }

    public record Assessment(
        double socKgM2,
        String status,
        String reason
    ) {
    }

    public static Assessment assess(
        List<Pool> pools,
        double horizonDays,
        double validatedHorizonDays
    ) {
        Objects.requireNonNull(pools, "pools must not be null");
        requireFiniteNonNegative(horizonDays, "horizonDays");
        requireFiniteNonNegative(validatedHorizonDays, "validatedHorizonDays");

        if (horizonDays > validatedHorizonDays) {
            return new Assessment(
                Double.NaN,
                "withheld",
                "Requested horizon exceeds the validated horizon."
            );
        }

        double total = 0.0;
        for (Pool pool : pools) {
            total += pool.initialCarbonKgM2() *
                Math.exp(-pool.transformedRatePerDay() * horizonDays);
        }

        return new Assessment(
            total,
            "advisory_candidate",
            "Bounded soil-carbon decay estimate for human review."
        );
    }

    public static boolean monotonicNonIncreasing(
        List<Pool> pools,
        double earlierDays,
        double laterDays,
        double validatedHorizonDays
    ) {
        if (laterDays <= earlierDays) {
            throw new IllegalArgumentException("laterDays must be greater than earlierDays.");
        }

        Assessment earlier = assess(pools, earlierDays, validatedHorizonDays);
        Assessment later = assess(pools, laterDays, validatedHorizonDays);

        if (!"advisory_candidate".equals(earlier.status()) ||
            !"advisory_candidate".equals(later.status())) {
            return false;
        }

        return later.socKgM2() <= earlier.socKgM2();
    }

    private static void requireFiniteNonNegative(double value, String name) {
        if (!Double.isFinite(value) || value < 0.0) {
            throw new IllegalArgumentException(name + " must be finite and non-negative.");
        }
    }
}
