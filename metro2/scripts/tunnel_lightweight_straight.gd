extends Node3D
## Straight 16 m modules. Slots cover the complete consist and the camera separately.
const MODULE_LENGTH := 16.0
const VISIBLE_DISTANCE := 56.0
const GUARD_DISTANCE := 16.0
const PROFILE := [
    Vector2(-3.15, -0.29), Vector2(-3.15, 3.25),
    Vector2(-2.92, 4.75), Vector2(-2.25, 6.1),
    Vector2(-1.25, 6.8), Vector2(0.0, 7.0),
    Vector2(1.25, 6.8), Vector2(2.25, 6.1),
    Vector2(2.92, 4.75), Vector2(3.15, 3.25), Vector2(3.15, -0.29)
]
@export var center_x := 0.992
var _train: Node3D
var _camera: Camera3D
var _train_bounds := AABB()
var _active: Dictionary = {}
var _spares: Array[Node3D] = []
var _sections: Array[Node3D] = []
var _shell: ArrayMesh
var _floor: BoxMesh
var _rail: BoxMesh
var _sleepers: MultiMesh
var _joints: ArrayMesh
var _lamp: BoxMesh
var _concrete: StandardMaterial3D
var _steel: StandardMaterial3D
var _wood: StandardMaterial3D
var _seam: StandardMaterial3D
var _glow: StandardMaterial3D
var recycle_count := 0

func _ready() -> void:
    _concrete = _material(Color(0.30, 0.30, 0.28), 0.98)
    _steel = _material(Color(0.43, 0.45, 0.46), 0.4)
    _wood = _material(Color(0.13, 0.105, 0.08), 1.0)
    _seam = _material(Color(0.15, 0.15, 0.14), 1.0)
    _glow = _material(Color(0.72, 0.70, 0.60), 0.8)
    _glow.emission_enabled = true
    _glow.emission = Color(0.72, 0.70, 0.60)
    _glow.emission_energy_multiplier = 1.5
    var shell := SurfaceTool.new()
    shell.begin(Mesh.PRIMITIVE_TRIANGLES)
    for j in range(PROFILE.size() - 1):
        var a: Vector2 = PROFILE[j]
        var b: Vector2 = PROFILE[j + 1]
        for v in [Vector3(a.x,a.y,0), Vector3(a.x,a.y,16), Vector3(b.x,b.y,0),
                Vector3(b.x,b.y,0), Vector3(a.x,a.y,16), Vector3(b.x,b.y,16)]:
            shell.add_vertex(v)
    shell.generate_normals()
    _shell = shell.commit()
    _floor = BoxMesh.new()
    _floor.size = Vector3(6.32, 0.18, MODULE_LENGTH)
    _rail = BoxMesh.new()
    _rail.size = Vector3(0.095, 0.16, MODULE_LENGTH)
    var sleeper := BoxMesh.new()
    sleeper.size = Vector3(2.3, 0.12, 0.23)
    _sleepers = MultiMesh.new()
    _sleepers.transform_format = MultiMesh.TRANSFORM_3D
    _sleepers.mesh = sleeper
    _sleepers.instance_count = 25
    for j in range(25):
        _sleepers.set_instance_transform(j, Transform3D(Basis(), Vector3(0,-0.22,0.32+float(j)*0.64)))
    var joints := SurfaceTool.new()
    joints.begin(Mesh.PRIMITIVE_TRIANGLES)
    var edge := BoxMesh.new()
    edge.size = Vector3(0.025, 1.0, 0.035)
    for z in range(0,16,2):
        for j in range(PROFILE.size()-1):
            var a: Vector2 = PROFILE[j]
            var b: Vector2 = PROFILE[j+1]
            var basis := Basis(Vector3.BACK,-atan2(b.x-a.x,b.y-a.y)).scaled(Vector3(1,a.distance_to(b),1))
            joints.append_from(edge,0,Transform3D(basis,Vector3((a.x+b.x)*0.498,(a.y+b.y)*0.5,float(z))))
    _joints = joints.commit()
    _lamp = BoxMesh.new()
    _lamp.size = Vector3(0.08,0.16,0.8)

func configure(train: Node3D, bounds: AABB, camera: Camera3D) -> void:
    _train = train
    _train_bounds = bounds
    _camera = camera
    sync_to_view()

func _process(_delta: float) -> void:
    sync_to_view()

func _include_slots(required: Dictionary, z0: float, z1: float) -> void:
    var first := int(floor((z0 - VISIBLE_DISTANCE - GUARD_DISTANCE) / MODULE_LENGTH))
    var last := int(floor((z1 + VISIBLE_DISTANCE + GUARD_DISTANCE) / MODULE_LENGTH))
    for slot in range(first,last+1):
        required[slot] = true

func sync_to_view() -> void:
    if not is_instance_valid(_train) or not is_instance_valid(_camera):
        return
    var required: Dictionary = {}
    _include_slots(required,_train.global_position.z+_train_bounds.position.z,_train.global_position.z+_train_bounds.end.z)
    _include_slots(required,_camera.global_position.z,_camera.global_position.z)
    # Retire only slots outside BOTH protected volumes. Every retired slot is
    # at least 72 m from the camera: beyond the 56 m fully dark fog boundary.
    for slot in _active.keys():
        if not required.has(slot):
            var spare: Node3D = _active[slot]
            spare.hide()
            _spares.append(spare)
            _active.erase(slot)
    for slot in required:
        if _active.has(slot):
            continue
        var section: Node3D
        if _spares.is_empty():
            section = _new_section()
        else:
            section = _spares.pop_back()
            recycle_count += 1
        section.position = Vector3(center_x,0,float(slot)*MODULE_LENGTH)
        section.set_meta("slot",slot)
        section.get_node("WallLight").visible = posmod(int(slot),2) == 0
        section.show()
        _active[slot] = section

func _new_section() -> Node3D:
    var section := Node3D.new()
    section.name = "ReusableTunnel16m_%d" % _sections.size()
    add_child(section)
    _sections.append(section)
    _mesh(section,"ConcreteArch",_shell,_concrete,Vector3.ZERO)
    _mesh(section,"TrackFoundation",_floor,_concrete,Vector3(0,-0.38,8))
    for side in [-0.9,0.9]:
        _mesh(section,"Rail",_rail,_steel,Vector3(side,-0.08,8))
    var ties := MultiMeshInstance3D.new()
    ties.name = "Sleepers"
    ties.multimesh = _sleepers
    ties.material_override = _wood
    section.add_child(ties)
    _mesh(section,"ConcreteJoints",_joints,_seam,Vector3.ZERO)
    _mesh(section,"WallFixture",_lamp,_glow,Vector3(-3.0,3.4,8))
    var light := OmniLight3D.new()
    light.name = "WallLight"
    light.position = Vector3(-2.8,3.4,8)
    light.light_color = Color(0.88,0.86,0.74)
    light.light_energy = 0.65
    light.omni_range = 15.0
    light.shadow_enabled = false
    section.add_child(light)
    return section

func _mesh(parent: Node3D, label: String, mesh: Mesh, material: Material, at: Vector3) -> void:
    var instance := MeshInstance3D.new()
    instance.name = label
    instance.mesh = mesh
    instance.material_override = material
    instance.position = at
    parent.add_child(instance)

func _material(color: Color, roughness_value: float) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = roughness_value
    material.cull_mode = BaseMaterial3D.CULL_DISABLED
    return material

func coverage_is_valid() -> bool:
    if not is_instance_valid(_train) or not is_instance_valid(_camera):
        return false
    var required: Dictionary = {}
    _include_slots(required,_train.global_position.z+_train_bounds.position.z,_train.global_position.z+_train_bounds.end.z)
    _include_slots(required,_camera.global_position.z,_camera.global_position.z)
    for slot in required:
        if not _active.has(slot):
            return false
        var section: Node3D = _active[slot]
        if not section.visible or absf(section.position.z-float(slot)*MODULE_LENGTH) > 0.001:
            return false
    return true

func active_module_count() -> int:
    return _active.size()

func constrain_camera(world_position: Vector3) -> Vector3:
    var p := to_local(world_position)
    p.y = clampf(p.y,0.15,6.6)
    var width := 3.15
    for j in range(PROFILE.size()/2):
        var a: Vector2 = PROFILE[j]
        var b: Vector2 = PROFILE[j+1]
        if p.y >= a.y and p.y <= b.y:
            width = absf(lerpf(a.x,b.x,(p.y-a.y)/maxf(0.001,b.y-a.y)))
            break
    p.x = clampf(p.x-center_x,-width+0.15,width-0.15)+center_x
    return to_global(p)
