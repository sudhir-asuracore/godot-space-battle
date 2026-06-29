extends Resource
class_name ShipData

# Physical size class of the ship. Drives the destruction explosion scale,
# duration and audio so larger hulls blow up bigger, longer and louder.
enum ShipSize { SMALL, MEDIUM, LARGE, CAPITAL }

# Combat archetype of the ship, defining its role in the fleet.
enum ShipClass { SCOUT, FRIGATE, DREADNAUGHT, CARRIER }

# Single source of truth for ship-class display names. Change a label here and
# it updates everywhere; wrap the return of get_ship_class_name() in tr() to add
# localization later without touching call sites or resource files.
const SHIP_CLASS_NAMES := {
	ShipClass.SCOUT: "Scout",
	ShipClass.FRIGATE: "Frigate",
	ShipClass.DREADNAUGHT: "Dreadnaught",
	ShipClass.CARRIER: "Carrier",
}

@export_category("Profile")
@export var name: String = "Scout"
@export var tier: int = 1
@export var ship_class: ShipClass = ShipClass.SCOUT
@export var faction: FactionData.Faction = FactionData.Faction.ZARAK
@export var ship_size: ShipSize = ShipSize.MEDIUM
# Short role blurb shown in the hangar detail panel (e.g. "A fast and agile
# strike fighter. Excellent for hit-and-run tactics.").
@export_multiline var description: String = ""
# Scene instantiated when this ship is spawned for the player. When left unset
# the spawner falls back to its configured default ship scene.
@export var ship_scene: PackedScene
# Optional explicit FactionData override. Normally left unset: the ship's
# `faction` enum already identifies its faction and resolve_faction_data()
# looks the resource up via FactionData's registry, which avoids the load-time
# cycle a direct ext_resource link would create with hangar_ship_options. Set
# this only for ships whose faction is not registered in that map.
@export var faction_data: FactionData

# Returns the FactionData this ship belongs to. Prefers an explicit override and
# otherwise resolves the canonical resource from the `faction` enum, so a ship
# stays linked to its own faction without external wiring.
func resolve_faction_data() -> FactionData:
	if faction_data:
		return faction_data
	return FactionData.load_faction(faction)

@export_category("Vitals")
@export var max_hull: float = 100.0
@export var max_shield: float = 50.0
@export var shield_regen: float = 5.0
@export var shield_regen_delay: float = 3.0
@export var shield_angle: float = 360.0

@export_category("Movement")
@export var max_speed: float = 35.0
@export var acceleration: float = 45.0
# Peak turn rate (radians/second) the ship can rotate at.
@export var turn_speed: float = 4.0
# How quickly the ship can build up to / bleed off its turn rate
# (radians/second^2). Lower values give the ship more rotational inertia so it
# feels heavy: it eases into a turn and keeps drifting briefly after the input
# stops instead of snapping. Set <= 0 to turn instantly (no inertia).
@export var turn_acceleration: float = 8.0
@export var strafe_speed: float = 12.0
@export var reverse_speed: float = 8.0
@export var forward_damping: float = 0.08
@export var lateral_damping: float = 0.18
@export var arrival_radius: float = 80.0
@export var braking_strength: float = 1.5

@export_category("Capacitor")
@export var max_capacitor: float = 100.0
@export var capacitor_regen: float = 15.0

@export_category("Weapons")
@export var basic_weapon: WeaponData
@export var target_lock_range: float = 300.0
# Maps a muzzle weapon-type (the <type> in muzzle_<type>_<side>_<index> markers,
# e.g. "cannon", "gattling", "laser") to the WeaponData used for its projectile.
# Any type not listed here falls back to basic_weapon.
@export var muzzle_weapons: Dictionary = {}

# Maps a self-contained weapon node's key to the WeaponData resource it fires.
# The key matches the weapon node's prefix in the ship scene, i.e. the
# "weapon_<key>" portion of a node named weapon_<key>_<side>_<index>
# (e.g. node "weapon_cannonlarge_right_0" -> key "weapon_cannonlarge"). This
# lets a ship declare which weapon .tres each of its weapon slots uses, so the
# weapon (its projectile, muzzle flash, audio) stays fully self-contained.
@export var weapons: Dictionary = {}

# Returns the weapon resource configured for a given muzzle type, or null when
# no specific mapping exists (callers fall back to basic_weapon).
func get_muzzle_weapon(muzzle_type: StringName) -> WeaponData:
	if muzzle_type == &"":
		return null
	var mapped: Variant = muzzle_weapons.get(muzzle_type)
	if mapped == null:
		# Allow string keys too for convenience when authored in the inspector.
		mapped = muzzle_weapons.get(String(muzzle_type))
	return mapped as WeaponData

# Returns the WeaponData a self-contained weapon node should fire, resolved from
# the node's "weapon_<key>" prefix (e.g. "weapon_cannonlarge"). Returns null
# when the ship declares no weapon for that key.
func get_ship_weapon(weapon_key: StringName) -> WeaponData:
	if weapon_key == &"":
		return null
	var mapped: Variant = weapons.get(weapon_key)
	if mapped == null:
		# Allow string keys too for convenience when authored in the inspector.
		mapped = weapons.get(String(weapon_key))
	return mapped as WeaponData

@export_category("Visuals")
@export var trail_color: Color = Color(1.0, 0.5, 0.2, 0.8)
@export var trail_brightness: float = 2.0
@export var trail_thickness: float = 8.0
@export var trail_length: int = 40
@export var trail_lifetime: float = 1.5

@export_category("Abilities")
@export var ability_1: AbilityData
@export var ability_2: AbilityData
@export var ability_3: AbilityData
@export var ability_4: AbilityData
@export var ability_5: AbilityData

@export_category("Economy")
@export var purchase_cost: float = 150.0
@export var kill_bounty: float = 75.0
@export var death_penalty: float = 37.0
# Starter ships are the always-available free fallback: they never cost prestige
# to deploy and count as owned from the start so going broke can't softlock the
# player (PRD section 10.4 / Milestone 7).
@export var is_starter: bool = false

@export_category("Hangar Presentation")
# Large hero image shown on the hangar's center stage. When left unset it is
# resolved from the ship scene's `lod_near` Sprite2D so art only has to be
# authored once, on the scene itself (see get_hangar_portrait()).
@export var hangar_portrait: Texture2D
# Thumbnail shown in the scrollable ship list. Falls back to the ship scene's
# `lod_medium` Sprite2D when unset (see get_hangar_icon()).
@export var hangar_icon: Texture2D

# Display name for this ship's class (e.g. "Frigate"), sourced from the shared
# SHIP_CLASS_NAMES lookup so the label stays consistent everywhere it is shown.
func get_ship_class_name() -> String:
	return SHIP_CLASS_NAMES.get(ship_class, "")

# Returns the large hangar hero image. Prefers an explicit override and
# otherwise pulls the `lod_near` texture straight from the ship scene, so the
# same artwork drives both the in-game hull and the hangar without duplication.
func get_hangar_portrait() -> Texture2D:
	if hangar_portrait:
		return hangar_portrait
	return _scene_sprite_texture(&"lod_near")

# Returns the small hangar list thumbnail. Prefers an explicit override and
# otherwise pulls the `lod_medium` texture from the ship scene.
func get_hangar_icon() -> Texture2D:
	if hangar_icon:
		return hangar_icon
	var medium: Texture2D = _scene_sprite_texture(&"lod_medium")
	return medium if medium else get_hangar_portrait()

# Reads the `texture` of a named Sprite2D from `ship_scene` without
# instantiating it. PackedScene.get_state() lets us inspect authored node
# properties directly, avoiding the side effects (trails, audio, _ready logic)
# of spawning a live Ship just to grab its artwork for a menu.
func _scene_sprite_texture(sprite_name: StringName) -> Texture2D:
	if ship_scene == null:
		return null
	var state: SceneState = ship_scene.get_state()
	for node_index in state.get_node_count():
		if state.get_node_name(node_index) != String(sprite_name):
			continue
		for prop_index in state.get_node_property_count(node_index):
			if state.get_node_property_name(node_index, prop_index) == &"texture":
				return state.get_node_property_value(node_index, prop_index) as Texture2D
	return null
