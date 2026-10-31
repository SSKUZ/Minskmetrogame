extends Node3D
## P2 synthetic GPU/CPU stress benchmark; no legacy assets.
## Geometry budgets are approximate and reported as ACTUAL generated triangle counts.

const TARGET_TRIANGLES := [10000, 50000, 100000, 250000, 500000, 1000000]
const TARGET_OBJECTS := [25, 50, 100, 150, 250, 400]
const SAMPLE_WINDOW := 600
const WARMUP_SECONDS := 3.0

var current_level := -1
var camera: Camera3D
var info: Label
var status: Label
var level_root: Node3D
var frame_samples: Array[float] = []
var level_elapsed := 0.0
var generated_triangles := 0
var generated_objects := 0
var yaw := 0.0
var pitch := -0.35
var distance := 55.0
var touch_positions: Dictionary = {}
var last_pinch_distance := 0.0

func _ready() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.055, 0.075, 0.11)
	world.environment = env
	add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, 25, 0)
	add_child(light)
	camera = Camera3D.new()
	camera.current = true
	camera.far = 500.0
	add_child(camera)
	_update_camera()
	level_root = Node3D.new()
	add_child(level_root)
	var ui := CanvasLayer.new()
	add_child(ui)
	var box := VBoxContainer.new()
	box.position = Vector2(14, 14)
	box.add_theme_constant_override("separation", 7)
	ui.add_child(box)
	var heading := Label.new()
	heading.text = "METRO 2.0 / P2 STRESS TEST"
	heading.add_theme_font_size_override("font_size", 24)
	box.add_child(heading)
	var buttons := GridContainer.new()
	buttons.columns = 3
	box.add_child(buttons)
	for i in range(TARGET_TRIANGLES.size()):
		var button := Button.new()
		button.text = "%sK" % str(TARGET_TRIANGLES[i] / 1000)
		if TARGET_TRIANGLES[i] >= 1000000:
			button.text = "1M"
		button.custom_minimum_size = Vector2(125, 48)
		button.pressed.connect(_set_level.bind(i))
		buttons.add_child(button)
	info = Label.new()
	info.add_theme_font_size_override("font_size", 20)
	box.add_child(info)
	status = Label.new()
	status.text = "Drag: orbit | pinch: zoom | select a level"
	box.add_child(status)
	_set_level(0)

func _make_grid_mesh(segments: int) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	for y in range(segments + 1):
		for x in range(segments + 1):
			var fx := float(x) / float(segments)
			var fy := float(y) / float(segments)
			vertices.append(Vector3((fx - 0.5) * 2.0, 0.13 * sin(fx * 16.0) * cos(fy * 16.0), (fy - 0.5) * 2.0))
			normals.append(Vector3.UP)
	for y in range(segments):
		for x in range(segments):
			var a := y * (segments + 1) + x
			var b := a + 1
			var c := a + segments + 1
			var d := c + 1
			indices.append_array(PackedInt32Array([a, c, b, b, c, d]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _set_level(level: int) -> void:
	if level < 0 or level >= TARGET_TRIANGLES.size():
		return
	for child in level_root.get_children():
		level_root.remove_child(child)
		child.queue_free()
	current_level = level
	var objects: int = TARGET_OBJECTS[level]
	var segments := maxi(1, roundi(sqrt(float(TARGET_TRIANGLES[level]) / (2.0 * float(objects)))))
	var mesh := _make_grid_mesh(segments)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.19, 0.65, 0.9)
	material.metallic = 0.15
	material.roughness = 0.6
	mesh.surface_set_material(0, material)
	var cols := ceili(sqrt(float(objects)))
	for i in range(objects):
		var node := MeshInstance3D.new()
		node.mesh = mesh
		node.position = Vector3(float(i % cols) * 2.3 - float(cols) * 1.15, 0, float(i / cols) * 2.3 - float(cols) * 1.15)
		level_root.add_child(node)
	generated_objects = objects
	generated_triangles = objects * 2 * segments * segments
	frame_samples.clear()
	level_elapsed = 0.0
	status.text = "Level %d / 6 | warmup %.0f sec | orbit/pinch to stress" % [level + 1, WARMUP_SECONDS]

func _process(delta: float) -> void:
	level_elapsed += delta
	if level_elapsed >= WARMUP_SECONDS and delta > 0.0:
		frame_samples.append(delta * 1000.0)
		if frame_samples.size() > SAMPLE_WINDOW:
			frame_samples.pop_front()
	if Engine.get_process_frames() % 15 != 0:
		return
	var current_fps := Engine.get_frames_per_second()
	var avg_fps := 0.0
	var p95_ms := 0.0
	var low_fps := 0.0
	if not frame_samples.is_empty():
		var sorted := frame_samples.duplicate()
		sorted.sort()
		var sum_ms := 0.0
		for ms in sorted:
			sum_ms += ms
		avg_fps = 1000.0 * float(sorted.size()) / sum_ms
		p95_ms = sorted[mini(sorted.size() - 1, int(float(sorted.size() - 1) * 0.95))]
		var p99_ms: float = sorted[mini(sorted.size() - 1, int(float(sorted.size() - 1) * 0.99))]
		low_fps = 1000.0 / maxf(p99_ms, 0.01)
	var static_mb := float(Performance.get_monitor(Performance.MEMORY_STATIC)) / 1048576.0
	var reported_calls := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var reported_tris := int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	info.text = "Level: %d/6 | FPS now: %d\nAvg FPS: %.1f | 1%% low (frame p99): %.1f\nFrame p95: %.1f ms | samples: %d\nGenerated triangles: %d | objects: %d\nRendered triangles: %d | draw calls: %d\nGodot static memory: %.1f MiB\nElapsed: %.0f s (warmup excluded)" % [
		current_level + 1, current_fps, avg_fps, low_fps,
		p95_ms, frame_samples.size(), generated_triangles, generated_objects,
		reported_tris, reported_calls, static_mb, level_elapsed]

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			touch_positions[event.index] = event.position
		else:
			touch_positions.erase(event.index)
			last_pinch_distance = 0.0
	elif event is InputEventScreenDrag:
		touch_positions[event.index] = event.position
		if touch_positions.size() == 1:
			yaw -= event.relative.x * 0.007
			pitch = clampf(pitch - event.relative.y * 0.007, -1.3, 1.3)
			_update_camera()
		elif touch_positions.size() >= 2:
			var keys := touch_positions.keys()
			var new_distance: float = touch_positions[keys[0]].distance_to(touch_positions[keys[1]])
			if last_pinch_distance > 0.0:
				distance = clampf(distance * last_pinch_distance / maxf(new_distance, 1.0), 12.0, 180.0)
				_update_camera()
			last_pinch_distance = new_distance
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		yaw -= event.relative.x * 0.007
		pitch = clampf(pitch - event.relative.y * 0.007, -1.3, 1.3)
		_update_camera()

func _update_camera() -> void:
	if camera == null:
		return
	camera.position = Vector3(distance * sin(yaw) * cos(pitch), 12.0 + distance * sin(pitch), distance * cos(yaw) * cos(pitch))
	camera.look_at(Vector3.ZERO, Vector3.UP)
