extends Resource
class_name PlanetData

# Planet strategic archetypes (PRD section 11.5). The chosen type biases the
# generated properties below — income, capture difficulty, defenses, radar /
# vision range and whether the planet can host a deployable hangar.
enum PlanetType {
	NEUTRAL_COLONY,
	MINING,
	FORTRESS,
	SHIPYARD,
	RELAY,
	GAS,
}

# Human-readable name for each archetype (shown once a planet is identified).
const TYPE_NAMES := {
	PlanetType.NEUTRAL_COLONY: "Neutral Colony",
	PlanetType.MINING: "Mining World",
	PlanetType.FORTRESS: "Fortress World",
	PlanetType.SHIPYARD: "Shipyard World",
	PlanetType.RELAY: "Relay Station",
	PlanetType.GAS: "Gas Giant",
}

# One-line strategic role, mirrored from the PRD planet-type table.
const TYPE_ROLES := {
	PlanetType.NEUTRAL_COLONY: "Balanced default world",
	PlanetType.MINING: "Higher prestige income",
	PlanetType.FORTRESS: "Built-in defenses, slow to capture",
	PlanetType.SHIPYARD: "Hosts a hangar for redeployment",
	PlanetType.RELAY: "Extends radar / vision range",
	PlanetType.GAS: "Reduced visibility hazard",
}

# Baseline radar / vision contribution (world units) for a captured planet, used
# when vision_range is left at 0. Relay planets extend this notably.
const BASE_VISION_RANGE := 2600.0

@export var name: String = "Neutral Colony"
# Legacy free-form label kept for back-compat with hand-authored resources.
@export var planet_type: String = "Default"
# Strategic archetype driving generated properties (PRD 11.5).
@export var type_id: PlanetType = PlanetType.NEUTRAL_COLONY
@export var income_per_second: float = 2.0
@export var capture_radius: float = 300.0
@export var capture_required: float = 100.0
@export var capture_resistance: float = 1.0
@export var has_defenses: bool = false
# Radar / vision range contributed to the owning faction's fog-of-war reveal
# once the planet is captured. 0 falls back to BASE_VISION_RANGE.
@export var vision_range: float = 0.0
# When true the planet can host a hangar, so the fleet may (re)deploy here.
@export var supports_hangar: bool = false

# Effective fog-of-war reveal radius for this planet (handles the 0 fallback).
func get_vision_range() -> float:
	return vision_range if vision_range > 0.0 else BASE_VISION_RANGE

# Display label for the planet's archetype, preferring the enum name and
# falling back to the legacy free-form string for hand-authored resources.
func get_type_name() -> String:
	if TYPE_NAMES.has(type_id):
		return TYPE_NAMES[type_id]
	return planet_type

func get_type_role() -> String:
	return TYPE_ROLES.get(type_id, "")

# Procedurally builds a PlanetData for a freshly generated planet. The type is
# drawn from a weighted table and drives income, capture difficulty, defenses,
# vision range and hangar support. Pass a seeded RNG so a given system seed
# always reproduces the same planets (conventions.md Determinism).
static func generate(rng: RandomNumberGenerator) -> PlanetData:
	var roll: float = rng.randf()
	var t: PlanetType
	if roll < 0.34:
		t = PlanetType.NEUTRAL_COLONY
	elif roll < 0.52:
		t = PlanetType.MINING
	elif roll < 0.68:
		t = PlanetType.FORTRESS
	elif roll < 0.80:
		t = PlanetType.SHIPYARD
	elif roll < 0.92:
		t = PlanetType.RELAY
	else:
		t = PlanetType.GAS
	return build_type(t, rng)

# Builds a PlanetData for a specific archetype. Exposed (rather than private) so
# scripted setups — homebase worlds, tests — can request a known type.
static func build_type(t: PlanetType, rng: RandomNumberGenerator) -> PlanetData:
	var data := PlanetData.new()
	data.type_id = t
	data.name = TYPE_NAMES.get(t, "Neutral Colony")
	data.planet_type = data.name
	data.capture_radius = rng.randf_range(360.0, 440.0)

	match t:
		PlanetType.MINING:
			data.income_per_second = rng.randf_range(4.0, 6.0)
			data.capture_required = 100.0
			data.capture_resistance = 1.0
			data.vision_range = BASE_VISION_RANGE
		PlanetType.FORTRESS:
			data.income_per_second = rng.randf_range(1.5, 2.5)
			data.capture_required = 180.0
			data.capture_resistance = 2.0
			data.has_defenses = true
			data.vision_range = BASE_VISION_RANGE * 1.1
		PlanetType.SHIPYARD:
			data.income_per_second = rng.randf_range(2.0, 3.0)
			data.capture_required = 120.0
			data.capture_resistance = 1.2
			data.supports_hangar = true
			data.vision_range = BASE_VISION_RANGE
		PlanetType.RELAY:
			data.income_per_second = rng.randf_range(1.5, 2.5)
			data.capture_required = 90.0
			data.capture_resistance = 0.8
			data.vision_range = BASE_VISION_RANGE * 1.8
		PlanetType.GAS:
			data.income_per_second = rng.randf_range(2.5, 3.5)
			data.capture_required = 110.0
			data.capture_resistance = 1.0
			# Visibility hazard: a gas giant reveals less than a normal world.
			data.vision_range = BASE_VISION_RANGE * 0.6
		_:
			data.income_per_second = rng.randf_range(2.0, 3.0)
			data.capture_required = 100.0
			data.capture_resistance = 1.0
			data.vision_range = BASE_VISION_RANGE
	return data
