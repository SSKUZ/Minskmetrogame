extends Node
## Door leaves discovered by their imported mesh bounds; GLB originals stay untouched.
## Two coplanar meshes per leaf (glass/skin) move together with their caution decal.
signal ready_count(count: int)
var leaves: Array[Dictionary] = []
var openness: float = 0.0
var target_open: bool = false
var validated: bool = false
const SLIDE_METERS := 0.56
const ANIMATION_SECONDS := 1.3

func setup(consist: Node3D) -> void:
    leaves.clear()
    validated = false
    for car in consist.get_children():
        var panels: Array[Dictionary] = []
        var decals: Array[Dictionary] = []
        _scan(car, panels, decals)
        var grouped: Dictionary = {}
        for item in panels:
            var mesh: MeshInstance3D = item["node"]
            var center: Vector3 = item["center"]
            var key := "%s:%s" % [roundi(center.x * 10.0), roundi(center.z * 100.0)]
            if not grouped.has(key):
                grouped[key] = []
            grouped[key].append(item)
        var car_leaves: Array[Dictionary] = []
        for key in grouped:
            var group: Array = grouped[key]
            if group.size() != 2:
                continue
            var center: Vector3 = group[0]["center"]
            car_leaves.append({"parts": group, "center": center, "decals": []})
        for decal in decals:
            var decal_center: Vector3 = decal["center"]
            var best_distance := 0.35
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

func _scan(root: Node, panels: Array[Dictionary], decals: Array[Dictionary]) -> void:
    if root is MeshInstance3D and root.mesh != null:
        var bounds: AABB = root.get_aabb()
        var scale_size: Vector3 = bounds.size * root.scale.abs()
        var center: Vector3 = root.transform * bounds.get_center()
        if str(root.name).begins_with("passenger-door-caution"):
            decals.append({"node": root, "center": center, "origin": root.position})
        elif str(root.name).is_valid_int() and absf(center.x) > 1.0 and absf(center.x) < 1.4 and scale_size.y > 1.9 and scale_size.y < 2.2 and scale_size.z > 0.65 and scale_size.z < 0.72:
            panels.append({"node": root, "center": center, "origin": root.position})
    for child in root.get_children():
        _scan(child, panels, decals)

func _process(delta: float) -> void:
    if not validated:
        return
    var goal := 1.0 if target_open else 0.0
    openness = move_toward(openness, goal, delta / ANIMATION_SECONDS)
    for leaf in leaves:
        var direction: float = leaf["direction"]
        var shift := Vector3(0, 0, direction * SLIDE_METERS * openness)
        for item in leaf["parts"]:
            var node: Node3D = item["node"]
            node.position = item["origin"] + shift
        for item in leaf["decals"]:
            var node: Node3D = item["node"]
            node.position = item["origin"] + shift

func request_open(speed_mps: float) -> void:
    if speed_mps > 0.05 or not validated:
        return
    target_open = true

func request_close() -> void:
    target_open = false

func can_move() -> bool:
    return not target_open and openness <= 0.001 and validated
