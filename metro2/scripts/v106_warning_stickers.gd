extends RefCounted
## Rebind the original 64 warning meshes. Their exported PNG had alpha=0
## everywhere; the original canvas drawing is preserved as a portable PNG.
const WARNING = preload("res://assets/v106_warning/v106_warning_caution.png")

static func restore(train: Node3D) -> void:
    var material := StandardMaterial3D.new()
    material.albedo_texture = WARNING
    material.albedo_color = Color.WHITE
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
    material.alpha_scissor_threshold = 0.025
    material.cull_mode = BaseMaterial3D.CULL_DISABLED
    material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
    material.render_priority = 2
    for car in train.get_children():
        if not car is Node3D or not str(car.name).begins_with("OriginalV106Car"):
            continue
        for node in car.find_children("passenger-door-caution*","MeshInstance3D",true,false):
            var decal := node as MeshInstance3D
            # These belong to the fixed car body, never to a translating leaf.
            if decal.get_parent() != car: decal.reparent(car,true)
            decal.material_override = material
            decal.layers = 1
            decal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
            decal.show()
