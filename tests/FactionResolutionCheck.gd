extends SceneTree

# Verifies that ships resolve their FactionData from their own resource (via the
# faction enum registry) and that the resolved instance is the same engine-cached
# object the match loads, so allegiance comparisons (==) stay correct.

const ZARAK_FRIGATE_PATH := "res://resources/factions/zarak/ships/gorehammer.tres"
const ZARAK_SCOUT_PATH := "res://resources/factions/zarak/ships/scout.tres"
const STRIKER_LANCE_PATH := "res://resources/factions/solarion_collective/ships/striker_lance.tres"
const ZARAK_FACTION_PATH := "res://resources/factions/zarak/zarak_confedaracy.tres"
const SOLARION_FACTION_PATH := "res://resources/factions/solarion_collective/solarion_collective.tres"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []

	var zarak_faction := load(ZARAK_FACTION_PATH) as FactionData
	var solarion_faction := load(SOLARION_FACTION_PATH) as FactionData

	# Ships resolve to the correct faction, and to the SAME cached instance the
	# match loads (critical for friendly-fire `==` checks).
	_expect_same(ZARAK_FRIGATE_PATH, zarak_faction, "Zarak frigate", failures)
	_expect_same(ZARAK_SCOUT_PATH, zarak_faction, "Zarak scout", failures)
	_expect_same(STRIKER_LANCE_PATH, solarion_faction, "Striker Lance", failures)

	# Registry helper resolves both registered factions.
	if FactionData.load_faction(FactionData.Faction.ZARAK) != zarak_faction:
		failures.append("load_faction(ZARAK) did not return the zarak faction")
	if FactionData.load_faction(FactionData.Faction.SOLARION) != solarion_faction:
		failures.append("load_faction(SOLARION) did not return the solarion faction")

	if failures.is_empty():
		print("[TEST] FactionResolutionCheck passed")
		quit(0)
		return
	for failure in failures:
		push_error("[TEST] %s" % failure)
	quit(1)

func _expect_same(ship_path: String, expected: FactionData, label: String, failures: Array[String]) -> void:
	var ship := load(ship_path) as ShipData
	if not ship:
		failures.append("Failed to load %s" % label)
		return
	var resolved := ship.resolve_faction_data()
	if resolved == null:
		failures.append("%s resolved a null faction" % label)
	elif resolved != expected:
		failures.append("%s resolved the wrong faction instance" % label)
