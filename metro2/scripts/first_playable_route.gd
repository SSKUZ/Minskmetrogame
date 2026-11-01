extends Node3D
## Tunnel geometry adapted from browser js/main.js (feature/mobile-render-diagnostics).
## One continuous Station Base route; existing track geometry remains authoritative.
## Sections stop before the platform to keep the station open.
const SECTIONS := [Vector2(110.0, 310.0), Vector2(-220.0, -70.0)]
const ARCH := [
    Vector2(-3.15, 0.05), Vector2(-3.15, 3.3), Vector2(-2.94, 4.8),
    Vector2(-2.25, 6.15), Vector2(-1.25, 6.85), Vector2(0.0, 7.05),
    Vector2(1.25, 6.85), Vector2(2.25, 6.15), Vector2(2.94, 4.8),
    Vector2(3.15, 3.3), Vector2(3.15, 0.05)
]
var wall_mat: StandardMaterial3D
var rib_mat: StandardMaterial3D
var cable_mats: Array[StandardMaterial3D] = []
var equipment_mat: StandardMaterial3D
var lamp_mat: StandardMaterial3D

func _ready() -> void:
    wall_mat = _material(Color("#171b20"))
    rib_mat = _material(Color("#303840"), 0.3)
    equipment_mat = _material(Color("#62696b"), 0.5)
    cable_mats = [
        _material(Color("#10161b"), 0.3),
        _material(Color("#253d49"), 0.32),
        _material(Color("#302a28"), 0.4)
    ]
    lamp_mat = _material(Color("#e5f5ff"))
    lamp_mat.emission_enabled = true
    lamp_mat.emission = Color("#b7d9f0")
    lamp_mat.emission_energy_multiplier = 0.9
    for section in SECTIONS:
        _build_section(section.x, section.y)

func _build_section(start_z: float, end_z: float) -> void:
    var root := Node3D.new()
    root.name = "Tunnel_%d_%d" % [int(start_z), int(end_z)]
    add_child(root)
    var length := end_z - start_z
    var center := (start_z + end_z) * 0.5
    # Faceted concrete arch, based on the browser tunnel cross-section.
    for i in range(ARCH.size() - 1):
        var a: Vector2 = ARCH[i]
        var b: Vector2 = ARCH[i + 1]
        _arch_panel(root, a, b, center, length, 0.22, wall_mat)
    # Periodic transverse concrete ribs.
    var z := start_z + 4.0
    while z < end_z:
        for i in range(ARCH.size() - 1):
            _arch_panel(root, ARCH[i], ARCH[i + 1], z, 0.095, 0.065, rib_mat)
        z += 8.0
    # Six cable runs on each wall, with mounting brackets and service cabinets.
    for side in [-1, 1]:
        for k in range(6):
            var x: float = side * (3.12 - float(k) * 0.075 * 0.32)
            var y: float = 1.45 + float(k) * 0.22
            _cable(root, x, y, start_z, end_z, 0.045 + float(k) * 0.0018, cable_mats[k % 3])
        z = start_z + 3.0
        while z < end_z:
            _box(root, "CableBracket", Vector3(0.15, 0.08, 0.25),
                Vector3(side * 3.04, 1.55, z), rib_mat)
            _box(root, "CableBracket", Vector3(0.15, 0.08, 0.25),
                Vector3(side * 3.04, 2.58, z), rib_mat)
            z += 7.0
        z = start_z + 24.0
        while z < end_z:
            _box(root, "ServiceCabinet", Vector3(0.24, 0.82, 0.86),
                Vector3(side * 2.97, 2.35, z), equipment_mat)
            z += 96.0
    # Visible wall fixtures; no dozens of dynamic lights on mobile.
    z = start_z + 8.0
    while z < end_z:
        _box(root, "WallLamp", Vector3(0.11, 0.62, 0.25),
            Vector3(-3.01, 3.3, z), lamp_mat)
        z += 16.0

func _arch_panel(parent: Node3D, a: Vector2, b: Vector2, z: float,
        depth: float, thickness: float, material: Material) -> void:
    var dx: float = b.x - a.x
    var dy: float = b.y - a.y
    var panel := _box(parent, "Arch", Vector3(thickness, a.distance_to(b), depth),
        Vector3((a.x + b.x) * 0.5, (a.y + b.y) * 0.5, z), material)
    panel.rotation.z = -atan2(dx, dy)

func _cable(parent: Node3D, x: float, y: float, z0: float, z1: float,
        radius: float, material: Material) -> void:
    # One low-poly longitudinal cylinder per run; avoid costly curved tubes.
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = z1 - z0
    mesh.radial_segments = 6
    mesh.material = material
    var instance := MeshInstance3D.new()
    instance.name = "Cable"
    instance.mesh = mesh
    instance.rotation.x = PI * 0.5
    instance.position = Vector3(x, y, (z0 + z1) * 0.5)
    parent.add_child(instance)

func _material(color: Color, metallic: float = 0.0) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.metallic = metallic
    material.roughness = 0.9
    return material

func _box(parent: Node3D, label: String, size: Vector3,
        position: Vector3, material: Material) -> MeshInstance3D:
    var instance := MeshInstance3D.new()
    instance.name = label
    var mesh := BoxMesh.new()
    mesh.size = size
    mesh.material = material
    instance.mesh = mesh
    instance.position = position
    parent.add_child(instance)
    return instance
