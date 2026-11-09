extends Node3D
## Shared passenger ticker and ceiling CCTV mounts. No train control or physics.
var _game: Node3D
var _train: Node3D
var _cars: Dictionary = {}
var _view: SubViewport
var _ticker: Control
var _labels: Array[Label] = []
var _message := ""
var _span := 512.0
var _scroll := 0.0
var _tick := 0.0
var _material: StandardMaterial3D

func initialize(game: Node3D,train: Node3D) -> void:
    _game=game
    _train=train
    _view=SubViewport.new()
    _view.name="PassengerInformationTexture"
    _view.size=Vector2i(512,64)
    _view.disable_3d=true
    _view.render_target_update_mode=SubViewport.UPDATE_DISABLED
    add_child(_view)
    var backing := ColorRect.new()
    backing.color=Color("#020803")
    backing.size=Vector2(512,64)
    _view.add_child(backing)
    _ticker=Control.new()
    _ticker.size=Vector2(512,64)
    _ticker.clip_contents=true
    _view.add_child(_ticker)
    for i in range(2):
        var label := Label.new()
        label.add_theme_font_size_override("font_size",30)
        label.add_theme_color_override("font_color",Color("#58ed78"))
        label.add_theme_color_override("font_shadow_color",Color("#155e25"))
        label.add_theme_constant_override("shadow_offset_x",1)
        label.add_theme_constant_override("shadow_offset_y",1)
        label.position.y=10
        label.mouse_filter=Control.MOUSE_FILTER_IGNORE
        _ticker.add_child(label)
        _labels.append(label)
    _material=StandardMaterial3D.new()
    _material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
    _material.albedo_texture=_view.get_texture()
    _material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR
    _install_cars()

func _install_cars() -> void:
    for node in _train.get_children():
        if node is Node3D and str(node.name).begins_with("OriginalV106Car"):
            _install_car(node as Node3D)

func camera_mount(car: Node3D) -> Node3D:
    _install_car(car)
    return _cars[car].mount as Node3D

func _poster_bounds(car: Node3D,body: AABB) -> AABB:
    var chosen := AABB()
    var best := -INF
    for node in car.find_children("*","MeshInstance3D",true,false):
        var mesh := node as MeshInstance3D
        if mesh.mesh == null or not mesh.is_visible_in_tree(): continue
        var bounds: AABB=car.global_transform.affine_inverse()*mesh.global_transform*mesh.get_aabb()
        var center := bounds.get_center()
        # Only a textured transverse passenger poster, never side windows/doors.
        if bounds.size.x < 0.65 or bounds.size.x > 2.25 or bounds.size.y < 0.4 or bounds.size.y > 1.5: continue
        if bounds.size.z > 0.10 or center.y < 1.8 or center.y > 3.05: continue
        if absf(center.x-body.get_center().x) > 0.7: continue
        var textured := false
        var named := str(mesh.name).to_lower().contains("goodmix")
        for surface in range(mesh.mesh.get_surface_count()):
            var material := mesh.get_active_material(surface) as BaseMaterial3D
            if material != null and material.albedo_texture != null:
                textured=true
                var description := (material.resource_name+material.albedo_texture.resource_path).to_lower()
                named=named or description.contains("goodmix")
        if not textured: continue
        # Prefer the front passenger bulkhead; named original poster wins outright.
        var score := (100.0 if named else 0.0)+bounds.size.x*2.0-center.z*0.02
        if score > best:
            best=score
            chosen=bounds
    if best == -INF:
        # Original head cab ends at -7.4 m; other cars use their model-local bounds.
        var front := maxf(body.position.z+0.25,-7.25) if str(car.name) == "OriginalV106Car01" else body.position.z+0.28
        chosen=AABB(Vector3(body.get_center().x-0.62,2.0,front),Vector3(1.24,0.78,0.025))
    return chosen

func _install_car(car: Node3D) -> void:
    if _cars.has(car): return
    var body: AABB=_game.call("_get_model_bounds",car)
    var poster := _poster_bounds(car,body)
    var sign_z := 1.0 if poster.get_center().z < body.get_center().z else -1.0
    var center_x := body.get_center().x
    var panel_width := clampf(poster.size.x,0.95,1.85)
    var panel_y := minf(3.06,poster.end.y+0.125)
    var panel_pos := Vector3(poster.get_center().x,panel_y,poster.get_center().z+sign_z*0.055)
    var black := StandardMaterial3D.new()
    black.albedo_color=Color("#111815")
    black.roughness=0.75
    var casing := BoxMesh.new()
    casing.size=Vector3(panel_width+0.055,0.21,0.065)
    casing.material=black
    var board := MeshInstance3D.new()
    board.name="PassengerInformationCase"
    board.mesh=casing
    board.position=panel_pos
    board.layers=17
    car.add_child(board)
    var face := MeshInstance3D.new()
    face.name="GreenPassengerTicker"
    var quad := QuadMesh.new()
    quad.size=Vector2(panel_width,0.155)
    quad.material=_material
    face.mesh=quad
    face.position=panel_pos+Vector3(0,0,sign_z*0.034)
    face.rotation.y=0.0 if sign_z > 0.0 else PI
    face.layers=17
    face.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    car.add_child(face)
    var mount := Node3D.new()
    mount.name="SaloonCeilingCameraAnchor"
    # Right upper corner marked by the user, slightly inside the passenger volume.
    var right_x := minf(body.end.x-0.28,center_x+1.03)
    mount.position=Vector3(right_x,3.01,poster.get_center().z+sign_z*0.48)
    car.add_child(mount)
    var look := Vector3(center_x,1.95,poster.get_center().z+sign_z*8.0)
    mount.look_at(car.to_global(look),car.global_basis.y.normalized())
    var housing := Node3D.new()
    housing.name="SaloonCeilingDomeCamera"
    housing.position=mount.position+Vector3(0,0.10,0)
    car.add_child(housing)
    var white := StandardMaterial3D.new()
    white.albedo_color=Color("#d1d5cf")
    white.roughness=0.5
    var foot := CylinderMesh.new()
    foot.top_radius=0.105; foot.bottom_radius=0.105
    foot.height=0.025; foot.radial_segments=16; foot.material=white
    _mesh(housing,foot,Vector3(0,0.032,0))
    var dome := SphereMesh.new()
    dome.radius=0.085; dome.height=0.105
    dome.radial_segments=16; dome.rings=8; dome.material=black
    _mesh(housing,dome,Vector3(0,-0.022,0))
    var lens := SphereMesh.new()
    lens.radius=0.025; lens.height=0.05
    lens.radial_segments=12; lens.rings=6
    var glass := StandardMaterial3D.new()
    glass.albedo_color=Color("#1c3941"); glass.metallic=0.45; glass.roughness=0.18
    lens.material=glass
    var lens_node := _mesh(housing,lens,Vector3(0,-0.04,sign_z*0.064))
    _cars[car]={"mount":mount,"housing":housing,"lens":lens_node,"face":face}

func _mesh(parent: Node3D,mesh: Mesh,pos: Vector3) -> MeshInstance3D:
    var instance := MeshInstance3D.new()
    instance.mesh=mesh
    instance.position=pos
    instance.layers=17
    parent.add_child(instance)
    return instance

func _process(delta: float) -> void:
    if not is_instance_valid(_game) or not is_instance_valid(_view): return
    # Fourth original car is attached asynchronously by the existing scene.
    _install_cars()
    var viewer := get_viewport().get_camera_3d()
    var nearby := false
    for car in _cars:
        var entry: Dictionary=_cars[car]
        var housing := entry.housing as Node3D
        var mount := entry.mount as Node3D
        var using_this := str(_game.get("camera_mode")) == "salon" and viewer != null and viewer.global_position.distance_squared_to(mount.global_position) < 0.16
        housing.visible=not using_this
        if viewer != null and viewer.global_position.distance_squared_to((entry.face as Node3D).global_position) < 10000.0: nearby=true
    if not nearby: return
    _scroll+=delta*43.0
    _tick+=delta
    if _tick < 0.05: return
    _tick=0.0
    var information: Dictionary=_game.call("passenger_information")
    var message := str(information.get("current_station","")) if bool(information.get("at_station",false)) else "НАСТУПНАЯ СТАНЦЫЯ — "+str(information.get("next_station","УРУЧЧА"))
    if bool(information.get("at_station",false)): message="СТАНЦЫЯ — "+message
    if message != _message:
        _message=message
        _scroll=0.0
        var font := ThemeDB.fallback_font
        _span=maxf(512.0,font.get_string_size(_message,HORIZONTAL_ALIGNMENT_LEFT,-1,30).x+90.0)
        for label in _labels: label.text=_message
    var offset := fposmod(_scroll,_span)
    for i in range(_labels.size()): _labels[i].position.x=-offset+float(i)*_span
    _view.render_target_update_mode=SubViewport.UPDATE_ONCE
