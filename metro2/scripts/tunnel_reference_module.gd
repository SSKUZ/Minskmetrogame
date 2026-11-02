extends "res://scripts/tunnel_v2.gd"
## One authored 16 m module. Reuses Tunnel V2's profile and curved arch builder.
## Opt-in scene only: the playable route is not changed or replicated.
@export var route_start_z: float = 0.0
@export var include_track: bool = true
@export var include_service_cabinet: bool = true
@export_range(0.0, 2.0, 0.05) var illumination: float = 1.0:
    set(value):
        illumination = value
        for light in _wall_lights:
            light.light_energy = 2.5 * value
        if _lamp_material != null:
            _lamp_material.emission_energy_multiplier = 2.4 * value
var _wall_lights: Array[OmniLight3D] = []
var _lamp_material: StandardMaterial3D
static var _shared_box: BoxMesh
static var _shared_bolt: SphereMesh
static var _shared_materials: Dictionary = {}

# Smooth reference arch: Catmull-Rom interpolates the original profile vertices.
# The inherited polygonal profile is preserved for all legacy tunnel geometry.
func _curved_shell(parent: Node3D, z0: float, z1: float, material: Material) -> void:
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    st.set_smooth_group(0)
    var profile_steps := (PROFILE.size() - 1) * 4
    var length_steps := maxi(8, int(ceilf((z1 - z0) / 1.0)))
    for j in range(length_steps):
        var za := lerpf(z0, z1, float(j) / float(length_steps))
        var zb := lerpf(z0, z1, float(j + 1) / float(length_steps))
        for i in range(profile_steps):
            var a := _smooth_profile(float(i) / 4.0)
            var b := _smooth_profile(float(i + 1) / 4.0)
            var p0 := Vector3(a.x + curve_offset(za), a.y, za)
            var p1 := Vector3(b.x + curve_offset(za), b.y, za)
            var p2 := Vector3(b.x + curve_offset(zb), b.y, zb)
            var p3 := Vector3(a.x + curve_offset(zb), a.y, zb)
            for v in [p0, p1, p2, p0, p2, p3]:
                st.add_vertex(v)
    st.index()
    st.generate_normals()
    var shell := MeshInstance3D.new()
    shell.name = "SmoothReferenceArch"
    shell.mesh = st.commit()
    shell.material_override = material
    parent.add_child(shell)

func _smooth_profile(t: float) -> Vector2:
    var i := mini(int(floor(t)), PROFILE.size() - 2)
    var f := clampf(t - float(i), 0.0, 1.0)
    var a: Vector2 = PROFILE[maxi(i - 1, 0)]
    var b: Vector2 = PROFILE[i]
    var c: Vector2 = PROFILE[i + 1]
    var d: Vector2 = PROFILE[mini(i + 2, PROFILE.size() - 1)]
    return 0.5 * ((2.0 * b) + (-a + c) * f
        + (2.0 * a - 5.0 * b + 4.0 * c - d) * f * f
        + (-a + 3.0 * b - 3.0 * c + d) * f * f * f)

func curve_offset(z: float) -> float:
    return TRACK_PATH.offset(route_start_z + z)

func _ready() -> void:
    name = "TunnelReference16m"
    set_meta("length_m", MODULE_LENGTH)
    if _shared_box == null:
        _shared_box = BoxMesh.new()
        _shared_box.size = Vector3.ONE
        _shared_bolt = SphereMesh.new()
        _shared_bolt.radius = 0.022
        _shared_bolt.height = 0.044
        _shared_bolt.radial_segments = 6
        _shared_bolt.rings = 3
    if _shared_materials.is_empty():
        var concrete := ShaderMaterial.new()
        concrete.shader = preload("res://shaders/tunnel_reference_concrete.gdshader")
        _shared_materials = {"concrete": concrete,
            "metal": _mat(Color("#49483f")), "cable": _mat(Color("#272724")),
            "cabinet": _mat(Color("#8a8880")), "dark": _mat(Color("#252822")),
            "rust": _mat(Color("#574537")), "rail": _mat(Color("#878b87")),
            "sleepers": _mat(Color("#625e52"))}
        _shared_materials["rail"].metallic = 0.82
        _shared_materials["rail"].roughness = 0.24
        _shared_materials["cable"].roughness = 0.63
    _curved_shell(self, 0.0, MODULE_LENGTH, _shared_materials["concrete"])
    _ribs(self, 0.0, MODULE_LENGTH, _shared_materials["metal"])
    var rings: MultiMesh = get_node("ConcreteRibs").multimesh
    for i in range(rings.instance_count):
        var t := rings.get_instance_transform(i)
        t.origin.x += curve_offset(t.origin.z)
        t.basis = Basis(Vector3.UP, TRACK_PATH.heading(route_start_z+t.origin.z)) * t.basis
        rings.set_instance_transform(i,t)
    _reference_cables()
    if include_service_cabinet:
        _reference_panels()
    _reference_lamps()
    if include_track:
        _reference_track()

func _pose(p: Vector3, size: Vector3 = Vector3.ONE) -> Transform3D:
    var heading := TRACK_PATH.heading(route_start_z + p.z)
    p.x += curve_offset(p.z)
    return Transform3D(Basis(Vector3.UP, heading).scaled(size), p)

func _boxes(label: String, material: Material, transforms: Array[Transform3D]) -> void:
    if transforms.is_empty(): return
    var mm := MultiMesh.new()
    mm.transform_format = MultiMesh.TRANSFORM_3D
    mm.mesh = _shared_box
    mm.instance_count = transforms.size()
    for i in range(transforms.size()): mm.set_instance_transform(i, transforms[i])
    var node := MultiMeshInstance3D.new()
    node.name = label
    node.multimesh = mm
    node.material_override = material
    add_child(node)

func _reference_cables() -> void:
    # Round six-sided cable runs, replacing V2's flat ribbons in this module only.
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    for side in [-1, 1]:
        for level in range(9):
            var y := 1.10 + float(level) * 0.22
            var radius := 0.034 if level < 5 else 0.027
            for j in range(16):
                var za := float(j)
                var zb := float(j + 1)
                var ya := y - 0.014 * sin(PI * za / 2.0)
                var yb := y - 0.014 * sin(PI * zb / 2.0)
                for k in range(6):
                    var a := TAU * float(k) / 6.0
                    var b := TAU * float(k + 1) / 6.0
                    var points := [Vector3(side*2.99+cos(a)*radius,ya+sin(a)*radius,za),
                        Vector3(side*2.99+cos(b)*radius,ya+sin(b)*radius,za),
                        Vector3(side*2.99+cos(b)*radius,yb+sin(b)*radius,zb),
                        Vector3(side*2.99+cos(a)*radius,yb+sin(a)*radius,zb)]
                    for index in [0,1,2,0,2,3]:
                        var p: Vector3 = points[index]
                        p.x += curve_offset(p.z)
                        st.add_vertex(p)
    st.generate_normals()
    var cables := MeshInstance3D.new()
    cables.name = "RoundCableRuns"
    cables.mesh = st.commit()
    cables.material_override = _shared_materials["cable"]
    add_child(cables)
    var brackets: Array[Transform3D] = []
    var clamps: Array[Transform3D] = []
    for side in [-1,1]:
        for j in range(8):
            var z := 1.0 + float(j) * 2.0
            brackets.append(_pose(Vector3(side*3.08,2.02,z),Vector3(0.065,2.14,0.09)))
            for level in range(9):
                var y := 1.10 + float(level) * 0.22
                brackets.append(_pose(Vector3(side*3.035,y-0.06,z),Vector3(0.21,0.035,0.09)))
                clamps.append(_pose(Vector3(side*2.99,y,z),Vector3(0.085,0.083,0.032)))
    _boxes("CableRacks",_shared_materials["metal"],brackets)
    _boxes("CableClamps",_shared_materials["dark"],clamps)

func _reference_panels() -> void:
    var bolts := MultiMesh.new()
    bolts.transform_format = MultiMesh.TRANSFORM_3D
    bolts.mesh = _shared_bolt
    bolts.instance_count = 16 * (PROFILE.size()-2)
    var index := 0
    for j in range(16):
        var z := float(j) + 0.12
        for k in range(1,PROFILE.size()-1):
            var p: Vector2 = PROFILE[k]
            var inward := (Vector2(0,3.3)-p).normalized()*0.03
            bolts.set_instance_transform(index,_pose(Vector3(p.x+inward.x,p.y+inward.y,z)))
            index += 1
    var bolt_node := MultiMeshInstance3D.new()
    bolt_node.name = "LiningFasteners"
    bolt_node.multimesh = bolts
    bolt_node.material_override = _shared_materials["metal"]
    add_child(bolt_node)
    var cabinets: Array[Transform3D] = [_pose(Vector3(-2.88,1.10,6.9),Vector3(0.40,1.03,0.94))]
    _boxes("ExistingServiceCabinet",_shared_materials["cabinet"],cabinets)
    _boxes("CabinetDoorAndHinges",_shared_materials["metal"],[
        _pose(Vector3(-2.67,1.10,6.9),Vector3(0.023,0.96,0.87)),
        _pose(Vector3(-2.64,1.10,6.57),Vector3(0.035,0.11,0.025))])
    # A flat triangle and lightning glyph, drawn without external fonts/textures.
    var warning := SurfaceTool.new()
    warning.begin(Mesh.PRIMITIVE_TRIANGLES)
    for p in [Vector3(-2.648,1.37,6.9),Vector3(-2.648,1.06,6.72),Vector3(-2.648,1.06,7.08)]:
        p.x += curve_offset(p.z)
        warning.add_vertex(p)
    warning.generate_normals()
    var sign := MeshInstance3D.new()
    sign.name = "HighVoltageWarning"
    sign.mesh = warning.commit()
    sign.material_override = _mat(Color("#c9a02d"))
    add_child(sign)
    _boxes("WarningLightning",_shared_materials["dark"],[
        _pose(Vector3(-2.645,1.23,6.90),Vector3(0.006,0.10,0.022)),
        _pose(Vector3(-2.645,1.19,6.93),Vector3(0.006,0.025,0.075)),
        _pose(Vector3(-2.645,1.14,6.94),Vector3(0.006,0.09,0.022))])

func _reference_lamps() -> void:
    var housings: Array[Transform3D] = []
    var faces: Array[Transform3D] = []
    for z in [4.0,12.0]:
        housings.append(_pose(Vector3(-3.025,3.48,z),Vector3(0.18,0.24,1.04)))
        faces.append(_pose(Vector3(-2.925,3.48,z),Vector3(0.035,0.135,0.86)))
        var light := OmniLight3D.new()
        light.name = "WallFixtureLight"
        light.position = _pose(Vector3(-2.73,3.48,z)).origin
        light.light_color = Color("#eee8d8")
        light.light_energy = 2.5 * illumination
        light.omni_range = 8.5
        light.omni_attenuation = 1.0
        light.shadow_enabled = z == 12.0
        light.shadow_bias = 0.035
        light.distance_fade_enabled = true
        light.distance_fade_begin = 22.0
        light.distance_fade_length = 6.0
        _wall_lights.append(light)
        add_child(light)
    _boxes("RectangularLampHousings",_shared_materials["metal"],housings)
    _lamp_material = _mat(Color("#eeeae2"),true)
    _lamp_material.emission_energy_multiplier = 2.4 * illumination
    _boxes("RectangularLampDiffusers",_lamp_material,faces)

func _reference_track() -> void:
    # Standalone module preview only; disable include_track beside authoritative route rails.
    var bed := ShaderMaterial.new()
    bed.shader = preload("res://shaders/tunnel_reference_ballast.gdshader")
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    for j in range(16):
        var za := float(j)
        var zb := float(j+1)
        for p in [Vector3(-3.15,-0.28,za),Vector3(3.15,-0.28,za),Vector3(3.15,-0.28,zb),
                Vector3(-3.15,-0.28,za),Vector3(3.15,-0.28,zb),Vector3(-3.15,-0.28,zb)]:
            p.x += curve_offset(p.z)
            st.set_uv(Vector2(p.x,p.z))
            st.add_vertex(p)
    st.generate_normals()
    var ballast := MeshInstance3D.new()
    ballast.name = "BallastBed"
    ballast.mesh = st.commit()
    ballast.material_override = bed
    add_child(ballast)
    var sleepers: Array[Transform3D] = []
    var fasteners: Array[Transform3D] = []
    # 0.64 m pitch divides 16 m exactly: no doubled or missing boundary sleepers.
    for j in range(25):
        var z := 0.32 + float(j)*0.64
        sleepers.append(_pose(Vector3(0,-0.20,z),Vector3(2.55,0.12,0.23)))
        for x in [-0.9,0.9]:
            fasteners.append(_pose(Vector3(x,-0.12,z),Vector3(0.27,0.045,0.27)))
    _boxes("Sleepers",_shared_materials["sleepers"],sleepers)
    _boxes("RailFastenings",_shared_materials["rust"],fasteners)
    for entry in [["RailHeads",0.0,0.12,0.045,"rail"],["RailWebs",-0.065,0.045,0.09,"rust"],
            ["RailFeet",-0.105,0.18,0.035,"rust"]]:
        var rails := SurfaceTool.new()
        rails.begin(Mesh.PRIMITIVE_TRIANGLES)
        for side in [-1,1]:
            var x: float = side*0.9
            var y: float = entry[1]
            var w: float = entry[2]*0.5
            var h: float = entry[3]*0.5
            for j in range(16):
                var za := float(j)
                var zb := float(j+1)
                var ring := [Vector2(x-w,y-h),Vector2(x+w,y-h),Vector2(x+w,y+h),Vector2(x-w,y+h)]
                for k in range(4):
                    var a: Vector2 = ring[k]
                    var b: Vector2 = ring[(k+1)%4]
                    for p in [Vector3(a.x,a.y,za),Vector3(b.x,b.y,za),Vector3(b.x,b.y,zb),
                            Vector3(a.x,a.y,za),Vector3(b.x,b.y,zb),Vector3(a.x,a.y,zb)]:
                        p.x += curve_offset(p.z)
                        rails.add_vertex(p)
        rails.generate_normals()
        var rail := MeshInstance3D.new()
        rail.name = entry[0]
        rail.mesh = rails.commit()
        rail.material_override = _shared_materials[entry[4]]
        add_child(rail)
