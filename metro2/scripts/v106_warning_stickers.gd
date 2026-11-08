extends RefCounted
## Rebuild exactly two fixed-body caution signs per door opening.
## Imported warning quads are never reused: their positions may overlap doors.
const WARNING = preload("res://assets/v106_warning/v106_warning_caution.png")
const SIGN_WIDTH := 0.16
const SIGN_HEIGHT := 0.115
const SIGN_Y := 1.28
const EDGE_MARGIN := 0.10
const SURFACE_OFFSET := 0.065

static func restore(train: Node3D, door_system: Node) -> void:
    var material := StandardMaterial3D.new()
    material.albedo_texture = WARNING
    material.albedo_color = Color.WHITE
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
    material.alpha_scissor_threshold = 0.025
    material.cull_mode = BaseMaterial3D.CULL_DISABLED
    material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
    material.render_priority = 2
    var all_leaves: Array = door_system.get("leaves")
    for car in train.get_children():
        if not car is Node3D or not str(car.name).begins_with("OriginalV106Car"):
            continue
        # Imported GLB warning meshes are the cause of overlapping decals.
        # Hide ALL of them, including those nested under moving door leaves.
        for node in car.find_children("passenger-door-caution*", "MeshInstance3D", true, false):
            (node as MeshInstance3D).hide()
        var old := car.get_node_or_null("FixedBodyWarningSigns")
        if old != null:
            old.queue_free()
        var holder := Node3D.new()
        holder.name = "FixedBodyWarningSigns"
        car.add_child(holder)
        var side_leaves: Array = [[], []]
        for leaf in all_leaves:
            var part: Dictionary = leaf
            var piece: Dictionary = part["parts"][0]
            var root := piece["node"] as Node3D
            if root == null or not car.is_ancestor_of(root):
                continue
            var center: Vector3 = part["center"]
            side_leaves[0 if center.x < 0.0 else 1].append(part)
        var created := 0
        for side in side_leaves:
            side.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
                var ac: Vector3 = a["center"]
                var bc: Vector3 = b["center"]
                return ac.z < bc.z
            )
            if side.size() != 8:
                push_warning("Warning signs: expected 8 door leaves per side on " + str(car.name) + ", got " + str(side.size()))
                continue
            for pair in range(4):
                var first: Dictionary = side[pair * 2]
                var second: Dictionary = side[pair * 2 + 1]
                var a: AABB = first["parts"][0]["bounds"]
                var b: AABB = second["parts"][0]["bounds"]
                var side_x: float = (first["center"] as Vector3).x
                var direction := -1.0 if side_x < 0.0 else 1.0
                var outer_face_x := maxf(maxf(absf(a.position.x), absf(a.end.x)), maxf(absf(b.position.x), absf(b.end.x)))
                var x := direction * (outer_face_x + SURFACE_OFFSET)
                var start_z := minf(a.position.z, b.position.z) - EDGE_MARGIN - SIGN_WIDTH * 0.5
                var end_z := maxf(a.end.z, b.end.z) + EDGE_MARGIN + SIGN_WIDTH * 0.5
                _make_sign(holder, material, Vector3(x, SIGN_Y, start_z), pair, "A")
                _make_sign(holder, material, Vector3(x, SIGN_Y, end_z), pair, "B")
                created += 2
        print("V106_WARNING_FIXED ", car.name, " signs=", created)

static func _make_sign(holder: Node3D, material: Material, pos: Vector3, pair: int, edge: String) -> void:
    var sign := MeshInstance3D.new()
    sign.name = "BodyCaution_%d_%s" % [pair, edge]
    var quad := QuadMesh.new()
    quad.size = Vector2(SIGN_WIDTH, SIGN_HEIGHT)
    sign.mesh = quad
    sign.material_override = material
    sign.position = pos
    sign.rotation.y = -PI * 0.5 if pos.x < 0.0 else PI * 0.5
    sign.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    holder.add_child(sign)
