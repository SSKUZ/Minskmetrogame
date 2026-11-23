extends MeshInstance3D
## Rear-end CCTV shares the actual station world, including any train in it.
## Only a nearby, front-facing screen renders; no recursive screen/mirror views.
const SCREEN_LAYER := 1 << 18
const MIRROR_LAYER := 1 << 19
@export var camera_position := Vector3.ZERO
@export var camera_target := Vector3.ZERO
var _view: SubViewport
var _camera: Camera3D
var _screen: StandardMaterial3D
var _elapsed := 0.0

func _ready() -> void:
    layers=SCREEN_LAYER
    cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    _screen=StandardMaterial3D.new()
    _screen.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
    _screen.albedo_color=Color.WHITE
    _screen.albedo_texture=preload("res://modules/stations/moskovskaya/art/platform_cctv.jpg")
    _screen.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR
    material_override=_screen
    _view=SubViewport.new()
    _view.name="RearPlatformCameraFeed"
    _view.size=Vector2i(512,288)
    _view.world_3d=get_viewport().world_3d
    _view.handle_input_locally=false
    _view.render_target_update_mode=SubViewport.UPDATE_DISABLED
    add_child(_view)
    _camera=Camera3D.new()
    _camera.fov=64.0
    _camera.near=0.10;_camera.far=160.0
    _camera.cull_mask=0xFFFFF & ~(SCREEN_LAYER | MIRROR_LAYER)
    _view.add_child(_camera)
    _camera.current=true
    var station := get_parent() as Node3D
    _camera.global_position=station.to_global(camera_position)
    _camera.look_at(station.to_global(camera_target),station.global_basis.y)
    # Swap only after the first completed draw, avoiding a black initial frame.
    RenderingServer.frame_post_draw.connect(_first_frame,CONNECT_ONE_SHOT)
    _view.render_target_update_mode=SubViewport.UPDATE_ONCE

func _first_frame() -> void:
    if is_instance_valid(_view):_screen.albedo_texture=_view.get_texture()

func _process(delta: float) -> void:
    _elapsed+=delta
    if _elapsed<0.25:return
    _elapsed=0.0
    var viewer := get_viewport().get_camera_3d()
    if viewer==null:return
    var eye := viewer.global_position
    if eye.distance_squared_to(global_position)>1600.0:return
    if (eye-global_position).dot(global_basis.z)<0.05:return
    if viewer.is_position_behind(global_position):return
    _view.render_target_update_mode=SubViewport.UPDATE_ONCE
