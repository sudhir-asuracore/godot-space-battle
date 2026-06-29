extends Node

# Global signals

# Combat / lifecycle
signal ship_destroyed(ship: Ship, killer: Node2D)

# Planets / conquest
signal planet_captured(planet: Planet, new_owner: FactionData)
# Fog of war: a planet has been identified (visited long enough) by a faction,
# so its properties become readable for that faction.
signal planet_identified(faction: FactionData, planet: Planet)

# Homebase shield interlock network
signal homebase_shield_toggled(faction: FactionData, is_active: bool)
signal homebase_shield_warning(faction: FactionData, will_be_active: bool)
signal homebase_destroyed(faction: FactionData)

# Economy
signal prestige_changed(faction: FactionData, amount: float)
signal tech_points_changed(faction: FactionData, amount: float)
signal hangar_shop_requested(faction: FactionData, ships: Array)

# Hangar purchase / deploy loop (Milestone 7)
signal ship_purchased(faction: FactionData, ship_data: ShipData)
signal ship_deployed(faction: FactionData, ship_data: ShipData)

# Player ship selection (start-of-match picker and hangar swap)
signal player_ship_selected(ship_data: ShipData)

# Map screen (M key) open/close request and map-driven deployment. The map lets
# the player pick a hangar-capable location to (re)deploy the current ship to.
signal map_screen_toggle_requested()
signal map_deploy_requested(ship_data: ShipData, world_position: Vector2)

# Match flow
signal match_ended(winning_faction: FactionData)
