extends RefCounted
## Original Goodmix/Zakhar art, visual-only. Restore to the passenger-facing
## surfaces of the cab bulkheads of both head cars, not outside the body.
const POSTER = preload("res://assets/saloon_v49/goodmix-duo-zakhar.jpg")
const WIDTH := 1.48
const HEIGHT := 1.04
const INSET := 0.38

static func apply(train: Node3D) -> void:
    for car in train.get_children():
        if not car is Node3D:
            continue
        var name := str(car.name)
        if name != "OriginalV106Car01" and name != "OriginalV106Car04":
            continue
        if car.has_node("GoodmixZakharRestored"):
            continue
        var bounds := _car_bounds(car)
        if bounds.size.z <= 0.0:
            push_warning("Goodmix: no geometry bounds for " + name)
            continue
        # The head cars face opposite ends of the four-car consist.
        # Use their actual bounds, never absolute world Z coordinates.
        var front := name == "OriginalV106Car01"
        var wall_z := bounds.position.z + INSET if front else bounds.end.z - INSET
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
        image.position = Vector3(bounds.get_center().x, 2.48, wall_z)
        image.rotation.y = 0.0 if front else PI
        image.layers = 17
        image.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        car.add_child(image)
        print("GOODMIX_RESTORED car=%s z=%.3f" % [name, wall_z])

static func _car_bounds(car: Node3D) -> AABB:
    var result := AABB()
    var found := false
    for node in car.find_children("*", "MeshInstance3D", true, false):
        var mesh := node as MeshInstance3D
        if mesh.mesh == null:
            continue
        var box := (car.global_transform.affine_inverse() * mesh.global_transform) * mesh.mesh.get_aabb()
        if not found:
            result = box
            found = true
        else:
            result = result.merge(box)
    return result
