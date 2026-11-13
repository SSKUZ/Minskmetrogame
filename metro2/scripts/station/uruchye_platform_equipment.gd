extends Node3D
## Fixed platform equipment; observes the existing train without controlling it.
const FLOOR := 1.1805
const PLATFORM_X := -5.37
const CLOCK_SAVE := "user://uruchye_interval.cfg"
var _digit_mesh: MultiMesh
var _clock_second := -1
var _last_departure := 0
var _armed := false
var _departed_this_visit := false
var _game: Node3D
var _train: Node3D
var _mirror_view: SubViewport
var _mirror_camera: Camera3D
var _mirror: Node3D
var _mirror_tick := 0.0
var _amber := Color(1.0,0.57,0.045)
const DIGITS := [0x3f,0x06,0x5b,0x4f,0x66,0x6d,0x7d,0x07,0x7f,0x6f]

func _ready() -> void:
    _find_game()
    var saved := ConfigFile.new()
    if saved.load(CLOCK_SAVE) == OK:
        _last_departure = int(saved.get_value("interval","departure_unix",0))
    if _last_departure > int(Time.get_unix_time_from_system()): _last_departure=0
    _stop_marks()
    _platform_mirror()


func _find_game() -> void:
    var node: Node = get_parent()
    while node != null:
        var candidate := node.get_node_or_null("PlayerTrainPlacement") as Node3D
        if candidate != null:
            _game=node as Node3D
            _train=candidate
            return
        node=node.get_parent()

func _material(color: Color,metallic: float = 0.0) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color=color
    material.metallic=metallic
    material.roughness=0.45 if metallic > 0.0 else 0.8
    return material

func _box(parent: Node3D,label: String,size: Vector3,pos: Vector3,material: Material) -> MeshInstance3D:
    var mesh := BoxMesh.new()
    mesh.size=size
    mesh.material=material
    var instance := MeshInstance3D.new()
    instance.name=label
    instance.mesh=mesh
    instance.position=pos
    parent.add_child(instance)
    return instance

func _stop_marks() -> void:
    var white := _material(Color("#e9e7de"))
    var black := _material(Color("#15191b"))
    # A low painted stopping datum between the running rails, not a buffer stop.
    for i in range(10):
        var x := 0.992-0.71+(float(i)+0.5)*0.142
        _box(self,"TrackStopStripe%02d" % i,Vector3(0.142,0.09,0.13),Vector3(x,0.035,-1.25),white if i%2 == 0 else black)
    # Matching vertical datum on the outer track wall, at the same stop plane.
    for i in range(8):
        _box(self,"WallStopStripe%02d" % i,Vector3(0.055,0.14,0.15),Vector3(3.285,1.26+float(i)*0.14,-1.25),white if i%2 == 0 else black)

func _platform_mirror() -> void:
    var steel := _material(Color("#c4c7c4"),0.80)
    _mirror=Node3D.new()
    _mirror.name="DriverPlatformMirror"
    _mirror.position=Vector3(-0.78,FLOOR+1.55,-2.80)
    _mirror.rotation.y=deg_to_rad(8.0)
    add_child(_mirror)
    _box(_mirror,"MirrorBack",Vector3(0.72,2.05,0.065),Vector3.ZERO,steel)
    var post := MeshInstance3D.new()
    var pole := CylinderMesh.new()
    pole.top_radius=0.055; pole.bottom_radius=0.055; pole.height=0.53
    pole.radial_segments=16; pole.material=steel
    post.mesh=pole
    post.position=Vector3(0,-1.285,0)
    _mirror.add_child(post)
    _box(_mirror,"MirrorFoot",Vector3(0.29,0.035,0.26),Vector3(0,-1.535,0),steel)
    _mirror_view=SubViewport.new()
    _mirror_view.name="PlatformReflection"
    _mirror_view.size=Vector2i(384,640)
    _mirror_view.world_3d=get_world_3d()
    _mirror_view.render_target_update_mode=SubViewport.UPDATE_DISABLED
    add_child(_mirror_view)
    _mirror_camera=Camera3D.new()
    _mirror_camera.cull_mask=1 # Exclude every mirror face to avoid feedback.
    _mirror_camera.near=0.08
    _mirror_camera.far=145.0
    _mirror_camera.fov=95.0
    _mirror_view.add_child(_mirror_camera)
    _mirror_camera.current=true
    var material := StandardMaterial3D.new()
    material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
    material.albedo_texture=_mirror_view.get_texture()
    material.uv1_scale=Vector3(-1,1,1)
    material.uv1_offset=Vector3(1,0,0)
    var pane := QuadMesh.new()
    pane.size=Vector2(0.66,1.98)
    pane.material=material
    var face := MeshInstance3D.new()
    face.name="LivePlatformMirrorGlass"
    face.mesh=pane
    face.position.z=0.036
    face.layers=64
    face.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    _mirror.add_child(face)

func _clock() -> void:
    var panel := Node3D.new()
    panel.name="UruchyeTimeAndDepartureInterval"
    panel.position=Vector3(0.992,4.91,-19.56)
    add_child(panel)
    _box(panel,"ClockCase",Vector3(2.03,0.43,0.11),Vector3.ZERO,_material(Color("#161718")))
    var material := StandardMaterial3D.new()
    material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
    material.vertex_color_use_as_albedo=true
    var bar := BoxMesh.new()
    bar.size=Vector3.ONE
    bar.material=material
    _digit_mesh=MultiMesh.new()
    _digit_mesh.transform_format=MultiMesh.TRANSFORM_3D
    _digit_mesh.use_colors=true
    _digit_mesh.mesh=bar
    _digit_mesh.instance_count=76 # 10 seven-segment digits and three colon pairs.
    var centers := PackedFloat32Array([-0.89,-0.73,-0.49,-0.33,-0.09,0.07,0.36,0.52,0.76,0.92])
    var positions := [Vector2(0,0.13),Vector2(0.055,0.065),Vector2(0.055,-0.065),Vector2(0,-0.13),Vector2(-0.055,-0.065),Vector2(-0.055,0.065),Vector2.ZERO]
    for digit in range(10):
        for segment in range(7):
            var horizontal: bool = segment in [0,3,6]
            var size := Vector3(0.10,0.024,0.012) if horizontal else Vector3(0.022,0.10,0.012)
            var p: Vector2=positions[segment]
            _digit_mesh.set_instance_transform(digit*7+segment,Transform3D(Basis.from_scale(size),Vector3(centers[digit]+p.x,p.y,0.063)))
    for colon in range(3):
        var x: float=[-0.61,-0.21,0.64][colon]
        for dot in range(2):
            _digit_mesh.set_instance_transform(70+colon*2+dot,Transform3D(Basis.from_scale(Vector3(0.022,0.022,0.012)),Vector3(x,0.045 if dot == 0 else -0.045,0.063)))
            _digit_mesh.set_instance_color(70+colon*2+dot,_amber)
    var display := MultiMeshInstance3D.new()
    display.name="LiveClockDigits"
    display.multimesh=_digit_mesh
    display.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    panel.add_child(display)

func _observe_departure(now: int) -> void:
    if not is_instance_valid(_train) or not is_instance_valid(_game):
        _find_game()
        return
    var station_z := to_local(_train.global_position).z
    var speed := absf(float(_game.get("speed")))
    if station_z > 115.0 or station_z < -40.0:
        _armed=false
        _departed_this_visit=false
    if not _departed_this_visit and absf(station_z-9.603) < 6.0 and speed < 0.03:
        _armed=true
    if _armed and not _departed_this_visit and speed > 0.25:
        _last_departure=now
        _armed=false
        _departed_this_visit=true
        var saved := ConfigFile.new()
        saved.set_value("interval","departure_unix",_last_departure)
        saved.save(CLOCK_SAVE)

func _update_clock(now: int) -> void:
    # Station clocks use Minsk time even when the browser is in another zone.
    var date := Time.get_datetime_dict_from_unix_time(now+3*3600)
    var values: Array[int]=[int(date.hour)/10,int(date.hour)%10,int(date.minute)/10,int(date.minute)%10,int(date.second)/10,int(date.second)%10,-1,-1,-1,-1]
    if _last_departure > 0:
        var elapsed := maxi(0,now-_last_departure)
        var minutes := mini(99,elapsed/60)
        values[6]=minutes/10; values[7]=minutes%10
        values[8]=(elapsed%60)/10; values[9]=elapsed%10
    for digit in range(10):
        var bits: int=DIGITS[values[digit]] if values[digit] >= 0 else 0x40
        for segment in range(7):
            _digit_mesh.set_instance_color(digit*7+segment,_amber if (bits & (1<<segment)) != 0 else Color(0.07,0.045,0.02))

func _process(delta: float) -> void:
    _mirror_tick+=delta
    if _mirror_tick < 0.2: return
    _mirror_tick=0.0
    var viewer := get_viewport().get_camera_3d()
    if viewer == null or viewer.global_position.distance_to(_mirror.global_position) > 140.0: return
    if not viewer.is_position_in_frustum(_mirror.global_position): return
    _mirror_camera.global_position=_mirror.to_global(Vector3(0,0,0.10))
    _mirror_camera.look_at(to_global(Vector3(PLATFORM_X,2.10,27.0)),global_basis.y)
    _mirror_view.render_target_update_mode=SubViewport.UPDATE_ONCE
