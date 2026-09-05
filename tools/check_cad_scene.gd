extends SceneTree


func _initialize() -> void:
	call_deferred("_check")


func _check() -> void:
	var scene: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var car: Node3D = scene.get_node("FormulaCarMockup")
	var visual: Node3D = car.get_node("Visual")
	var meshes: Array[Node] = visual.find_children("*", "MeshInstance3D", true, false)
	assert(meshes.size() == 44)
	var bounds: AABB
	var first: bool = true
	for child in meshes:
		var mesh: MeshInstance3D = child as MeshInstance3D
		var local_bounds: AABB = (visual.global_transform.affine_inverse() * mesh.global_transform) * mesh.get_aabb()
		bounds = local_bounds if first else bounds.merge(local_bounds)
		first = false
	assert(bounds.size.is_equal_approx(Vector3(1.8, 0.95, 4.5)))
	assert(absf(bounds.position.y) < 0.001)
	var start: Vector3 = car.position
	Input.action_press("throttle")
	await create_timer(0.3).timeout
	Input.action_release("throttle")
	assert(car.position.z < start.z)
	assert(absf(car.position.x - start.x) < 0.001)
	print("CAD integration passed: 44 meshes, metre scale, ground contact, forward movement.")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/cad_preview.png")
	quit()
