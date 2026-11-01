extends Node3D
## Browser test: saved LOD1 car, existing door controller, cab and screen controls.
const DOOR_SCRIPT = preload("res://scripts/v106_door_controller.gd")
var doors: Node
var car: Node3D
var status: Label
var camera: Camera3D
var cab_button: StaticBody3D
var ray_length := 10.0

func _ready() -> void:
    car = $OptimizedHeadCar
    doors = DOOR_SCRIPT.new()
    add_child(doors)
    # The original controller expects 64 leaves / four cars. This test
    # must not claim functioning doors when only one car is available.
    doors.setup($Train)
    camera = $Camera3D
    _make_ui()
    _make_cab_button()

func _make_ui() -> void:
    var canvas := CanvasLayer.new()
    add_child(canvas)
    var row := HBoxContainer.new()
    row.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
    row.offset_top = -85
    canvas.add_child(row)
    for caption in ["ДВЕРИ ОТКРЫТЬ", "ДВЕРИ ЗАКРЫТЬ"]:
        var button := Button.new()
        button.text = caption
        button.custom_minimum_size = Vector2(220, 72)
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        row.add_child(button)
        if caption == "ДВЕРИ ОТКРЫТЬ":
            button.pressed.connect(func(): doors.request_open(0.0))
        else:
            button.pressed.connect(func(): doors.request_close())
    status = Label.new()
    status.text = "LOD1: двери ожидают полный состав (64 створки)"
    canvas.add_child(status)

func _make_cab_button() -> void:
    cab_button = StaticBody3D.new()
    cab_button.name = "DriverDoorButton3D"
    cab_button.position = Vector3(-0.6, 1.4, 2.0)
    car.add_child(cab_button)
    var mesh := MeshInstance3D.new()
    var cylinder := CylinderMesh.new()
    cylinder.top_radius = 0.10
    cylinder.bottom_radius = 0.10
    cylinder.height = 0.05
    mesh.mesh = cylinder
    var material := StandardMaterial3D.new()
    material.albedo_color = Color(0.1, 0.75, 0.25)
    mesh.material_override = material
    cab_button.add_child(mesh)
    var collision := CollisionShape3D.new()
    var shape := CylinderShape3D.new()
    shape.radius = 0.10
    shape.height = 0.05
    collision.shape = shape
    cab_button.add_child(collision)

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        _click_button(event.position)
    elif event is InputEventScreenTouch and event.pressed:
        _click_button(event.position)

func _click_button(point: Vector2) -> void:
    var origin := camera.project_ray_origin(point)
    var target := origin + camera.project_ray_normal(point) * ray_length
    var query := PhysicsRayQueryParameters3D.create(origin, target)
    var hit := get_world_3d().direct_space_state.intersect_ray(query)
    if hit.get("collider") == cab_button:
        if doors.target_open:
            doors.request_close()
        else:
            doors.request_open(0.0)
