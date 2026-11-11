extends RefCounted
## Restore the original Zakhar Goodmix Duo artwork on both head-car cab bulkheads.
## Visual-only overlay: no original GLB meshes, door nodes or cab controls are edited.
const POSTER = preload("res://assets/saloon_v49/goodmix-duo-zakhar.jpg")
const WIDTH := 1.48
const HEIGHT := 1.04

static func apply(train: Node3D) -> void:
    var head_ends := {
        "OriginalV106Car01": -7.56,
        "OriginalV106Car04": 67.58,
    }
    for car in train.get_children():
        if not car is Node3D or not head_ends.has(str(car.name)):
            continue
        if car.has_node("GoodmixZakharRestored"):
            continue
        var image := MeshInstance3D.new()
        image.name = "GoodmixZakharRestored"
        var quad := QuadMesh.new()
        quad.size = Vector2(WIDTH, HEIGHT)
        image.mesh = quad
        var material := StandardMaterial3D.new()
        material.albedo_texture = POSTER
        material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        material.cull_mode = BaseMaterial3D.CULL_DISABLED
        material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
        image.material_override = material
        image.position = Vector3(0.0, 2.65, head_ends[str(car.name)])
        # QuadMesh faces along local +Z. Keep double-sided for both head-car orientations.
        image.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        car.add_child(image)
