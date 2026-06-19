extends Node

# Global signals

# Combat / lifecycle
signal ship_destroyed(ship: Ship, killer: Node2D)

# Planets / conquest
signal planet_captured(planet: Planet, new_owner: FactionData)

# Homebase shield interlock network
signal homebase_shield_toggled(faction: FactionData, is_active: bool)
signal homebase_shield_warning(faction: FactionData, will_be_active: bool)
signal homebase_destroyed(faction: FactionData)

# Economy
signal prestige_changed(faction: FactionData, amount: float)

# Match flow
signal match_ended(winning_faction: FactionData)
