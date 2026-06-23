extends SceneTree

const TITLE_SCENE_PATH := "res://ui/TitleScreen.tscn"
const FACTION_SCENE_PATH := "res://ui/FactionSelectionScreen.tscn"
const OPTIONS_SCENE_PATH := "res://ui/OptionsScreen.tscn"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []

	_validate_scene_nodes(
		TITLE_SCENE_PATH,
		[
			^"MenuPanel/VBox/PlayButton",
			^"MenuPanel/VBox/MultiplayerButton",
			^"MenuPanel/VBox/OptionsButton",
			^"MenuPanel/VBox/ExitButton"
		],
		failures
	)

	_validate_scene_nodes(
		FACTION_SCENE_PATH,
		[
			^"LeftPanel/VBox/SolarisButton",
			^"LeftPanel/VBox/ZerekButton",
			^"LeftPanel/VBox/AegisButton",
			^"RightPanel/VBox/DescriptionLabel",
			^"PlayButton"
		],
		failures
	)

	_validate_scene_nodes(
		OPTIONS_SCENE_PATH,
		[
			^"MainPanel/VBox/MasterVolumeSlider",
			^"MainPanel/VBox/SfxVolumeSlider",
			^"MainPanel/VBox/ActionRow/ActionSelector",
			^"MainPanel/VBox/KeyRow/KeySelector",
			^"MainPanel/VBox/ApplyButton",
			^"MainPanel/VBox/BackButton"
		],
		failures
	)

	await _validate_faction_play_gate(failures)

	if failures.is_empty():
		print("[TEST] MenuFlowSmokeCheck passed")
		quit(0)
		return

	for failure in failures:
		push_error("[TEST] %s" % failure)
	quit(1)

func _validate_scene_nodes(scene_path: String, required_nodes: Array[NodePath], failures: Array[String]) -> void:
	var packed_scene := load(scene_path) as PackedScene
	if not packed_scene:
		failures.append("Failed to load scene: %s" % scene_path)
		return

	var instance := packed_scene.instantiate() as Node
	if not instance:
		failures.append("Failed to instantiate scene: %s" % scene_path)
		return

	root.add_child(instance)
	for node_path: NodePath in required_nodes:
		if not instance.get_node_or_null(node_path):
			failures.append("Missing node '%s' in scene %s" % [node_path, scene_path])
	instance.queue_free()

func _validate_faction_play_gate(failures: Array[String]) -> void:
	var packed_scene := load(FACTION_SCENE_PATH) as PackedScene
	if not packed_scene:
		failures.append("Failed to load faction scene for play-gate validation")
		return

	var faction_screen := packed_scene.instantiate() as Control
	if not faction_screen:
		failures.append("Failed to instantiate faction screen for play-gate validation")
		return

	root.add_child(faction_screen)
	await process_frame

	var play_button := faction_screen.get_node_or_null(^"PlayButton") as Button
	if not play_button:
		failures.append("Faction scene is missing PlayButton")
		faction_screen.queue_free()
		return

	if not play_button.disabled:
		failures.append("PlayButton should be disabled before any faction selection")

	var solaris_button := faction_screen.get_node_or_null(^"LeftPanel/VBox/SolarisButton") as Button
	if not solaris_button:
		failures.append("Faction scene is missing SolarisButton")
		faction_screen.queue_free()
		return

	solaris_button.emit_signal("pressed")
	await process_frame

	if play_button.disabled:
		failures.append("PlayButton should be enabled after selecting a faction")

	faction_screen.queue_free()
