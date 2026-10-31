extends Node3D

const MODELS = {
 "ORIGINAL": "res://assets/v106/v106_car_01.glb",
 "HIGH": "res://assets/v106_mobile/v106_car01_mobile.glb",
 "MEDIUM": "res://assets/v106_mobile/medium/v106_car01_medium.glb",
 "LOW": "res://assets/v106_mobile/low/v106_car01_low.glb"
}
var model: Node3D
var camera := Camera3D.new()
var status := Label.new()
var selected := ""
var yaw := 0.8
var pitch := 0.2
var distance := 27.0
var target := Vector3(0, 1.8, 0)
var fingers: Dictionary = {}

func _ready() -> void:
 add_child(camera)
 camera.near = 0.03
 camera.far = 150.0
 camera.current = true
 get_viewport().mesh_lod_threshold = 0.0
 var layer := CanvasLayer.new()
 add_child(layer)
 var panel := VBoxContainer.new()
 panel.position = Vector2(18, 18)
 layer.add_child(panel)
 var row := HBoxContainer.new()
 panel.add_child(row)
 for variant in MODELS:
  var button := Button.new()
  button.text = variant
  button.custom_minimum_size = Vector2(145, 58)
  button.pressed.connect(_select.bind(variant))
  row.add_child(button)
 panel.add_child(status)
 var controls := HBoxContainer.new()
 panel.add_child(controls)
 for caption in ["+", "−", "INTERIOR", "EXTERIOR"]:
  var button := Button.new()
  button.text = caption
  button.custom_minimum_size = Vector2(145, 54)
  button.pressed.connect(_view.bind(caption))
  controls.add_child(button)
 var hint := Label.new()
 hint.text = "Drag: rotate · Pinch / + −: zoom · Two fingers: move"
 panel.add_child(hint)
 _select("ORIGINAL")
 _camera_update()

func _select(variant: String) -> void:
 if variant == selected:
  return
 if is_instance_valid(model):
  remove_child(model)
  model.free()
 var scene := load(MODELS[variant]) as PackedScene
 if scene == null:
  push_error("Missing model: " + variant)
  return
 model = scene.instantiate()
 add_child(model)
 selected = variant

func _process(_delta: float) -> void:
 status.text = "%s  |  FPS: %d" % [selected, Engine.get_frames_per_second()]

func _view(caption: String) -> void:
 match caption:
  "+": distance = maxf(0.1, distance * 0.8)
  "−": distance = minf(60.0, distance * 1.25)
  "INTERIOR":
   target = Vector3(0, 2.0, 0)
   distance = 0.15
   yaw = 0.0
   pitch = 0.0
  "EXTERIOR":
   target = Vector3(0, 1.8, 0)
   distance = 27.0
   yaw = 0.8
   pitch = 0.2
 _camera_update()

func _camera_update() -> void:
 camera.position = target + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * distance
 camera.look_at(target)

func _unhandled_input(event: InputEvent) -> void:
 if event is InputEventScreenTouch:
  if event.pressed:
   fingers[event.index] = event.position
  else:
   fingers.erase(event.index)
 elif event is InputEventScreenDrag:
  if not fingers.has(event.index):
   return
  if fingers.size() == 2:
   var keys := fingers.keys()
   var before: float = fingers[keys[0]].distance_to(fingers[keys[1]])
   fingers[event.index] = event.position
   var after: float = fingers[keys[0]].distance_to(fingers[keys[1]])
   if after > 1.0:
    distance = clampf(distance * before / after, 0.1, 60.0)
   target += (-camera.global_basis.x * event.relative.x + camera.global_basis.y * event.relative.y) * 0.006
  else:
   fingers[event.index] = event.position
   yaw -= event.relative.x * 0.006
   pitch = clampf(pitch + event.relative.y * 0.006, -1.45, 1.45)
  _camera_update()
 elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
  yaw -= event.relative.x * 0.006
  pitch = clampf(pitch + event.relative.y * 0.006, -1.45, 1.45)
  _camera_update()
 elif event is InputEventMouseButton and event.pressed:
  if event.button_index == MOUSE_BUTTON_WHEEL_UP: _view("+")
  elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN: _view("−")
