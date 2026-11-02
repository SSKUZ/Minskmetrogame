extends Node3D
## Tunnel V2: native Godot mobile geometry, browser 'testing' as visual reference.
## Existing StationBaseStatic rails and sleepers are authoritative; no duplicates.
const SECTIONS := [Vector2(110.0, 310.0), Vector2(-220.0, -70.0)]
const TRACK_PATH = preload("res://scripts/playable_track_path.gd")
const ROUTE_GRAPH_SCRIPT = preload("res://scripts/tunnel_route_graph.gd")
var route_graph: RefCounted
const PROFILE := [
    Vector2(-3.15, 0.05), Vector2(-3.15, 3.3), Vector2(-2.94, 4.8),
    Vector2(-2.25, 6.15), Vector2(-1.25, 6.85), Vector2(0.0, 7.05),
    Vector2(1.25, 6.85), Vector2(2.25, 6.15), Vector2(2.94, 4.8),
    Vector2(3.15, 3.3), Vector2(3.15, 0.05)
]
const RIB_STEP := 8.0
const LIGHT_STEP := 12.0
const LINING_STEP := 2.0
const MODULE_LENGTH := 16.0
const VISIBLE_DISTANCE := 120.0
# Depot (z=329.6) -> Malinovka (z=9.6), travel along negative Z.
# Decorative junction at z=232, curved side bore turns 22 degrees right.
const CURVE_START_Z := 210.0
const CURVE_END_Z := 146.0
const CURVE_OFFSET := 0.65
const BRANCH_Z := 232.0
const BRANCH_SIDE := 1
const BRANCH_LENGTH := 48.0
const BRANCH_TURN := deg_to_rad(22.0)
var _modules: Array[Node3D] = []
var _follow_train: Node3D

func _ready() -> void:
    var concrete := _concrete_material()
    var seam := _mat(Color("#393a38"))
    var grime := _mat(Color("#4c4944"))
    var ribs := _mat(Color("#5a5854"))
    var cable_colors := [_mat(Color("#10161b")), _mat(Color("#253d49")), _mat(Color("#302a28"))]
    var fixture := _mat(Color("#737779"))
    var hazard := _mat(Color("#d7b43a"))
    var signal_body := _mat(Color("#101619"))
    var glow := _mat(Color("#e5f5ff"), true)
    var red := _mat(Color("#ff2828"), true)
    var green := _mat(Color("#26ff73"), true)
    route_graph = ROUTE_GRAPH_SCRIPT.new()
    # Existing geometry stays straight; future authored curves/junctions use route_graph.sample().
    for i in range(SECTIONS.size()):
        var section: Vector2 = SECTIONS[i]
        route_graph.add_straight("main_%d" % i, Vector3(0, 0, section.y), 0.0, section.y - section.x)
    route_graph.add_visual_branch("depot_side_bore", Vector3(3.15, 0, BRANCH_Z), 0.0,
        BRANCH_LENGTH, BRANCH_SIDE, BRANCH_TURN)
    _follow_train = get_parent().get_node_or_null("PlayerTrainPlacement") as Node3D
    for section in SECTIONS:
        var module_start: float = section.x
        while module_start < section.y - 0.001:
            var module_end: float = minf(module_start + MODULE_LENGTH, section.y)
            # Reference shell on complete 16 m spans; keep legacy junction and end caps.
            var full_span: bool = absf(module_end - module_start - MODULE_LENGTH) < 0.001
            var at_junction: bool = module_start < BRANCH_Z + 8.0 and module_end > BRANCH_Z - 8.0
            if full_span and not at_junction:
                var reference := Node3D.new()
                reference.set_script(load("res://scripts/tunnel_reference_module.gd"))
                reference.name = "ReferenceTunnel_%d" % int(module_start)
                reference.set("route_start_z", module_start)
                reference.set("include_track", false)
                reference.set("include_service_cabinet", posmod(int(floor(module_start / MODULE_LENGTH)), 4) == 0)
                reference.set("illumination", _module_illumination(module_start))
                reference.position.z = module_start
                add_child(reference)
                _modules.append(reference)
            else:
                _build_module(module_start, module_end, concrete, seam, grime, ribs, cable_colors, fixture, hazard, signal_body, glow, red, green)
            module_start = module_end
    _build_side_branch(concrete, seam, ribs)
    _build_branch_tracks()
    _build_switch_connection()
    # StationBaseStatic now builds the authoritative curved track; no duplicate overlay.

func _module_illumination(z: float) -> float:
    # Deterministic variety without additional unique tunnel meshes.
    var index := int(floor(z / MODULE_LENGTH))
    if posmod(index, 7) == 0:
        return 0.45
    if posmod(index, 5) == 0:
        return 1.3
    return 0.9

func _process(_delta: float) -> void:
    if _follow_train == null:
        return
    var train_z := _follow_train.global_position.z
    var branch := get_node_or_null("DepotSideBranch_Curved_VisualOnly")
    if branch != null:
        branch.visible = absf(BRANCH_Z - train_z) < VISIBLE_DISTANCE + BRANCH_LENGTH
    var switch_track := get_node_or_null("DepotSwitchConnection_VisualOnly")
    if switch_track != null:
        switch_track.visible = absf(BRANCH_Z - train_z) < VISIBLE_DISTANCE + 24.0
    var branch_track := get_node_or_null("DepotBranchTrack_VisualOnly")
    if branch_track != null:
        branch_track.visible = absf(BRANCH_Z - train_z) < VISIBLE_DISTANCE + BRANCH_LENGTH
    for module in _modules:
        module.visible = absf(module.position.z - train_z) < VISIBLE_DISTANCE + MODULE_LENGTH

func _build_module(z0: float, z1: float, concrete: Material, seam: Material,
        grime: Material, ribs: Material, cable_colors: Array, fixture: Material,
        hazard: Material, signal_body: Material, glow: Material, red: Material,
        green: Material) -> void:
        var root := Node3D.new()
        root.name = "TunnelModule_%d_%d" % [int(z0), int(z1)]
        root.position.z = (z0 + z1) * 0.5
        # Geometry uses absolute Z; compensate by placing a neutral local container.
        var geometry := Node3D.new()
        geometry.position.z = -root.position.z
        root.add_child(geometry)
        _modules.append(root)
        add_child(root)
        root = geometry
        if z1 <= CURVE_END_Z or z0 >= CURVE_START_Z:
            _shell(root, z0, z1, concrete)
        else:
            _curved_shell(root, z0, z1, concrete)
        _ribs(root, z0, z1, ribs)
        _lining_joints(root, z0, z1, seam)
        _grime_strips(root, z0, z1, grime)
        _cables(root, z0, z1, cable_colors)
        _repeat_boxes(root, "WallLights", Vector3(0.11, 0.62, 0.25), glow,
            Vector3(-3.02, 3.3, z0 + 8.0), Vector3(0, 0, LIGHT_STEP),
            maxi(0, int((z1 - z0 - 8.0) / LIGHT_STEP) + 1))
        for side in [-1, 1]:
            _repeat_boxes(root, "CableBrackets", Vector3(0.15, 0.08, 0.25), ribs,
                Vector3(side * 3.04, 1.55, z0 + 3.0), Vector3(0, 0, 7.0),
                maxi(0, int((z1 - z0 - 3.0) / 7.0) + 1))
            _repeat_boxes(root, "UpperBrackets", Vector3(0.15, 0.08, 0.25), ribs,
                Vector3(side * 3.04, 2.58, z0 + 3.0), Vector3(0, 0, 7.0),
                maxi(0, int((z1 - z0 - 3.0) / 7.0) + 1))
            var z := ceilf((z0 - 24.0) / 48.0) * 48.0 + 24.0
            while z < z1:
                _box(root, "ServiceCabinet", Vector3(0.22, 0.82, 0.86),
                    Vector3(side * 2.97, 2.35, z), fixture)
                _box(root, "CabinetDoor", Vector3(0.235, 0.68, 0.69),
                    Vector3(side * 2.82, 2.35, z), ribs)
                _box(root, "HazardPlate", Vector3(0.245, 0.22, 0.23),
                    Vector3(side * 2.81, 2.43, z), hazard)
                z += 48.0
        var signal_z := ceilf((z0 - 64.0) / 128.0) * 128.0 + 64.0
        while signal_z < z1 - 1.0:
            _signal(root, signal_z, signal_body, ribs, red, green, int(signal_z) % 2 == 0)
            signal_z += 128.0

func _build_side_branch(concrete: Material, seam: Material, ribs: Material) -> void:
    # One visibly curved, non-drivable side bore. Does not change player track.
    var parent := Node3D.new()
    parent.name = "DepotSideBranch_Curved_VisualOnly"
    add_child(parent)
    # Culling is based on the junction coordinate, not the origin of this node.
    # Build an open-sided connection mouth, then a curved tube from 8m to 48m.
    var shell := SurfaceTool.new()
    shell.begin(Mesh.PRIMITIVE_TRIANGLES)
    var joint := SurfaceTool.new()
    joint.begin(Mesh.PRIMITIVE_TRIANGLES)
    var steps := 24
    for j in range(steps):
        var d0 := BRANCH_LENGTH * float(j) / float(steps)
        var d1 := BRANCH_LENGTH * float(j + 1) / float(steps)
        var t0 := BRANCH_TURN * d0 / BRANCH_LENGTH
        var t1 := BRANCH_TURN * d1 / BRANCH_LENGTH
        var p0 := _branch_center(d0)
        var p1 := _branch_center(d1)
        for i in range(PROFILE.size() - 1):
            var a: Vector2 = PROFILE[i]
            var b: Vector2 = PROFILE[i + 1]
            # Reduced bore size, positioned off the live running line.
            var aa := Vector3(a.x * 0.78, a.y * 0.85, 0)
            var bb := Vector3(b.x * 0.78, b.y * 0.85, 0)
            var v0 := p0 + Basis(Vector3.UP, -t0) * aa
            var v1 := p0 + Basis(Vector3.UP, -t0) * bb
            var v2 := p1 + Basis(Vector3.UP, -t1) * bb
            var v3 := p1 + Basis(Vector3.UP, -t1) * aa
            for vertex in [v0, v1, v2, v0, v2, v3]:
                shell.add_vertex(vertex)
            if j % 4 == 0:
                # Thin arch joints at 8m intervals.
                var edge := (bb - aa).normalized() * 0.035
                var out := Basis(Vector3.UP, -t0) * edge
                var along := Basis(Vector3.UP, -t0) * Vector3(0, 0, -0.07)
                for vertex in [v0, v1, v1 + along, v0, v1 + along, v0 + along]:
                    joint.add_vertex(vertex + out)
    shell.generate_normals()
    joint.generate_normals()
    var arch := MeshInstance3D.new()
    arch.name = "CurvedBranchArch"
    arch.mesh = shell.commit()
    arch.material_override = concrete
    parent.add_child(arch)
    var seams := MeshInstance3D.new()
    seams.name = "BranchLiningJoints"
    seams.mesh = joint.commit()
    seams.material_override = seam
    parent.add_child(seams)
    # Dark end cap makes the side tunnel visibly recede into darkness.
    var cap := MeshInstance3D.new()
    cap.name = "BranchDarkEnd"
    var cap_mesh := SphereMesh.new()
    cap_mesh.radius = 2.3
    cap_mesh.height = 4.6
    cap.mesh = cap_mesh
    cap.material_override = _mat(Color("#090b0c"))
    cap.position = _branch_center(BRANCH_LENGTH)
    parent.add_child(cap)

func curve_offset(z: float) -> float:
    return TRACK_PATH.offset(z)

func _curved_shell(parent: Node3D, z0: float, z1: float, material: Material) -> void:
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var slices := maxi(4, int(ceilf((z1 - z0) / 2.0)))
    for j in range(slices):
        var za := lerpf(z0, z1, float(j) / slices)
        var zb := lerpf(z0, z1, float(j + 1) / slices)
        for i in range(PROFILE.size() - 1):
            var a: Vector2 = PROFILE[i]
            var b: Vector2 = PROFILE[i + 1]
            var x0 := curve_offset(za)
            var x1 := curve_offset(zb)
            var p0 := Vector3(a.x + x0, a.y, za)
            var p1 := Vector3(b.x + x0, b.y, za)
            var p2 := Vector3(b.x + x1, b.y, zb)
            var p3 := Vector3(a.x + x1, a.y, zb)
            for v in [p0, p1, p2, p0, p2, p3]:
                st.add_vertex(v)
    st.generate_normals()
    var mesh := MeshInstance3D.new()
    mesh.name = "GentlyCurvedArch"
    mesh.mesh = st.commit()
    mesh.material_override = material
    parent.add_child(mesh)

func _build_main_visual_curve(concrete: Material) -> void:
    # Native low-poly curved rail overlay. StationBaseStatic original rails
    # remain intact, so no station geometry or train physics is rewritten.
    var root := Node3D.new()
    root.name = "MainTrackGentleSCurve_Visual"
    add_child(root)
    var steel := _mat(Color("#a1a7aa"))
    steel.metallic = 0.7
    var ballast := _mat(Color("#33383c"))
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var slices := 64
    for j in range(slices):
        var za := lerpf(CURVE_END_Z, CURVE_START_Z, float(j) / slices)
        var zb := lerpf(CURVE_END_Z, CURVE_START_Z, float(j + 1) / slices)
        for side in [-1, 1]:
            var xa := curve_offset(za) + float(side) * 0.9
            var xb := curve_offset(zb) + float(side) * 0.9
            var w := 0.07
            for v in [
                Vector3(xa-w, 0.02, za), Vector3(xa+w, 0.02, za),
                Vector3(xb+w, 0.02, zb), Vector3(xa-w, 0.02, za),
                Vector3(xb+w, 0.02, zb), Vector3(xb-w, 0.02, zb)
            ]:
                st.add_vertex(v)
    st.generate_normals()
    var rail := MeshInstance3D.new()
    rail.name = "CurvedRailTops"
    rail.mesh = st.commit()
    rail.material_override = steel
    root.add_child(rail)
    # The narrow ballast ribbon masks the straight original track beneath.
    # It is deliberately low to avoid obscuring the new rail tops.
    var bed := SurfaceTool.new()
    bed.begin(Mesh.PRIMITIVE_TRIANGLES)
    for j in range(slices):
        var za := lerpf(CURVE_END_Z, CURVE_START_Z, float(j) / slices)
        var zb := lerpf(CURVE_END_Z, CURVE_START_Z, float(j + 1) / slices)
        var xa := curve_offset(za)
        var xb := curve_offset(zb)
        for v in [Vector3(xa-1.25,-0.13,za),Vector3(xa+1.25,-0.13,za),
                Vector3(xb+1.25,-0.13,zb),Vector3(xa-1.25,-0.13,za),
                Vector3(xb+1.25,-0.13,zb),Vector3(xb-1.25,-0.13,zb)]:
            bed.add_vertex(v)
    bed.generate_normals()
    var bed_node := MeshInstance3D.new()
    bed_node.name = "CurvedBallast"
    bed_node.mesh = bed.commit()
    bed_node.material_override = ballast
    root.add_child(bed_node)

func _build_switch_connection() -> void:
    # Visual-only turnout: tapered rails join the live straight rail without
    # changing its collision, train trajectory, or station stop position.
    var root := Node3D.new()
    root.name = "DepotSwitchConnection_VisualOnly"
    add_child(root)
    var steel := _mat(Color("#92999a"))
    steel.metallic = 0.75
    var sleeper := _mat(Color("#4c4741"))
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    # Branch centre drifts smoothly from the main track to the side bore.
    # At z=BRANCH_Z+20 the turnout begins on the running line;
    # at z=BRANCH_Z it reaches the decorative bore mouth.
    var steps := 24
    for rail_side in [-1, 1]:
        for i in range(steps):
            var u0 := float(i) / float(steps)
            var u1 := float(i + 1) / float(steps)
            var x0 := 3.15 * (u0 * u0 * (3.0 - 2.0 * u0))
            var x1 := 3.15 * (u1 * u1 * (3.0 - 2.0 * u1))
            var z0 := BRANCH_Z + 20.0 * (1.0 - u0)
            var z1 := BRANCH_Z + 20.0 * (1.0 - u1)
            # The first rail lies on the original right-hand rail.
            # The second rail converges from the left side of the running track.
            var side_offset := float(rail_side) * 0.9
            var a := Vector3(x0 + side_offset, -0.01, z0)
            var b := Vector3(x1 + side_offset, -0.01, z1)
            var width := 0.055
            for p in [a + Vector3(-width, 0, 0), a + Vector3(width, 0, 0),
                    b + Vector3(width, 0, 0), a + Vector3(-width, 0, 0),
                    b + Vector3(width, 0, 0), b + Vector3(-width, 0, 0)]:
                st.add_vertex(p)
    st.generate_normals()
    var rails := MeshInstance3D.new()
    rails.name = "TaperedTurnoutRails"
    rails.mesh = st.commit()
    rails.material_override = steel
    root.add_child(rails)
    # Light sleeper ties emphasize the junction without duplicating main track.
    for i in range(8):
        var u := (float(i) + 0.5) / 8.0
        var x := 3.15 * u * u * (3.0 - 2.0 * u)
        var z := BRANCH_Z + 20.0 * (1.0 - u)
        _box(root, "TurnoutSleeper", Vector3(2.2, 0.07, 0.18),
            Vector3(x, -0.22, z), sleeper)

func _build_branch_tracks() -> void:
    # Dedicated decorative track: never touches the existing main line rails.
    var root := Node3D.new()
    root.name = "DepotBranchTrack_VisualOnly"
    add_child(root)
    var rail_mat := _mat(Color("#747a7e"))
    rail_mat.metallic = 0.65
    var sleeper_mat := _mat(Color("#4a4440"))
    var ballast_mat := _mat(Color("#393735"))
    var rail_mesh := BoxMesh.new()
    rail_mesh.size = Vector3(0.075, 0.14, 1.0)
    rail_mesh.material = rail_mat
    var ballast_mesh := BoxMesh.new()
    ballast_mesh.size = Vector3(2.55, 0.18, 1.0)
    ballast_mesh.material = ballast_mat
    var sleepers_mesh := BoxMesh.new()
    sleepers_mesh.size = Vector3(2.35, 0.14, 0.24)
    sleepers_mesh.material = sleeper_mat
    var segment_count := 48
    var mm_rails := MultiMesh.new()
    mm_rails.transform_format = MultiMesh.TRANSFORM_3D
    mm_rails.mesh = rail_mesh
    mm_rails.instance_count = segment_count * 2
    var mm_ballast := MultiMesh.new()
    mm_ballast.transform_format = MultiMesh.TRANSFORM_3D
    mm_ballast.mesh = ballast_mesh
    mm_ballast.instance_count = segment_count
    var mm_sleepers := MultiMesh.new()
    mm_sleepers.transform_format = MultiMesh.TRANSFORM_3D
    mm_sleepers.mesh = sleepers_mesh
    mm_sleepers.instance_count = segment_count
    for i in range(segment_count):
        var d := (float(i) + 0.5) * BRANCH_LENGTH / float(segment_count)
        var angle := BRANCH_TURN * d / BRANCH_LENGTH
        var basis := Basis(Vector3.UP, -angle)
        var center := _branch_center(d)
        for side in [-1, 1]:
            var rail_position := center + basis * Vector3(side * 0.76, 0.23, 0)
            mm_rails.set_instance_transform(i * 2 + (0 if side == -1 else 1),
                Transform3D(basis, rail_position))
        mm_ballast.set_instance_transform(i, Transform3D(basis,
            center + Vector3(0, 0.01, 0)))
        mm_sleepers.set_instance_transform(i, Transform3D(basis,
            center + Vector3(0, 0.14, 0)))
    for entry in [["BranchRails", mm_rails], ["BranchBallast", mm_ballast],
            ["BranchSleepers", mm_sleepers]]:
        var instance := MultiMeshInstance3D.new()
        instance.name = entry[0]
        instance.multimesh = entry[1]
        root.add_child(instance)

func _branch_center(distance: float) -> Vector3:
    var turn := BRANCH_TURN * distance / BRANCH_LENGTH
    var radius := BRANCH_LENGTH / BRANCH_TURN
    # Rightward deviation along negative Z; starts beside the right-hand wall.
    return Vector3(3.15 + radius * (1.0 - cos(turn)),
        0.0, BRANCH_Z - radius * sin(turn))

func _concrete_material() -> ShaderMaterial:
    # World-position noise: no bitmap texture download, seamless between modules.
    var shader := Shader.new()
    shader.code = """shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_disabled;
varying vec3 world_pos;
void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
float hash21(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
void fragment() {
    vec2 cell = floor(vec2(world_pos.z * 3.0, world_pos.y * 3.0));
    float grain = hash21(cell);
    float broad = hash21(floor(vec2(world_pos.z, world_pos.y) * 0.35));
    float stains = smoothstep(0.60, 0.93, broad) * 0.18;
    float base = 0.43 + grain * 0.095 - stains;
    ALBEDO = vec3(base * 1.04, base * 1.01, base * 0.95);
    ROUGHNESS = 0.96;
}
"""
    var material := ShaderMaterial.new()
    material.shader = shader
    return material

func _lining_joints(parent: Node3D, z0: float, z1: float, material: Material) -> void:
    var mesh := BoxMesh.new()
    mesh.size = Vector3(0.035, 1.0, 0.035)
    mesh.material = material
    var count := maxi(0, int((z1 - z0) / LINING_STEP))
    var mm := MultiMesh.new()
    mm.transform_format = MultiMesh.TRANSFORM_3D
    mm.mesh = mesh
    mm.instance_count = count * (PROFILE.size() - 1)
    var index := 0
    for j in range(count):
        var z := z0 + (j + 1) * LINING_STEP
        for k in range(PROFILE.size() - 1):
            var a: Vector2 = PROFILE[k]
            var b: Vector2 = PROFILE[k + 1]
            var angle := -atan2(b.x - a.x, b.y - a.y)
            var basis := Basis(Vector3.BACK, angle).scaled(Vector3(1, a.distance_to(b), 1))
            mm.set_instance_transform(index, Transform3D(basis,
                Vector3((a.x + b.x) * 0.5, (a.y + b.y) * 0.5, z)))
            index += 1
    var inst := MultiMeshInstance3D.new()
    inst.name = "LiningSegmentJoints"
    inst.multimesh = mm
    parent.add_child(inst)

func _grime_strips(parent: Node3D, z0: float, z1: float, material: Material) -> void:
    for side in [-1, 1]:
        _box(parent, "LowerWallGrime", Vector3(0.025, 0.52, z1 - z0),
            Vector3(side * 3.14, 0.45, (z0 + z1) * 0.5), material)

func _shell(parent: Node3D, z0: float, z1: float, material: Material) -> void:
    # One combined arch surface per section, except an accurately bounded junction opening.
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    for i in range(PROFILE.size() - 1):
        var a: Vector2 = PROFILE[i]
        var b: Vector2 = PROFILE[i + 1]
        var spans: Array[Vector2] = [Vector2(z0, z1)]
        if i == PROFILE.size() - 2 and z0 < BRANCH_Z + 8.0 and z1 > BRANCH_Z - 8.0:
            spans.clear()
            if z0 < BRANCH_Z - 8.0:
                spans.append(Vector2(z0, BRANCH_Z - 8.0))
            if z1 > BRANCH_Z + 8.0:
                spans.append(Vector2(BRANCH_Z + 8.0, z1))
        for span in spans:
            var p0 := Vector3(a.x, a.y, span.x)
            var p1 := Vector3(b.x, b.y, span.x)
            var p2 := Vector3(b.x, b.y, span.y)
            var p3 := Vector3(a.x, a.y, span.y)
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
                    var xa: float = side * (3.12 - offset * 0.32 + 0.025 * sin(za * 0.375 + offset * 12.0))
                    var xb: float = side * (3.12 - offset * 0.32 + 0.025 * sin(zb * 0.375 + offset * 12.0))
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
