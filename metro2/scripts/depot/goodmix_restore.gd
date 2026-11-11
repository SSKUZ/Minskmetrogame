extends RefCounted
## Original Goodmix/Zakhar art, visual-only. Restore to the passenger-facing
## surfaces of the cab bulkheads of both head cars, not outside the body.
const POSTER = preload("res://assets/saloon_v49/goodmix-duo-zakhar.jpg")
const WIDTH := 1.48
const HEIGHT := 1.04

static func apply(train: Node3D) -> void:
    for car in train.get_children():
        if not car is Node3D:
            continue
        var name := str(car.name)
        if name != "OriginalV106Car01" and name != "OriginalV106Car04":
            continue
        if car.has_node("GoodmixZakharRestored"):
            continue
        # Reuse the original framed banner when the GLB retains its named mesh.
        var material := StandardMaterial3D.new()
        material.albedo_texture = POSTER
        material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        material.cull_mode = BaseMaterial3D.CULL_DISABLED
        material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
        var restored := false
        for node in car.find_children("*", "MeshInstance3D", true, false):
            var label := str(node.name).to_lower()
            if label.contains("goodmix") and label.contains("cab") and label.contains("banner"):
                (node as MeshInstance3D).material_override = material
                restored = true
        if restored:
            continue
        # LOD1 may merge the banner into the body mesh. Its original frame remains;
        # put the replacement print 4 mm in front of that existing framed surface.
        var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/saloon_v49/mounts.json"))[name]
        var front := name == "OriginalV106Car01"
        var wall_z := float(layout.door_z[0]) - 1.195 + 0.004 if front else float(layout.door_z[3]) + 1.195 - 0.004
        var image := MeshInstance3D.new()
        image.name = "GoodmixZakharRestored"
        var quad := QuadMesh.new()
        quad.size = Vector2(WIDTH, HEIGHT)
        image.mesh = quad
        image.material_override = material
        image.position = Vector3(0.0, 2.44, wall_z)
        image.rotation.y = 0.0 if front else PI
        image.layers = 17
        image.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        car.add_child(image)
        print("GOODMIX_RESTORED car=%s z=%.3f" % [name, wall_z])

