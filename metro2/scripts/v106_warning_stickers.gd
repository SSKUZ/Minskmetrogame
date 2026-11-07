extends RefCounted
## Keep exactly one caution label on each BODY side of each passenger doorway.
## Original artwork is preserved; duplicate imported meshes are hidden.
const WARNING = preload("res://assets/v106_warning/v106_warning_caution.png")
const LABELS_PER_SIDE := 8
const LOWER_BY_METRES := 0.06

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
        var sides := [[], []]
        for node in car.find_children("passenger-door-caution*", "MeshInstance3D", true, false):
            var decal := node as MeshInstance3D
            # Work in the car's local coordinates, not world/train coordinates.
            var local_pos := car.to_local(decal.global_position)
            sides[0 if local_pos.x < 0.0 else 1].append(decal)
            decal.hide()
        for side in sides:
            # Sort along the car. Every pair belongs to one doorway edge;
            # imported duplicate quads must never become additional labels.
            side.sort_custom(func(a: MeshInstance3D, b: MeshInstance3D) -> bool:
                return car.to_local(a.global_position).z < car.to_local(b.global_position).z
            )
            if side.is_empty():
                continue
            # Partition the side into the four door areas. Preserve only the
            # two outermost warning meshes of each area (body-side labels).
            for doorway in range(4):
                var begin := int(floor(float(doorway * side.size()) / 4.0))
                var end := int(floor(float((doorway + 1) * side.size()) / 4.0))
                if end <= begin:
                    continue
                var chosen: Array[MeshInstance3D] = [side[begin]]
                if end - begin > 1:
                    chosen.append(side[end - 1])
                for decal in chosen:
                    # Never parent to a moving door leaf.
                    if decal.get_parent() != car:
                        decal.reparent(car, true)
                    decal.position.y -= LOWER_BY_METRES
                    decal.material_override = material
                    decal.layers = 1
                    decal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
                    decal.show()
            if side.size() != LABELS_PER_SIDE:
                print("V106_CAUTION_DEDUP car=", car.name, " candidates=", side.size(), " visible_max=", LABELS_PER_SIDE)
