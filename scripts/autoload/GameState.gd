extends Node

# Economy constants (PRD section 10.2)
const STARTING_PRESTIGE: float = 200.0
const CAPTURE_REWARD: float = 100.0
# Tech points are a second currency spent on ability/tech upgrades (Milestone 7
# header, fully used from Milestone 10). Players start with none and earn them
# from tech-bearing planets.
const STARTING_TECH_POINTS: float = 0.0

# Homebase shield interlock warning delay (PRD section 11.6: 10-20s)
const SHIELD_WARNING_DELAY: float = 12.0

var player_faction: FactionData = null

var selected_faction_id: String = ""
var selected_faction_path: String = ""
var selected_ship_data_path: String = ""
var selected_ship_scene_path: String = ""
var selected_enemy_faction_path: String = ""
var selected_enemy_ship_data_path: String = ""
var selected_enemy_ship_scene_path: String = ""

var planet_ownership: Dictionary = {}      # Planet -> FactionData (null = neutral)
var faction_prestige: Dictionary = {}      # FactionData -> float
var faction_tech_points: Dictionary = {}   # FactionData -> float
# Ships a faction has unlocked (purchased or starter). FactionData -> { ShipData -> true }.
var _owned_ships: Dictionary = {}
# The ship each faction currently has selected for deployment. FactionData -> ShipData.
var _current_ship: Dictionary = {}

var _homebase_factions: Array = []         # Factions that own a homebase
var _shield_active: Dictionary = {}        # FactionData -> bool (current homebase shield state)
var _shield_target: Dictionary = {}        # FactionData -> bool (desired homebase shield state)
var _shield_timer: Dictionary = {}         # FactionData -> float (remaining warning seconds)

var _income_accumulator: float = 0.0

func _ready() -> void:
	EventBus.planet_captured.connect(_on_planet_captured)
	EventBus.ship_destroyed.connect(_on_ship_destroyed)

func _process(delta: float) -> void:
	# Passive planet income, evaluated once per second (PRD: +2 Prestige/sec).
	_income_accumulator += delta
	if _income_accumulator >= 1.0:
		_income_accumulator -= 1.0
		_tick_income()
	_tick_shields(delta)

# --- Faction / economy registration -----------------------------------------

func register_faction(faction: FactionData) -> void:
	if faction and not faction_prestige.has(faction):
		faction_prestige[faction] = STARTING_PRESTIGE
		EventBus.prestige_changed.emit(faction, faction_prestige[faction])
	if faction and not faction_tech_points.has(faction):
		faction_tech_points[faction] = STARTING_TECH_POINTS
		EventBus.tech_points_changed.emit(faction, faction_tech_points[faction])
	# Starter ships are unlocked for free so the player always has a fallback.
	if faction:
		for option in faction.hangar_ship_options:
			var ship_data := option as ShipData
			if ship_data and ship_data.is_starter:
				grant_ship(faction, ship_data)

func register_homebase(faction: FactionData) -> void:
	register_faction(faction)
	if faction and not _homebase_factions.has(faction):
		_homebase_factions.append(faction)
		_shield_active[faction] = true
		_shield_target[faction] = true
		_shield_timer[faction] = 0.0

# --- Prestige helpers --------------------------------------------------------

func get_prestige(faction: FactionData) -> float:
	return faction_prestige.get(faction, 0.0)

func add_prestige(faction: FactionData, amount: float) -> void:
	if not faction:
		return
	faction_prestige[faction] = get_prestige(faction) + amount
	EventBus.prestige_changed.emit(faction, faction_prestige[faction])

func spend_prestige(faction: FactionData, amount: float) -> bool:
	if get_prestige(faction) < amount:
		return false
	add_prestige(faction, -amount)
	return true

# --- Tech point helpers ------------------------------------------------------

func get_tech_points(faction: FactionData) -> float:
	return faction_tech_points.get(faction, 0.0)

func add_tech_points(faction: FactionData, amount: float) -> void:
	if not faction:
		return
	faction_tech_points[faction] = get_tech_points(faction) + amount
	EventBus.tech_points_changed.emit(faction, faction_tech_points[faction])

func spend_tech_points(faction: FactionData, amount: float) -> bool:
	if get_tech_points(faction) < amount:
		return false
	add_tech_points(faction, -amount)
	return true

# --- Ship ownership / purchase / deploy --------------------------------------

# True when the faction may deploy this ship without paying: either a starter
# (free fallback) or a previously purchased hull.
func is_ship_owned(faction: FactionData, ship_data: ShipData) -> bool:
	if not ship_data:
		return false
	if ship_data.is_starter:
		return true
	var owned: Dictionary = _owned_ships.get(faction, {})
	return owned.has(ship_data)

# Marks a ship as unlocked for the faction (no prestige is spent here).
func grant_ship(faction: FactionData, ship_data: ShipData) -> void:
	if not faction or not ship_data:
		return
	var owned: Dictionary = _owned_ships.get(faction, {})
	owned[ship_data] = true
	_owned_ships[faction] = owned

# A ship is affordable when already owned (free redeploy) or the faction holds
# enough prestige to cover its purchase cost.
func can_afford_ship(faction: FactionData, ship_data: ShipData) -> bool:
	if not ship_data:
		return false
	if is_ship_owned(faction, ship_data):
		return true
	return get_prestige(faction) >= ship_data.purchase_cost

# Spends prestige to unlock a ship. Returns false (and changes nothing) when the
# faction can't afford it. Already-owned ships succeed for free. Emits
# EventBus.ship_purchased on a fresh unlock so HUD/audio can react.
func purchase_ship(faction: FactionData, ship_data: ShipData) -> bool:
	if not faction or not ship_data:
		return false
	if is_ship_owned(faction, ship_data):
		return true
	if not spend_prestige(faction, ship_data.purchase_cost):
		return false
	grant_ship(faction, ship_data)
	EventBus.ship_purchased.emit(faction, ship_data)
	return true

# Records the faction's active deployment choice and persists the resource paths
# so a respawn/redeploy uses it. Emits EventBus.ship_deployed.
func set_current_ship(faction: FactionData, ship_data: ShipData) -> void:
	if not faction or not ship_data:
		return
	_current_ship[faction] = ship_data
	if faction == player_faction:
		selected_ship_data_path = ship_data.resource_path
		if ship_data.ship_scene:
			selected_ship_scene_path = ship_data.ship_scene.resource_path
	EventBus.ship_deployed.emit(faction, ship_data)

func get_current_ship(faction: FactionData) -> ShipData:
	return _current_ship.get(faction, null) as ShipData

# --- Planet / majority queries ----------------------------------------------

func get_planet_count(faction: FactionData) -> int:
	var count := 0
	for f in planet_ownership.values():
		if f == faction:
			count += 1
	return count

func get_total_planets() -> int:
	return planet_ownership.size()

func get_majority_faction() -> FactionData:
	var total := planet_ownership.size()
	if total == 0:
		return null
	var counts := {}
	for f in planet_ownership.values():
		if f:
			counts[f] = counts.get(f, 0) + 1
	for f in counts:
		if counts[f] > total / 2.0:
			return f
	return null

func is_homebase_shield_active(faction: FactionData) -> bool:
	return _shield_active.get(faction, true)

# --- Signal handlers ---------------------------------------------------------

func _on_planet_captured(planet: Planet, new_owner: FactionData) -> void:
	planet_ownership[planet] = new_owner
	add_prestige(new_owner, CAPTURE_REWARD)
	_recompute_majority()

func _on_ship_destroyed(ship: Ship, killer: Node2D) -> void:
	if not ship or not ship.ship_data:
		return
	# Death penalty to the destroyed ship's faction.
	add_prestige(ship.faction_data, -ship.ship_data.death_penalty)
	# Kill bounty to the killer's faction (no reward for friendly fire / suicide).
	if killer and killer is Ship and killer.faction_data != ship.faction_data:
		add_prestige(killer.faction_data, ship.ship_data.kill_bounty)

# --- Homebase shield interlock -----------------------------------------------

func _recompute_majority() -> void:
	var majority := get_majority_faction()
	for f in _homebase_factions:
		# A homebase is vulnerable when a DIFFERENT faction controls the majority.
		var vulnerable: bool = majority != null and majority != f
		var desired_active: bool = not vulnerable
		if _shield_target.get(f, true) != desired_active:
			_shield_target[f] = desired_active
			_shield_timer[f] = SHIELD_WARNING_DELAY
			EventBus.homebase_shield_warning.emit(f, desired_active)

func _tick_shields(delta: float) -> void:
	for f in _homebase_factions:
		if _shield_active.get(f) == _shield_target.get(f):
			continue
		_shield_timer[f] -= delta
		if _shield_timer[f] <= 0.0:
			_shield_active[f] = _shield_target[f]
			EventBus.homebase_shield_toggled.emit(f, _shield_active[f])

func _tick_income() -> void:
	for planet in planet_ownership:
		if not is_instance_valid(planet):
			continue
		var owner: FactionData = planet_ownership[planet]
		if owner and planet.planet_data:
			add_prestige(owner, planet.planet_data.income_per_second)

func clear_menu_selection() -> void:
	selected_faction_id = ""
	selected_faction_path = ""
	selected_ship_data_path = ""
	selected_ship_scene_path = ""
	selected_enemy_faction_path = ""
	selected_enemy_ship_data_path = ""
	selected_enemy_ship_scene_path = ""
