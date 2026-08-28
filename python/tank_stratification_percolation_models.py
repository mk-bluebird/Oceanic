from __future__ import annotations

from dataclasses import dataclass
from math import exp, isfinite
from random import Random
from typing import Iterable, Sequence


SECONDS_PER_HOUR = 3_600.0


def _positive(name: str, value: float) -> None:
    if not isfinite(value) or value <= 0.0:
        raise ValueError(f"{name} must be finite and greater than zero.")


def _nonnegative(name: str, value: float) -> None:
    if not isfinite(value) or value < 0.0:
        raise ValueError(f"{name} must be finite and non-negative.")


def _probability(name: str, value: float) -> None:
    if not isfinite(value) or not 0.0 < value < 1.0:
        raise ValueError(f"{name} must be strictly between zero and one.")


@dataclass(frozen=True)
class StorageTankThermalInputs:
    """
    Solar and evaporative vertical-temperature profile inputs.

    Positive depth z is measured downward from the water surface:

      T(z,t) =
        T_ambient(t)
        + Delta_T_rad(t) exp[-z/d_penetration]
        - Delta_T_evap(t) exp[-z/d_evap]

    The model represents a screened vertical profile. It should be fitted to
    temperature strings at multiple depths and does not replace a CFD or
    hydrodynamic model where filling jets, baffles, recirculation, or nonuniform
    solar exposure dominate behavior.
    """

    total_water_depth_m: float
    ambient_air_temperature_c: float
    radiative_surface_warming_c: float
    radiative_penetration_depth_m: float
    evaporative_surface_cooling_c: float
    evaporative_depth_m: float
    tank_surface_area_m2: float
    tank_volume_m3: float
    fill_flow_m3_per_s: float
    fill_mixing_efficiency: float
    incoming_water_temperature_c: float

    def __post_init__(self) -> None:
        for name, value in (
            ("total_water_depth_m", self.total_water_depth_m),
            ("radiative_surface_warming_c", self.radiative_surface_warming_c),
            (
                "radiative_penetration_depth_m",
                self.radiative_penetration_depth_m,
            ),
            (
                "evaporative_surface_cooling_c",
                self.evaporative_surface_cooling_c,
            ),
            ("evaporative_depth_m", self.evaporative_depth_m),
            ("tank_surface_area_m2", self.tank_surface_area_m2),
            ("tank_volume_m3", self.tank_volume_m3),
            ("fill_flow_m3_per_s", self.fill_flow_m3_per_s),
            ("fill_mixing_efficiency", self.fill_mixing_efficiency),
        ):
            _nonnegative(name, value)

        _positive("total_water_depth_m", self.total_water_depth_m)
        _positive(
            "radiative_penetration_depth_m",
            self.radiative_penetration_depth_m,
        )
        _positive("evaporative_depth_m", self.evaporative_depth_m)
        _positive("tank_surface_area_m2", self.tank_surface_area_m2)
        _positive("tank_volume_m3", self.tank_volume_m3)
        if self.fill_mixing_efficiency > 1.0:
            raise ValueError("fill_mixing_efficiency must not exceed one.")
        if not isfinite(self.ambient_air_temperature_c):
            raise ValueError("ambient_air_temperature_c must be finite.")
        if not isfinite(self.incoming_water_temperature_c):
            raise ValueError("incoming_water_temperature_c must be finite.")


@dataclass(frozen=True)
class TankTemperatureProfileResult:
    depth_m: float
    static_temperature_c: float
    mixed_temperature_c: float
    mixing_turnover_time_hours: float
    temperature_above_legionella_threshold: bool


@dataclass(frozen=True)
class TankAmplificationAssessment:
    shallowest_depth_above_threshold_m: float | None
    deepest_depth_above_threshold_m: float | None
    maximum_continuous_hours_above_threshold: float
    exceeds_twelve_hour_persistence_limit: bool
    fill_mixing_turnover_time_hours: float
    mixing_disrupts_stratification: bool
    interpretation: str


def static_tank_temperature_c(
    depth_m: float,
    inputs: StorageTankThermalInputs,
) -> float:
    """
    Evaluate the supplied temperature profile at a depth from the surface.
    """
    _nonnegative("depth_m", depth_m)
    if depth_m > inputs.total_water_depth_m:
        raise ValueError("depth_m cannot exceed total_water_depth_m.")

    return (
        inputs.ambient_air_temperature_c
        + inputs.radiative_surface_warming_c
        * exp(-depth_m / inputs.radiative_penetration_depth_m)
        - inputs.evaporative_surface_cooling_c
        * exp(-depth_m / inputs.evaporative_depth_m)
    )


def effective_fill_mixing_fraction(
    inputs: StorageTankThermalInputs,
    fill_duration_hours: float,
) -> float:
    """
    Mixing fraction for a filling event:

      f_mix = 1 - exp[-eta_mix * Q_fill * t / V_tank]

    This is a transparent first-order turnover approximation. It captures that
    mixing increases with inflow, duration, and inlet-jet/baffle effectiveness.
    A low efficiency does not falsely claim that nominal tank turnover produces
    complete vertical mixing.
    """
    _nonnegative("fill_duration_hours", fill_duration_hours)
    if inputs.fill_flow_m3_per_s == 0.0 or inputs.fill_mixing_efficiency == 0.0:
        return 0.0

    mixed_turnovers = (
        inputs.fill_mixing_efficiency
        * inputs.fill_flow_m3_per_s
        * fill_duration_hours
        * SECONDS_PER_HOUR
        / inputs.tank_volume_m3
    )
    return 1.0 - exp(-mixed_turnovers)


def tank_temperature_after_fill_c(
    depth_m: float,
    inputs: StorageTankThermalInputs,
    fill_duration_hours: float,
) -> TankTemperatureProfileResult:
    """
    Blend the stratified temperature with incoming water according to the
    effective mixing fraction. The profile remains depth-aware when mixing is
    incomplete.
    """
    static_temperature = static_tank_temperature_c(depth_m, inputs)
    fraction = effective_fill_mixing_fraction(inputs, fill_duration_hours)
    mixed_temperature = (
        (1.0 - fraction) * static_temperature
        + fraction * inputs.incoming_water_temperature_c
    )
    turnover_hours = (
        float("inf")
        if inputs.fill_flow_m3_per_s == 0.0 or inputs.fill_mixing_efficiency == 0.0
        else inputs.tank_volume_m3
        / (
            inputs.fill_flow_m3_per_s
            * inputs.fill_mixing_efficiency
            * SECONDS_PER_HOUR
        )
    )

    return TankTemperatureProfileResult(
        depth_m=depth_m,
        static_temperature_c=static_temperature,
        mixed_temperature_c=mixed_temperature,
        mixing_turnover_time_hours=turnover_hours,
        temperature_above_legionella_threshold=mixed_temperature_c > 25.0,
    )


def assess_tank_amplification_window(
    inputs_by_hour: Sequence[StorageTankThermalInputs],
    fill_duration_hours_by_hour: Sequence[float],
    depth_increment_m: float = 0.10,
    legionella_threshold_c: float = 25.0,
    persistence_limit_hours: float = 12.0,
) -> TankAmplificationAssessment:
    """
    Evaluate the depth-time temperature field across a supplied hourly sequence.

    The output identifies the deepest and shallowest water layers that exceed
    the temperature threshold for a continuous run longer than the stated
    persistence limit. The default threshold is 25°C because this is the lower
    edge of the commonly cited Legionella growth-favorable range.

    A "mixing disrupts stratification" conclusion requires both:
      - a fill mixing turnover time no greater than the measured fill duration;
      - no evaluated depth remaining over the threshold for the persistence
        limit after mixing.

    This is intentionally more stringent than treating any tank filling as
    equivalent to complete mixing.
    """
    if len(inputs_by_hour) != len(fill_duration_hours_by_hour):
        raise ValueError(
            "inputs_by_hour and fill_duration_hours_by_hour must match in length."
        )
    if not inputs_by_hour:
        raise ValueError("At least one hourly profile is required.")
    _positive("depth_increment_m", depth_increment_m)
    _positive("legionella_threshold_c", legionella_threshold_c)
    _positive("persistence_limit_hours", persistence_limit_hours)

    reference_depth = inputs_by_hour[0].total_water_depth_m
    if any(
        abs(item.total_water_depth_m - reference_depth) > 1e-9
        for item in inputs_by_hour
    ):
        raise ValueError(
            "All hourly inputs must use the same total_water_depth_m."
        )

    depths: list[float] = []
    current = 0.0
    while current <= reference_depth + 1e-9:
        depths.append(min(current, reference_depth))
        current += depth_increment_m
    if depths[-1] != reference_depth:
        depths.append(reference_depth)

    qualifying_depths: list[float] = []
    longest_run = 0
    all_mixing_sufficient = True

    for depth in depths:
        current_run = 0
        local_longest = 0
        for inputs, fill_hours in zip(inputs_by_hour, fill_duration_hours_by_hour):
            profile = tank_temperature_after_fill_c(depth, inputs, fill_hours)
            if profile.mixed_temperature_c > legionella_threshold_c:
                current_run += 1
                local_longest = max(local_longest, current_run)
            else:
                current_run = 0

            if (
                profile.mixing_turnover_time_hours > fill_hours
                or profile.mixed_temperature_c > legionella_threshold_c
            ):
                all_mixing_sufficient = False

        if local_longest > persistence_limit_hours:
            qualifying_depths.append(depth)
        longest_run = max(longest_run, local_longest)

    representative = inputs_by_hour[0]
    turnover_hours = (
        float("inf")
        if representative.fill_flow_m3_per_s == 0.0
        or representative.fill_mixing_efficiency == 0.0
        else representative.tank_volume_m3
        / (
            representative.fill_flow_m3_per_s
            * representative.fill_mixing_efficiency
            * SECONDS_PER_HOUR
        )
    )

    exceeds = longest_run > persistence_limit_hours
    interpretation = (
        "At least one tank layer remains above the stated temperature threshold "
        "for longer than the persistence limit; temperature, turnover, residual "
        "disinfectant, biofilm, and microbiological controls require review."
        if exceeds
        else
        "The modeled depth-time profile remains below the stated continuous "
        "temperature persistence limit. This supports, but does not alone prove, "
        "control of Legionella amplification conditions."
    )

    return TankAmplificationAssessment(
        shallowest_depth_above_threshold_m=(
            min(qualifying_depths) if qualifying_depths else None
        ),
        deepest_depth_above_threshold_m=(
            max(qualifying_depths) if qualifying_depths else None
        ),
        maximum_continuous_hours_above_threshold=float(longest_run),
        exceeds_twelve_hour_persistence_limit=exceeds,
        fill_mixing_turnover_time_hours=turnover_hours,
        mixing_disrupts_stratification=not exceeds and all_mixing_sufficient,
        interpretation=interpretation,
    )


@dataclass(frozen=True)
class HexCell:
    """
    A finite Phoenix corridor lattice cell.

    habitable is determined from an externally documented ecological-resistance
    threshold for the focal species or habitat process. It should incorporate
    urban heat, road barriers, land cover, water availability, light, noise,
    invasive pressure, and verified restoration condition as appropriate.

    axial_q and axial_r identify local grid adjacency only; they are not a
    location identifier or a substitute for geodetic provenance.
    """

    axial_q: int
    axial_r: int
    resistance: float
    resistance_threshold: float
    role: str

    def __post_init__(self) -> None:
        _nonnegative("resistance", self.resistance)
        _positive("resistance_threshold", self.resistance_threshold)
        if self.role not in {"salt_river", "mountains_preserve", "intermediate"}:
            raise ValueError("role must be salt_river, mountains_preserve, or intermediate.")

    @property
    def habitable(self) -> bool:
        return self.resistance <= self.resistance_threshold

    @property
    def coordinate(self) -> tuple[int, int]:
        return (self.axial_q, self.axial_r)


@dataclass(frozen=True)
class PercolationAssessment:
    habitable_fraction: float
    threshold_reference_fraction: float
    salt_river_to_mountains_connected: bool
    current_habitable_cell_count: int
    minimum_additional_cells_for_connection: int | None
    minimum_restoration_investment: float | None
    interpretation: str


def _neighbors(cell: tuple[int, int]) -> tuple[tuple[int, int], ...]:
    q, r = cell
    return (
        (q + 1, r),
        (q + 1, r - 1),
        (q, r - 1),
        (q - 1, r),
        (q - 1, r + 1),
        (q, r + 1),
    )


def _cell_map(cells: Iterable[HexCell]) -> dict[tuple[int, int], HexCell]:
    result: dict[tuple[int, int], HexCell] = {}
    for cell in cells:
        if cell.coordinate in result:
            raise ValueError("Hex coordinates must be unique.")
        result[cell.coordinate] = cell
    return result


def _connected(
    cell_map: dict[tuple[int, int], HexCell],
    restored_coordinates: frozenset[tuple[int, int]] = frozenset(),
) -> bool:
    salt_cells = {
        coordinate
        for coordinate, cell in cell_map.items()
        if cell.role == "salt_river" and (cell.habitable or coordinate in restored_coordinates)
    }
    mountain_cells = {
        coordinate
        for coordinate, cell in cell_map.items()
        if cell.role == "mountains_preserve"
        and (cell.habitable or coordinate in restored_coordinates)
    }

    if not salt_cells or not mountain_cells:
        return False

    frontier = list(salt_cells)
    visited = set(salt_cells)
    while frontier:
        current = frontier.pop()
        if current in mountain_cells:
            return True
        for neighbor in _neighbors(current):
            adjacent = cell_map.get(neighbor)
            if adjacent is None:
                continue
            if (
                neighbor not in visited
                and (adjacent.habitable or neighbor in restored_coordinates)
            ):
                visited.add(neighbor)
                frontier.append(neighbor)
    return False


def _minimum_restoration_path(
    cell_map: dict[tuple[int, int], HexCell],
) -> tuple[int, list[tuple[int, int]]] | None:
    """
    Dijkstra-style path search minimizing the count of presently non-habitable
    cells that must be restored. Existing habitable cells have zero entry cost.

    The result is a finite-grid connectivity investment calculation. It is more
    operationally relevant than applying an infinite-lattice threshold as a
    literal Phoenix investment rule.
    """
    salt_cells = [
        coordinate
        for coordinate, cell in cell_map.items()
        if cell.role == "salt_river"
    ]
    mountain_cells = {
        coordinate
        for coordinate, cell in cell_map.items()
        if cell.role == "mountains_preserve"
    }

    if not salt_cells or not mountain_cells:
        return None

    distance = {coordinate: float("inf") for coordinate in cell_map}
    predecessor: dict[tuple[int, int], tuple[int, int] | None] = {
        coordinate: None for coordinate in cell_map
    }
    frontier: set[tuple[int, int]] = set()

    for source in salt_cells:
        source_cost = 0 if cell_map[source].habitable else 1
        distance[source] = source_cost
        frontier.add(source)

    destination: tuple[int, int] | None = None
    while frontier:
        current = min(frontier, key=lambda coordinate: distance[coordinate])
        frontier.remove(current)

        if current in mountain_cells:
            destination = current
            break

        for neighbor in _neighbors(current):
            if neighbor not in cell_map:
                continue
            entry_cost = 0 if cell_map[neighbor].habitable else 1
            candidate = distance[current] + entry_cost
            if candidate < distance[neighbor]:
                distance[neighbor] = candidate
                predecessor[neighbor] = current
                frontier.add(neighbor)

    if destination is None:
        return None

    path: list[tuple[int, int]] = []
    current: tuple[int, int] | None = destination
    while current is not None:
        path.append(current)
        current = predecessor[current]
    path.reverse()

    restored = [
        coordinate
        for coordinate in path
        if not cell_map[coordinate].habitable
    ]
    return len(restored), restored


def assess_percolation_corridor(
    cells: Sequence[HexCell],
    restoration_cost_per_cell: float,
    infinite_honeycomb_site_threshold: float = 0.6970402,
) -> PercolationAssessment:
    """
    Assess finite-grid connectivity and minimum restoration cells.

    The honeycomb site threshold is included only as a theoretical reference.
    Real Phoenix green infrastructure is finite, spatially correlated, anisotropic,
    and resistance-weighted; connectivity must be calculated directly from mapped
    cells, not assumed from the infinite random-lattice threshold.
    """
    if not cells:
        raise ValueError("At least one hex cell is required.")
    _nonnegative("restoration_cost_per_cell", restoration_cost_per_cell)
    _probability(
        "infinite_honeycomb_site_threshold",
        infinite_honeycomb_site_threshold,
    )

    cell_map = _cell_map(cells)
    habitable_count = sum(cell.habitable for cell in cells)
    fraction = habitable_count / len(cells)
    is_connected = _connected(cell_map)
    path_result = _minimum_restoration_path(cell_map)

    if path_result is None:
        additions = None
        investment = None
    else:
        additions, _ = path_result
        investment = additions * restoration_cost_per_cell

    interpretation = (
        "The finite mapped habitat lattice already contains a connected "
        "Salt River-to-Phoenix Mountains path under the selected resistance "
        "threshold."
        if is_connected
        else (
            "The lattice is not presently connected. The reported additional "
            "cell count is the minimum least-restoration path under the present "
            "binary habitat classification and must be reviewed with focal-species "
            "movement, land tenure, road crossings, hydrology, and habitat quality."
        )
    )

    return PercolationAssessment(
        habitable_fraction=fraction,
        threshold_reference_fraction=infinite_honeycomb_site_threshold,
        salt_river_to_mountains_connected=is_connected,
        current_habitable_cell_count=habitable_count,
        minimum_additional_cells_for_connection=additions,
        minimum_restoration_investment=investment,
        interpretation=interpretation,
    )
