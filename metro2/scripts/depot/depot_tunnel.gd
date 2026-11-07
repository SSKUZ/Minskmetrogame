extends "res://scripts/tunnel_lightweight_straight.gd"
const Route = preload("res://scripts/depot/route_profile.gd")
var _entrance_shade: MeshInstance3D

func _ready() -> void:
    super._ready()
    # Darkness follows the far pooled tunnel boundary, beyond visible fog.
    # It must never receive the outdoor haze or disappear after entry.
    _entrance_shade = MeshInstance3D.new()
    var shade_mesh := QuadMesh.new()
    shade_mesh.size = Vector2(6.34,7.35)
    _entrance_shade.mesh = shade_mesh
    _entrance_shade.position = Vector3(center_x,3.34,-64.1)
    var shade_shader := Shader.new()
    shade_shader.code = """shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;
void fragment() { ALBEDO = vec3(0.002,0.003,0.004); }
"""
    var shade_material := ShaderMaterial.new()
    shade_material.shader = shade_shader
    _entrance_shade.material_override = shade_material
    _entrance_shade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(_entrance_shade)
    # The 95 mm rail heads have 1,520 mm clear gauge on the new route.
    for i in range(_rail_clips.instance_count):
        var pose := _rail_clips.get_instance_transform(i)
        pose.origin.x = signf(pose.origin.x)*Route.RAIL_CENTER
        _rail_clips.set_instance_transform(i,pose)

func _process(delta: float) -> void:
    super._process(delta)
    if _entrance_shade != null and is_instance_valid(_camera):
        var forward_z: float = minf(Route.PORTAL_Z,_camera.global_position.z)
        if is_instance_valid(_train):
            forward_z = minf(forward_z,_train.global_position.z+_train_bounds.position.z)
        var far_boundary: float = floor((forward_z-VISIBLE_DISTANCE-GUARD_DISTANCE)/MODULE_LENGTH)*MODULE_LENGTH
        _entrance_shade.position.z = minf(-64.1,far_boundary+0.05)
        _entrance_shade.visible = true

func _include_slots(required: Dictionary,z0: float,z1: float) -> void:
    super._include_slots(required,minf(z0,Route.PORTAL_Z),minf(z1,Route.PORTAL_Z))
    for slot in required.keys():
        if int(slot)*MODULE_LENGTH >= Route.PORTAL_Z: required.erase(slot)
    # Keep the existing entrance modules ready while approaching on the surface.
    if is_instance_valid(_train) and _train.global_position.z+_train_bounds.position.z > Route.PORTAL_Z:
        for slot in range(-4,6): required[slot] = true

func _new_section() -> Node3D:
    var section := super._new_section()
    for child in section.get_children():
        if child is MeshInstance3D and (child as MeshInstance3D).mesh == _rail:
            (child as Node3D).position.x = signf((child as Node3D).position.x)*Route.RAIL_CENTER
    return section

func constrain_camera(world_position: Vector3) -> Vector3:
    if world_position.z > Route.PORTAL_Z:
        var point := world_position
        point.y = maxf(point.y,Route.height(point.z)+0.35)
        return point
    return super.constrain_camera(world_position)
