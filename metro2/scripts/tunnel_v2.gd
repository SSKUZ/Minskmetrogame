extends Node3D
## Tunnel V2: native Godot mobile geometry, browser 'testing' as visual reference.
## Existing StationBaseStatic rails and sleepers are authoritative; no duplicates.
const SECTIONS := [Vector2(110.0, 310.0), Vector2(-220.0, -70.0)]
const PROFILE := [
    Vector2(-3.15, 0.05), Vector2(-3.15, 3.3), Vector2(-2.94, 4.8),
    Vector2(-2.25, 6.15), Vector2(-1.25, 6.85), Vector2(0.0, 7.05),
    Vector2(1.25, 6.85), Vector2(2.25, 6.15), Vector2(2.94, 4.8),
    Vector2(3.15, 3.3), Vector2(3.15, 0.05)
]
const RIB_STEP := 8.0
const LIGHT_STEP := 16.0

func _ready() -> void:
    var concrete := _mat(Color("#171b20"))
    var ribs := _mat(Color("#303840"))
    var cable_colors := [_mat(Color("#10161b")), _mat(Color("#253d49")), _mat(Color("#302a28"))]
    var fixture := _mat(Color("#62696b"))
    var signal_body := _mat(Color("#101619"))
    var glow := _mat(Color("#e5f5ff"), true)
    var red := _mat(Color("#ff2828"), true)
    var green := _mat(Color("#26ff73"), true)
    for section in SECTIONS:
        var root := Node3D.new()
        root.name = "TunnelV2_%d_%d" % [int(section.x), int(section.y)]
        add_child(root)
        _shell(root, section.x, section.y, concrete)
        _ribs(root, section.x, section.y, ribs)
        _cables(root, section.x, section.y, cable_colors)
        _repeat_boxes(root, "WallLights", Vector3(0.11, 0.62, 0.25), glow,
            Vector3(-3.02, 3.3, section.x + 8.0), Vector3(0, 0, LIGHT_STEP),
            maxi(0, int((section.y - section.x - 8.0) / LIGHT_STEP) + 1))
        for side in [-1, 1]:
            _repeat_boxes(root, "CableBrackets", Vector3(0.15, 0.08, 0.25), ribs,
                Vector3(side * 3.04, 1.55, section.x + 3.0), Vector3(0, 0, 7.0),
                maxi(0, int((section.y - section.x - 3.0) / 7.0) + 1))
            _repeat_boxes(root, "UpperBrackets", Vector3(0.15, 0.08, 0.25), ribs,
                Vector3(side * 3.04, 2.58, section.x + 3.0), Vector3(0, 0, 7.0),
                maxi(0, int((section.y - section.x - 3.0) / 7.0) + 1))
            var z := section.x + 24.0
            while z < section.y:
                _box(root, "ServiceCabinet", Vector3(0.22, 0.82, 0.86),
                    Vector3(side * 2.97, 2.35, z), fixture)
                _box(root, "CabinetDoor", Vector3(0.235, 0.68, 0.69),
                    Vector3(side * 2.82, 2.35, z), ribs)
                z += 96.0
        var signal_z := section.x + 64.0
        while signal_z < section.y - 12.0:
            _signal(root, signal_z, signal_body, ribs, red, green, int(signal_z) % 2 == 0)
            signal_z += 128.0

func _shell(parent: Node3D, z0: float, z1: float, material: Material) -> void:
    # One combined arch surface per section, rather than a MeshInstance per panel.
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    for i in range(PROFILE.size() - 1):
        var a: Vector2 = PROFILE[i]
        var b: Vector2 = PROFILE[i + 1]
        var p0 := Vector3(a.x, a.y, z0)
        var p1 := Vector3(b.x, b.y, z0)
        var p2 := Vector3(b.x, b.y, z1)
        var p3 := Vector3(a.x, a.y, z1)
        for p in [p0, p1, p2, p0, p2, p3]:
            st.add_vertex(p)
    st.generate_normals()
    var mesh := st.commit()
    var instance := MeshInstance3D.new()
    instance.name = "CombinedArch"
    instance.mesh = mesh
    instance.material_override = material
    parent.add_child(instance)

func _ribs(parent: Node3D, z0: float, z1: float, material: Material) -> void:
    var mesh := BoxMesh.new()
    mesh.size = Vector3(0.065, 1.0, 0.095)
    mesh.material = material
    var count := maxi(0, int((z1 - z0 - 4.0) / RIB_STEP) + 1)
    var mm := MultiMesh.new()
    mm.transform_format = MultiMesh.TRANSFORM_3D
    mm.mesh = mesh
    mm.instance_count = count * (PROFILE.size() - 1)
    var index := 0
    for j in range(count):
        var z := z0 + 4.0 + j * RIB_STEP
        for k in range(PROFILE.size() - 1):
            var a: Vector2 = PROFILE[k]
            var b: Vector2 = PROFILE[k + 1]
            var length := a.distance_to(b)
            var angle := -atan2(b.x - a.x, b.y - a.y)
            var basis := Basis(Vector3.BACK, angle).scaled(Vector3(1, length, 1))
            mm.set_instance_transform(index, Transform3D(basis,
                Vector3((a.x + b.x) * 0.5, (a.y + b.y) * 0.5, z)))
            index += 1
    var inst := MultiMeshInstance3D.new()
    inst.name = "ConcreteRibs"
    inst.multimesh = mm
    parent.add_child(inst)

func _cables(parent: Node3D, z0: float, z1: float, materials: Array) -> void:
    # A single combined line mesh per material; gentle sag like the browser tunnel.
    for color_index in range(3):
        var st := SurfaceTool.new()
        st.begin(Mesh.PRIMITIVE_TRIANGLES)
        for side in [-1, 1]:
            for cable_index in range(color_index, 6, 3):
                var offset := cable_index * 0.075
                var y := 1.45 + cable_index * 0.22
                var segments := maxi(4, int((z1 - z0) / 3.2))
                for j in range(segments):
                    var za := lerpf(z0, z1, float(j) / segments)
                    var zb := lerpf(z0, z1, float(j + 1) / segments)
                    var xa := side * (3.12 - offset * 0.32 + 0.025 * sin(za * 0.375 + offset * 12.0))
                    var xb := side * (3.12 - offset * 0.32 + 0.025 * sin(zb * 0.375 + offset * 12.0))
                    var ya := y + 0.055 * sin(za * 0.325 + offset * 6.0)
                    var yb := y + 0.055 * sin(zb * 0.325 + offset * 6.0)
                    # Flat ribbon cable: visible and inexpensive at driving distance.
                    var w := 0.045
                    var a := Vector3(xa, ya - w, za)
                    var b := Vector3(xa, ya + w, za)
                    var c := Vector3(xb, yb + w, zb)
                    var d := Vector3(xb, yb - w, zb)
                    for p in [a, b, c, a, c, d]:
                        st.add_vertex(p)
        st.generate_normals()
        var instance := MeshInstance3D.new()
        instance.name = "CableBundle%d" % color_index
        instance.mesh = st.commit()
        instance.material_override = materials[color_index]
        parent.add_child(instance)

func _signal(parent: Node3D, z: float, body: Material, metal: Material,
        red: Material, green: Material, is_green: bool) -> void:
    _box(parent, "SignalPost", Vector3(0.13, 4.2, 0.16), Vector3(-2.82, 2.15, z), metal)
    _box(parent, "SignalHead", Vector3(0.48, 1.17, 0.26), Vector3(-2.77, 4.2, z), body)
    _box(parent, "SignalGreen", Vector3(0.29, 0.29, 0.035),
        Vector3(-2.77, 4.47, z + 0.15), green if is_green else body)
    _box(parent, "SignalRed", Vector3(0.29, 0.29, 0.035),
        Vector3(-2.77, 4.0, z + 0.15), body if is_green else red)

func _repeat_boxes(parent: Node3D, label: String, size: Vector3,
        material: Material, start: Vector3, step: Vector3, count: int) -> void:
    if count <= 0:
        return
    var mesh := BoxMesh.new()
    mesh.size = size
    mesh.material = material
    var mm := MultiMesh.new()
    mm.transform_format = MultiMesh.TRANSFORM_3D
    mm.mesh = mesh
    mm.instance_count = count
    for i in range(count):
        mm.set_instance_transform(i, Transform3D(Basis(), start + step * i))
    var inst := MultiMeshInstance3D.new()
    inst.name = label
    inst.multimesh = mm
    parent.add_child(inst)

func _box(parent: Node3D, label: String, size: Vector3,
        pos: Vector3, material: Material) -> void:
    var mesh := BoxMesh.new()
    mesh.size = size
    mesh.material = material
    var inst := MeshInstance3D.new()
    inst.name = label
    inst.mesh = mesh
    inst.position = pos
    parent.add_child(inst)

func _mat(color: Color, emissive: bool = false) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = 0.9
    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    if emissive:
        mat.emission_enabled = true
        mat.emission = color
        mat.emission_energy_multiplier = 1.3
    return mat
