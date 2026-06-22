extends SceneTree

const WEAPON_DATA_SCRIPT := preload("res://scripts/resources/WeaponData.gd")
const GATTLING_WEAPON_PATH := "res://resources/weapons/t1_weapon_gattling.tres"

func _initialize() -> void:
	_verify_default_audio_is_empty()
	_verify_gattling_weapon_has_configured_audio()
	_verify_audio_field_accepts_clearing()
	quit(0)

func _verify_default_audio_is_empty() -> void:
	var weapon: WeaponData = WEAPON_DATA_SCRIPT.new()
	assert(weapon.fire_audio == null, "New weapons should default to no fire audio")

func _verify_gattling_weapon_has_configured_audio() -> void:
	var gattling_weapon := load(GATTLING_WEAPON_PATH) as WeaponData
	assert(gattling_weapon != null, "Gattling weapon resource should load as WeaponData")
	assert(gattling_weapon.fire_audio != null, "Gattling weapon should define a fire audio stream")
	assert(
		gattling_weapon.fire_audio.resource_path == "res://assets/audio/laser-short-pulse.mp3",
		"Gattling weapon should point at laser-short-pulse.mp3"
	)

func _verify_audio_field_accepts_clearing() -> void:
	var gattling_weapon := load(GATTLING_WEAPON_PATH) as WeaponData
	assert(gattling_weapon != null, "Gattling weapon resource should load as WeaponData")
	var weapon: WeaponData = WEAPON_DATA_SCRIPT.new()
	weapon.fire_audio = gattling_weapon.fire_audio
	assert(weapon.fire_audio != null, "Audio assignment should work")
	weapon.fire_audio = null
	assert(weapon.fire_audio == null, "Audio should be optional and clearable")