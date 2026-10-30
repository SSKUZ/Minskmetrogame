extends Node3D
## Minimal native Godot 4 Android performance probe. No legacy Three.js runtime.
## Touch: drag to orbit, pinch to zoom. Screen shows FPS/frame time/memory.

var camera: Camera3D
var hud: Label
var yaw := 0.0
var pitch := -0.2
var distance := 7.0
var drag_finger := -1
var touches: Dictionary = {}
var pinch_distance := 0.0
var elapsed := 0.0
var min_fps := 100000.0
var total_frames := 0
var frame_time_sum := 0.0

func _ready() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.08, 0.1, 0.13)
	world.environment = env
	add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, 35, 0)
	add_child(light)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.5, 1.5, 1.5)
	mesh.mesh = box
	add_child(mesh)
	camera = Camera3D.new()
	camera.current = true
	add_child(camera)
	_update_camera()
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Label.new()
	hud.position = Vector2(22, 22)
	hud.add_theme_font_size_override("font_size", 23)
	layer.add_child(hud)

func _process(delta: float) -> void:
	elapsed += delta
	total_frames += 1
	frame_time_sum += delta
	if elapsed >= 3.0:
		var fps := Engine.get_frames_per_second()
		min_fps = minf(min_fps, fps)
		var memory_mb := float(Performance.get_monitor(Performance.MEMORY_STATIC)) / 1048576.0
		hud.text = "Metro 2.0 / P1 native probe\nFPS: %d (min sample: %d)\nFrame: %.1f ms (avg %.1f)\nStatic memory: %.1f MiB\nTriangles: %d\nDraw calls: %d\nTouch drag: orbit / pinch: zoom" % [
			fps, int(min_fps), delta * 1000.0, frame_time_sum / float(total_frames) * 1000.0,
			memory_mb, int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
			int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))]
		elapsed = 0.0

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			touches[event.index] = event.position
			if drag_finger == -1:
				drag_finger = event.index
		else:
			touches.erase(event.index)
			if event.index == drag_finger:
				drag_finger = -1
				if touches.size() > 0:
					drag_finger = touches.keys()[0]
			pinch_distance = 0.0
	elif event is InputEventScreenDrag:
		touches[event.index] = event.position
		if touches.size() == 1 and event.index == drag_finger:
			yaw -= event.relative.x * 0.008
			pitch = clampf(pitch - event.relative.y * 0.008, -1.3, 1.3)
			_update_camera()
		elif touches.size() >= 2:
			var ids := touches.keys()
			var current: float = touches[ids[0]].distance_to(touches[ids[1]])
			if pinch_distance > 0.0:
				distance = clampf(distance * pinch_distance / maxf(current, 1.0), 2.0, 25.0)
				_update_camera()
			pinch_distance = current
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		yaw -= event.relative.x * 0.008
		pitch = clampf(pitch - event.relative.y * 0.008, -1.3, 1.3)
		_update_camera()

func _update_camera() -> void:
	if camera == null:
		return
	camera.position = Vector3(
		distance * sin(yaw) * cos(pitch),
		2.0 + distance * sin(pitch),
		distance * cos(yaw) * cos(pitch))
	camera.look_at(Vector3.ZERO, Vector3.UP)
