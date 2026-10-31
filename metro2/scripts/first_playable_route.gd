extends Node3D
## First playable route: visual tunnel approach and exit around Station Base.
## The station remains the existing StationBaseStatic scene.
## This is scenery only; no collision, signals, or lighting automation yet.

const TRACK_X := 0.0
const TUNNEL_SECTIONS := [
    Vector2(110.0, 310.0), # approach, train travels toward decreasing Z
    Vector2(-220.0, -70.0), # departure
]

func _ready() -> void:
    var wall := StandardMaterial3D.new()
    wall.albedo_color = Color(0.26, 0.29, 0.32)
    wall.roughness = 0.94
    var ceiling := StandardMaterial3D.new()
    ceiling.albedo_color = Color(0.32, 0.34, 0.36)
    var lamp_mat := StandardMaterial3D.new()
    lamp_mat.albedo_color = Color(1.0, 0.93, 0.73)
    lamp_mat.emission_enabled = true
    lamp_mat.emission = Color(1.0, 0.89, 0.64)
    lamp_mat.emission_energy_multiplier = 1.5

    for section in TUNNEL_SECTIONS:
        var start_z: float = section.x
        var end_z: float = section.y
        var length: float = end_z - start_z
        var center_z: float = (start_z + end_z) * 0.5
        var segment := Node3D.new()
        segment.name = "Tunnel_%d_%d" % [int(start_z), int(end_z)]
        add_child(segment)
        _box(segment, "LeftWall", Vector3(0.35, 5.2, length),
            Vector3(TRACK_X - 3.1, 2.3, center_z), wall)
        _box(segment, "RightWall", Vector3(0.35, 5.2, length),
            Vector3(TRACK_X + 3.1, 2.3, center_z), wall)
        _box(segment, "Roof", Vector3(6.55, 0.35, length),
            Vector3(TRACK_X, 5.05, center_z), ceiling)
        var z: float = start_z + 8.0
        while z < end_z:
            _box(segment, "Lamp", Vector3(0.32, 0.06, 0.7),
                Vector3(TRACK_X, 4.82, z), lamp_mat)
            z += 14.0

func _box(parent: Node3D, label: String, size: Vector3,
        position: Vector3, material: Material) -> void:
    var instance := MeshInstance3D.new()
    instance.name = label
    var mesh := BoxMesh.new()
    mesh.size = size
    mesh.material = material
    instance.mesh = mesh
    instance.position = position
    parent.add_child(instance)
