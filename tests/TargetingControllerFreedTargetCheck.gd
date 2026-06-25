extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []

	var controller := TargetingController.new()
	root.add_child(controller)
	controller.set_process(false)

	var target := Node2D.new()
	root.add_child(target)
	target.queue_free()
	await process_frame

	var result: Variant = controller.call("_is_target_still_attackable", target)
	if result != false:
		failures.append("Expected freed target validation to return false, got: %s" % [result])

	controller.queue_free()

	if failures.is_empty():
		print("[TEST] TargetingControllerFreedTargetCheck passed")
		quit(0)
		return

	for failure in failures:
		push_error("[TEST] %s" % failure)
	quit(1)