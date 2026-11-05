extends Node3D
## Straight 16 m modules. Slots cover the complete consist and the camera separately.
const MODULE_LENGTH := 16.0
const VISIBLE_DISTANCE := 120.0
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
var _concrete: ShaderMaterial
var _steel: StandardMaterial3D
var _wood: StandardMaterial3D
var _seam: StandardMaterial3D
var _glow: StandardMaterial3D
var _cable_meshes: Array[ArrayMesh] = []
var _cable_materials: Array[StandardMaterial3D] = []
var _brackets: ArrayMesh
var _bolts: MultiMesh
var _equipment_meshes: Array[ArrayMesh] = []
var _equipment_materials: Array[StandardMaterial3D] = []
var _damp_strip: BoxMesh
var _grime: StandardMaterial3D
var recycle_count := 0

func _ready() -> void:
    _concrete = _concrete_material()
    _steel = _material(Color(0.34, 0.37, 0.39), 0.52)
    _steel.metallic = 0.65
    _wood = _material(Color(0.13, 0.105, 0.08), 1.0)
    _seam = _material(Color(0.13, 0.135, 0.125), 1.0)
    _grime = _material(Color(0.12, 0.135, 0.12), 0.96)
    _glow = _material(Color(0.72, 0.70, 0.60), 0.8)
    _glow.emission_enabled = true
    _glow.emission = Color(0.72, 0.70, 0.60)
    _glow.emission_energy_multiplier = 1.5
    var visual_profile: Array[Vector2] = []
    for step in range((PROFILE.size()-1)*4+1):
        visual_profile.append(_smooth_profile(float(step)/4.0))
    var shell := SurfaceTool.new()
    shell.begin(Mesh.PRIMITIVE_TRIANGLES)
    shell.set_smooth_group(0)
    for j in range(visual_profile.size() - 1):
        var a: Vector2 = visual_profile[j]
        var b: Vector2 = visual_profile[j + 1]
        for v in [Vector3(a.x,a.y,0), Vector3(a.x,a.y,16), Vector3(b.x,b.y,0),
                Vector3(b.x,b.y,0), Vector3(a.x,a.y,16), Vector3(b.x,b.y,16)]:
            shell.add_vertex(v)
    shell.index()
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
    edge.size = Vector3(0.018, 1.0, 0.024)
    for z in range(0,16,2):
        for j in range(visual_profile.size()-1):
            var a: Vector2 = visual_profile[j]
            var b: Vector2 = visual_profile[j+1]
            a += (Vector2(0,3.3)-a).normalized()*0.02
            b += (Vector2(0,3.3)-b).normalized()*0.02
            var basis := Basis(Vector3.BACK,-atan2(b.x-a.x,b.y-a.y)).scaled(Vector3(1,a.distance_to(b),1))
            joints.append_from(edge,0,Transform3D(basis,Vector3((a.x+b.x)*0.5,(a.y+b.y)*0.5,float(z))))
    _joints = joints.commit()
    _lamp = BoxMesh.new()
    _lamp.size = Vector3(0.08,0.16,0.8)
    _damp_strip = BoxMesh.new()
    _damp_strip.size = Vector3(0.022,0.45,MODULE_LENGTH)
    _prepare_service_details(visual_profile)

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
    # at least 136 m from the camera: beyond the 120 m fully dark fog boundary.
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
        section.get_node("ServiceCabinet").visible = posmod(int(slot),4) == 1
        section.get_node("JunctionBox").visible = posmod(int(slot),3) == 0
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
    light.light_energy = 0.85
    light.omni_range = 23.0
    light.omni_attenuation = 1.3
    light.shadow_enabled = false
    section.add_child(light)
    for i in range(_cable_meshes.size()):
        _mesh(section,"ContinuousCableBundle%d" % i,_cable_meshes[i],_cable_materials[i],Vector3.ZERO)
    _mesh(section,"CableSupportBrackets",_brackets,_steel,Vector3.ZERO)
    var bolts := MultiMeshInstance3D.new()
    bolts.name = "LiningFasteners"
    bolts.multimesh = _bolts
    bolts.material_override = _steel
    section.add_child(bolts)
    for side in [-1.0,1.0]:
        _mesh(section,"DampLowerWall",_damp_strip,_grime,Vector3(side*3.12,0.35,8))
    for i in range(2):
        var equipment := Node3D.new()
        equipment.name = "ServiceCabinet" if i == 0 else "JunctionBox"
        equipment.position = Vector3(-2.96 if i == 0 else 2.98,2.0 if i == 0 else 2.55,9.0 if i == 0 else 5.0)
        section.add_child(equipment)
        for part in range(3):
            var detail := _mesh(equipment,"EquipmentPart%d" % part,_equipment_meshes[part],_equipment_materials[part],Vector3.ZERO)
            if i == 1:
                detail.scale = Vector3(0.8,0.48,0.6)
                detail.rotation.y = PI
    return section

func _mesh(parent: Node3D, label: String, mesh: Mesh, material: Material, at: Vector3) -> MeshInstance3D:
    var instance := MeshInstance3D.new()
    instance.name = label
    instance.mesh = mesh
    instance.material_override = material
    instance.position = at
    parent.add_child(instance)
    instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    return instance

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

# Same Catmull-Rom profile interpolation as the existing reference module.
func _smooth_profile(t: float) -> Vector2:
    var i := mini(int(floor(t)),PROFILE.size()-2)
    var f := clampf(t-float(i),0.0,1.0)
    var a: Vector2 = PROFILE[maxi(i-1,0)]
    var b: Vector2 = PROFILE[i]
    var c: Vector2 = PROFILE[i+1]
    var d: Vector2 = PROFILE[mini(i+2,PROFILE.size()-1)]
    return 0.5*((2.0*b)+(-a+c)*f+(2.0*a-5.0*b+4.0*c-d)*f*f+(-a+3.0*b-3.0*c+d)*f*f*f)


func _concrete_material() -> ShaderMaterial:
    # Adapted from tunnel_v2.gd: world coordinates keep grain/stains continuous
    # across 16 m module boundaries and stable when pooled sections move.
    var shader := Shader.new()
    shader.code = """shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_disabled;
varying vec3 world_pos;
void vertex() { world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
float hash21(vec2 p) {
    return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);
}
float noise21(vec2 p) {
    vec2 i=floor(p); vec2 f=fract(p); f=f*f*(3.0-2.0*f);
    return mix(mix(hash21(i),hash21(i+vec2(1,0)),f.x),
               mix(hash21(i+vec2(0,1)),hash21(i+vec2(1,1)),f.x),f.y);
}
void fragment() {
    float arch=atan(world_pos.x-0.992,world_pos.y-3.3)*3.3;
    vec2 uv=vec2(world_pos.z,arch);
    float grain=hash21(floor(uv*95.0));
    float weather=noise21(uv*1.7);
    float blocks=hash21(floor(uv/vec2(2.0,1.7)));
    float streak=noise21(vec2(world_pos.z*3.5,world_pos.y*0.13));
    float moisture=smoothstep(0.63,0.86,streak)*0.17;
    float lower=1.0-smoothstep(0.15,1.4,world_pos.y);
    float longitudinal=1.0-smoothstep(0.015,0.035,abs(fract(arch/1.7+0.5)-0.5));
    float base=0.34+blocks*0.08+(weather-0.5)*0.08+(grain-0.5)*0.045;
    base-=moisture+lower*0.08+longitudinal*0.07;
    ALBEDO=vec3(base*1.04,base*1.01,base*0.92);
    ROUGHNESS=0.96-moisture*0.4;
}
"""
    var material := ShaderMaterial.new()
    material.shader = shader
    return material

func _append_box(st: SurfaceTool, size: Vector3, at: Vector3) -> void:
    var box := BoxMesh.new()
    box.size = size
    st.append_from(box,0,Transform3D(Basis(),at))

func _prepare_service_details(profile: Array[Vector2]) -> void:
    # Existing legacy cable/bracket/cabinet layout, baked into shared meshes.
    # Sags repeat every 4 m and finish at the same height at both module ends.
    for group in range(2):
        var st := SurfaceTool.new()
        st.begin(Mesh.PRIMITIVE_TRIANGLES)
        for side in [-1.0,1.0]:
            for line in range(group,6,2):
                var radius := 0.022+float(line%3)*0.009
                for span in range(16):
                    var za := float(span)
                    var zb := za+1.0
                    var ya := 1.1+float(line)*0.30-0.025*(1.0-cos(za*TAU/4.0))
                    var yb := 1.1+float(line)*0.30-0.025*(1.0-cos(zb*TAU/4.0))
                    for edge in range(6):
                        var a := float(edge)*TAU/6.0
                        var b := float(edge+1)*TAU/6.0
                        var p0 := Vector3(side*3.005+cos(a)*radius,ya+sin(a)*radius,za)
                        var p1 := Vector3(side*3.005+cos(b)*radius,ya+sin(b)*radius,za)
                        var p2 := Vector3(side*3.005+cos(b)*radius,yb+sin(b)*radius,zb)
                        var p3 := Vector3(side*3.005+cos(a)*radius,yb+sin(a)*radius,zb)
                        for point in [p0,p1,p2,p0,p2,p3]:
                            st.add_vertex(point)
        st.generate_normals()
        _cable_meshes.append(st.commit())
        _cable_materials.append(_material(Color("#191c1d") if group == 0 else Color("#36312c"),0.82))
    var supports := SurfaceTool.new()
    supports.begin(Mesh.PRIMITIVE_TRIANGLES)
    for side in [-1.0,1.0]:
        for z in [0.5,4.5,8.5,12.5]:
            _append_box(supports,Vector3(0.045,1.86,0.055),Vector3(side*3.08,1.83,z))
            for y in [1.08,1.68,2.28,2.58]:
                _append_box(supports,Vector3(0.20,0.045,0.07),Vector3(side*3.025,y,z))
            _append_box(supports,Vector3(0.11,0.18,0.15),Vector3(side*3.06,3.4,z))
    _brackets = supports.commit()
    var bolt := SphereMesh.new()
    bolt.radius = 0.04
    bolt.height = 0.08
    bolt.radial_segments = 6
    bolt.rings = 3
    _bolts = MultiMesh.new()
    _bolts.transform_format = MultiMesh.TRANSFORM_3D
    _bolts.mesh = bolt
    _bolts.instance_count = 8*8
    for ring in range(8):
        for index in range(8):
            var point: Vector2 = profile[4+index*4]
            point += (Vector2(0,3.3)-point).normalized()*0.035
            _bolts.set_instance_transform(ring*8+index,Transform3D(Basis(),Vector3(point.x,point.y,float(ring)*2.0+0.12)))
    for part in range(3):
        var st := SurfaceTool.new()
        st.begin(Mesh.PRIMITIVE_TRIANGLES)
        if part == 0:
            _append_box(st,Vector3(0.25,0.86,0.68),Vector3.ZERO)
            _append_box(st,Vector3(0.32,0.06,0.76),Vector3(0,0.46,0))
        elif part == 1:
            _append_box(st,Vector3(0.018,0.73,0.56),Vector3(0.135,0,0))
            _append_box(st,Vector3(0.04,0.14,0.03),Vector3(0.16,0,-0.18))
            for y in [-0.23,-0.18,-0.13]:
                _append_box(st,Vector3(0.023,0.012,0.24),Vector3(0.15,y,0.07))
        else:
            _append_box(st,Vector3(0.025,0.10,0.13),Vector3(0.15,0.23,0))
        _equipment_meshes.append(st.commit())
    _equipment_materials = [_material(Color("#535a58"),0.8),_material(Color("#2c3333"),0.72),_material(Color("#a38d49"),0.85)]
