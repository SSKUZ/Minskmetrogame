extends Node
## Door leaves discovered by their imported mesh bounds; GLB originals stay untouched.
## Existing leaf parents move all child meshes together with their caution decal.
signal ready_count(count: int)
var leaves: Array[Dictionary] = []
var openness: float = 0.0
var target_open: bool = false
# The depot-to-Uruchye platform is on the train's left side.
# Only this side is enabled for passenger service.
const PLATFORM_SIDE := -1.0
var validated: bool = false
const SLIDE_METERS := 0.56
const ANIMATION_SECONDS := 1.3

func setup(consist: Node3D) -> void:
    leaves.clear()
    validated = false
    for car in consist.get_children():
        var panels: Array[Dictionary] = []
        var decals: Array[Dictionary] = []
        _scan(car, car, panels, decals)
        var grouped: Dictionary = {}
        for item in panels:
            var center: Vector3 = item["center"]
            var key := "%s:%s" % [roundi(center.x * 10.0), roundi(center.z * 100.0)]
            if not grouped.has(key):
                grouped[key] = []
            grouped[key].append(item)
        var car_leaves: Array[Dictionary] = []
        for key in grouped:
            var group: Array = grouped[key]
            if group.size() != 1:
                continue
            var center: Vector3 = group[0]["center"]
            car_leaves.append({"parts": group, "center": center, "decals": []})
        for decal in decals:
            var decal_center: Vector3 = decal["center"]
            var best_distance := 0.65
            var best_index := -1
            for i in range(car_leaves.size()):
                var center: Vector3 = car_leaves[i]["center"]
                var distance := absf(center.z - decal_center.z) + absf(center.x - decal_center.x) * 0.05
                if signf(center.x) == signf(decal_center.x) and distance < best_distance:
                    best_distance = distance
                    best_index = i
            if best_index >= 0:
                car_leaves[best_index]["decals"].append(decal)
        if car_leaves.size() != 16:
            push_error("V106 door discovery: %s found %d/16 leaves" % [car.name, car_leaves.size()])
            leaves.clear()
            ready_count.emit(0)
            return
        for leaf in car_leaves:
            if leaf["decals"].size() != 1:
                push_error("V106 door decal mismatch in %s" % car.name)
                leaves.clear()
                ready_count.emit(0)
                return
        # Require one and only one matching leaf within the same car.
        for i in range(car_leaves.size()):
            var center: Vector3 = car_leaves[i]["center"]
            var partners: Array[int] = []
            for j in range(car_leaves.size()):
                if i == j:
                    continue
                var other: Vector3 = car_leaves[j]["center"]
                var distance := absf(other.z - center.z)
                if absf(other.x - center.x) < 0.2 and distance > 0.60 and distance < 0.80:
                    partners.append(j)
            if partners.size() != 1:
                push_error("Ambiguous door pairing in %s, leaf %d" % [car.name, i])
                leaves.clear()
                ready_count.emit(0)
                return
            var partner: Vector3 = car_leaves[partners[0]]["center"]
            car_leaves[i]["direction"] = signf(center.z - partner.z)
        leaves.append_array(car_leaves)
    validated = leaves.size() == 64
    ready_count.emit(leaves.size())
    if leaves.size() != 64:
        push_warning("Door controller expected 64 leaves; found %d. Animation disabled." % leaves.size())

func _scan(root: Node, car: Node3D, panels: Array[Dictionary], decals: Array[Dictionary]) -> void:
    if root is MeshInstance3D and root.mesh != null:
        var bounds: AABB = root.get_aabb()
        var size: Vector3 = bounds.size
        var to_car: Transform3D = car.global_transform.affine_inverse() * root.global_transform
        var center: Vector3 = to_car * bounds.get_center()
        if str(root.name).begins_with("passenger-door-caution"):
            decals.append({"node": root, "center": center, "origin": root.position,
                "slide_axis": root.get_parent().global_basis.inverse() * car.global_basis.z})
        elif size.x > 0.67 and size.x < 0.70 and size.y > 2.0 and size.y < 2.1 and size.z > 0.02 and size.z < 0.04 and absf(center.x) > 1.0 and absf(center.x) < 1.4:
            # Move the existing leaf parent, including skin, glass and trim.
            var leaf: Node3D = root.get_parent()
            panels.append({"node": leaf, "center": center, "origin": leaf.position,
                "slide_axis": leaf.get_parent().global_basis.inverse() * car.global_basis.z})
    for child in root.get_children():
        _scan(child, car, panels, decals)

func _process(delta: float) -> void:
    if not validated:
        return
    var goal := 1.0 if target_open else 0.0
    openness = move_toward(openness, goal, delta / ANIMATION_SECONDS)
    for leaf in leaves:
        var direction: float = leaf["direction"]
        var side_open := openness if float(leaf["center"].x) * PLATFORM_SIDE > 0.0 else 0.0
        for item in leaf["parts"]:
            var node: Node3D = item["node"]
            node.position = item["origin"] + item["slide_axis"] * direction * SLIDE_METERS * side_open
        for item in leaf["decals"]:
            var node: Node3D = item["node"]
            node.position = item["origin"] + item["slide_axis"] * direction * SLIDE_METERS * side_open

func request_open(speed_mps: float) -> void:
    if speed_mps > 0.05 or not validated:
        return
    target_open = true

func request_close() -> void:
    target_open = false

func can_move() -> bool:
    return not target_open and openness <= 0.001 and validated
