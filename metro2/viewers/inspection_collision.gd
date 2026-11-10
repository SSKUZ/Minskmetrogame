extends RefCounted
## Disposable conservative bounds, separate from original visual resources.
## Bounds may stop the camera early; FREE mode deliberately bypasses them.
const MASK := 1 << 19

static func build(module: Node3D, parent: Node3D) -> StaticBody3D:
    var body := StaticBody3D.new()
    body.name = "InspectionCollision"
    body.collision_layer = MASK
    body.collision_mask = 0
    parent.add_child(body)
    var shapes: Dictionary = {}
    var pending: Array[Node] = [module]
    var count := 0
    while not pending.is_empty():
        var node: Node = pending.pop_back()
        if node is GeometryInstance3D and not node.is_visible_in_tree(): continue
        if node is MeshInstance3D and node.mesh != null:
            count += _add_box(body,node.global_transform*node.get_aabb(),shapes)
        elif node is MultiMeshInstance3D and node.multimesh != null and node.multimesh.mesh != null:
            var mm := node.multimesh as MultiMesh
            var total := mm.instance_count if mm.visible_instance_count < 0 else mm.visible_instance_count
            var bounds := mm.mesh.get_aabb()
            for i in range(total):
                count += _add_box(body,node.global_transform*mm.get_instance_transform(i)*bounds,shapes)
        for child in node.get_children(): pending.append(child)
    body.set_meta("proxy_count",count)
    return body

static func _add_box(body: StaticBody3D, bounds: AABB, cache: Dictionary) -> int:
    if bounds.size.length() < 0.45: return 0
    var size := Vector3(maxf(0.025,bounds.size.x),maxf(0.025,bounds.size.y),maxf(0.025,bounds.size.z))
    size = size.snapped(Vector3.ONE*0.001)
    if not cache.has(size):
        var box := BoxShape3D.new()
        box.size = size
        cache[size] = box
    var owner_id := body.create_shape_owner(body)
    body.shape_owner_set_transform(owner_id,Transform3D(Basis.IDENTITY,bounds.get_center()))
    body.shape_owner_add_shape(owner_id,cache[size])
    return 1
