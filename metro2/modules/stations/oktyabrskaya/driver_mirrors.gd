extends MeshInstance3D
## One nearest visible mirror updates at six frames/second, including on Web GL.
## Reflect the viewer eye and use an off-axis frustum through the physical mirror.
const MIRROR_LAYER := 1 << 19
var _view: SubViewport
var _camera: Camera3D
var _material: StandardMaterial3D
var _elapsed := 0.0
var _has_frame := false

func _ready() -> void:
    add_to_group("oktyabrskaya_driver_mirrors")
    layers=MIRROR_LAYER
    cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    _material=StandardMaterial3D.new()
    _material.albedo_color=Color("#a7b4b3")
    _material.metallic=0.8;_material.roughness=0.08
    material_override=_material

func _process(delta: float) -> void:
    _elapsed+=delta
    if _elapsed<0.1667:return
    _elapsed=0.0
    var viewer := get_viewport().get_camera_3d()
    if viewer==null:return
    var eye := viewer.global_position
    var closest: Node3D=null
    var nearest := 32.0*32.0
    for item in get_tree().get_nodes_in_group("oktyabrskaya_driver_mirrors"):
        var candidate := item as Node3D
        if not candidate.is_visible_in_tree():continue
        if (eye-candidate.global_position).dot(candidate.global_basis.z)<0.10:continue
        if viewer.is_position_behind(candidate.global_position):continue
        var d := eye.distance_squared_to(candidate.global_position)
        if d<nearest:nearest=d;closest=candidate
    if closest!=self:return
    if _view==null:_create_reflection(viewer)
    var local_eye := to_local(eye)
    var distance := maxf(0.10,local_eye.z)
    _camera.global_transform=Transform3D(global_basis*Basis(Vector3.UP,PI),to_global(Vector3(local_eye.x,local_eye.y,-local_eye.z)))
    var size: Vector2=get_meta("mirror_size",Vector2(0.55,1.53))
    var near := 0.05
    _camera.set_frustum(size.y*near/distance,Vector2(local_eye.x,-local_eye.y)*near/distance,near,140.0)
    _view.render_target_update_mode=SubViewport.UPDATE_ONCE
    if not _has_frame:
        _material.albedo_texture=_view.get_texture()
        _material.albedo_color=Color(0.91,0.96,0.94)
        _material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
        _material.uv1_scale=Vector3(-1,1,1)
        _material.uv1_offset=Vector3(1,0,0)
        _has_frame=true

func _create_reflection(viewer: Camera3D) -> void:
    _view=SubViewport.new()
    _view.name="NearestMirrorReflection"
    _view.size=Vector2i(192,512)
    _view.world_3d=get_viewport().world_3d
    _view.handle_input_locally=false
    _view.render_target_update_mode=SubViewport.UPDATE_DISABLED
    add_child(_view)
    _camera=Camera3D.new()
    _camera.keep_aspect=Camera3D.KEEP_HEIGHT
    _camera.cull_mask=viewer.cull_mask & ~MIRROR_LAYER
    _camera.environment=viewer.environment
    _view.add_child(_camera)
    _camera.current=true
