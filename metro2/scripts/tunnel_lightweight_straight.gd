extends Node3D
## Lightweight straight metro tunnel: 16m modular shell, no branches or signals.
const MODULE_LENGTH := 16.0
@export var module_count := 6
@export var start_z := 254.0
@export var center_x := 0.992
@export var lit_every := 2
const PROFILE := [
    Vector2(-3.15, 0.05), Vector2(-3.15, 3.25),
    Vector2(-2.92, 4.75), Vector2(-2.25, 6.1),
    Vector2(-1.25, 6.8), Vector2(0.0, 7.0),
    Vector2(1.25, 6.8), Vector2(2.25, 6.1),
    Vector2(2.92, 4.75), Vector2(3.15, 3.25),
    Vector2(3.15, 0.05)
]
var concrete: StandardMaterial3D
var seam_mat: StandardMaterial3D
var rail_mat: StandardMaterial3D
var wood_mat: StandardMaterial3D
var _sections: Array[Node3D] = []
var _train: Node3D

func _ready() -> void:
    concrete = _material(Color(0.23, 0.24, 0.235), 0.98)
    seam_mat = _material(Color(0.105, 0.11, 0.115), 1.0)
    rail_mat = _material(Color(0.36, 0.38, 0.4), 0.48)
    wood_mat = _material(Color(0.10, 0.085, 0.07), 1.0)
    # One shared mesh and material per repeated element, rather than hundreds of nodes.
    var shell := _make_shell()
    var floor_mesh := BoxMesh.new()
    floor_mesh.size = Vector3(6.32, 0.18, MODULE_LENGTH)
    var rail_mesh := BoxMesh.new()
    rail_mesh.size = Vector3(0.095, 0.16, MODULE_LENGTH)
    var sleeper_mesh := BoxMesh.new()
    sleeper_mesh.size = Vector3(2.3, 0.12, 0.23)
    _train = get_parent().get_node_or_null("PlayerTrainPlacement") as Node3D
    for i in range(module_count):
        var section_root := Node3D.new()
        section_root.name = "ReusableTunnel16m_%d" % i
        add_child(section_root)
        _sections.append(section_root)
        var z0 := start_z + float(i) * MODULE_LENGTH
        var shell_node := MeshInstance3D.new()
        shell_node.mesh = shell
        shell_node.material_override = concrete
        shell_node.position = Vector3(center_x, 0, z0)
        section_root.add_child(shell_node)
        var floor_node := MeshInstance3D.new()
        floor_node.mesh = floor_mesh
        floor_node.material_override = concrete
        floor_node.position = Vector3(center_x, -0.29, z0 + 8.0)
        section_root.add_child(floor_node)
        for side in [-0.9, 0.9]:
            var rail := MeshInstance3D.new()
            rail.mesh = rail_mesh
            rail.material_override = rail_mat
            rail.position = Vector3(center_x + side, -0.08, z0 + 8.0)
            section_root.add_child(rail)
        var sleepers := MultiMeshInstance3D.new()
        var mm := MultiMesh.new()
        mm.transform_format = MultiMesh.TRANSFORM_3D
        mm.mesh = sleeper_mesh
        mm.instance_count = 24
        for j in range(24):
            mm.set_instance_transform(j, Transform3D(Basis(), Vector3(center_x, -0.22, z0 + 0.33 + float(j) * 0.65)))
        sleepers.multimesh = mm
        sleepers.material_override = wood_mat
        section_root.add_child(sleepers)
        if i % maxi(1, lit_every) == 0:
            var lamp := OmniLight3D.new()
            lamp.position = Vector3(center_x - 2.8, 3.3, z0 + 8.0)
            lamp.light_color = Color(0.77, 0.85, 1.0)
            lamp.light_energy = 0.55
            lamp.omni_range = 17.0
            lamp.shadow_enabled = false
            section_root.add_child(lamp)

func _process(_delta: float) -> void:
    if _train == null:
        return
    var train_z := _train.global_position.z
    # Keep six 16m sections, recycle those behind the train to its front.
    for section in _sections:
        var index := _sections.find(section)
        var center_z := start_z + float(index) * MODULE_LENGTH + 8.0 + section.position.z
        if center_z > train_z + 48.0:
            section.position.z -= float(module_count) * MODULE_LENGTH

func _material(color: Color, roughness_value: float) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.roughness = roughness_value
    m.cull_mode = BaseMaterial3D.CULL_DISABLED
    return m

func _make_shell() -> ArrayMesh:
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    for j in range(PROFILE.size() - 1):
        var a: Vector2 = PROFILE[j]
        var b: Vector2 = PROFILE[j + 1]
        var v0 := Vector3(a.x, a.y, 0.0)
        var v1 := Vector3(b.x, b.y, 0.0)
        var v2 := Vector3(a.x, a.y, MODULE_LENGTH)
        var v3 := Vector3(b.x, b.y, MODULE_LENGTH)
        st.add_vertex(v0)
        st.add_vertex(v2)
        st.add_vertex(v1)
        st.add_vertex(v1)
        st.add_vertex(v2)
        st.add_vertex(v3)
    st.generate_normals()
    return st.commit()
