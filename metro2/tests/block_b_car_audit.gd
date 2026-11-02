extends SceneTree
## Read-only bounds audit for imported car GLBs; prints local geometry centres.
const CAR_PATHS := [
    "res://assets/v106_lod1/v106_car01_lod1_mesh289_normals_fixed.glb",
    "res://assets/v106_original/car02/v106_car_02.glb",
    "res://assets/v106_original/car03/v106_car_03.glb",
    "res://assets/v106_original/car04/v106_car_04.glb"
]

func _initialize() -> void:
    call_deferred("_inspect")

func _inspect() -> void:
    var centers: Array[Vector3] = []
    var lengths: Array[float] = []
    for i in range(CAR_PATHS.size()):
        var scene := load(CAR_PATHS[i]) as PackedScene
        if scene == null:
            _fail("missing imported scene %d" % (i + 1))
            return
        var car := scene.instantiate() as Node3D
        if car == null:
            _fail("invalid root %d" % (i + 1))
            return
        root.add_child(car)
        var stats := {"min": Vector3(INF, INF, INF), "max": Vector3(-INF, -INF, -INF), "meshes": 0}
        _visit(car, car, stats)
        if int(stats["meshes"]) == 0:
            _fail("no mesh geometry in car %d" % (i + 1))
            return
        var min_corner: Vector3 = stats["min"]
        var max_corner: Vector3 = stats["max"]
        var center: Vector3 = (min_corner + max_corner) * 0.5
        var dimensions: Vector3 = max_corner - min_corner
        var scene_offset_z: float = [0.0, 0.38151, 0.41951, 0.45751][i]
        centers.append(center + Vector3(0.0, 0.0, scene_offset_z))
        lengths.append(dimensions.z)
        print("BLOCK_B_CAR_%02d meshes=%d center=%s size=%s min=%s max=%s" % [
            i + 1, stats["meshes"], center, dimensions, min_corner, max_corner])
        car.free()
    for i in range(1, centers.size()):
        var spacing: float = absf(centers[i].z - centers[i - 1].z)
        var gap: float = spacing - (lengths[i] + lengths[i - 1]) * 0.5
        print("BLOCK_B_PAIR_%02d_%02d centre_spacing=%.4f end_gap=%.4f" % [i, i + 1, spacing, gap])
        if spacing < 1.0 or spacing > 30.0:
            _fail("implausible car spacing; do not enable per-car motion")
            return
    print("BLOCK_B_CAR_AUDIT_PASS")
    quit(0)

func _visit(node: Node, car: Node3D, stats: Dictionary) -> void:
    if node is MeshInstance3D:
        var mesh := node as MeshInstance3D
        if mesh.mesh != null:
            stats["meshes"] = int(stats["meshes"]) + 1
            var box := mesh.get_aabb()
            var to_car := car.global_transform.affine_inverse() * mesh.global_transform
            for xi in range(2):
                for yi in range(2):
                    for zi in range(2):
                        var corner := box.position + box.size * Vector3(float(xi), float(yi), float(zi))
                        var point := to_car * corner
                        stats["min"] = (stats["min"] as Vector3).min(point)
                        stats["max"] = (stats["max"] as Vector3).max(point)
    for child in node.get_children():
        _visit(child, car, stats)

func _fail(message: String) -> void:
    push_error("BLOCK_B_CAR_AUDIT_FAIL: " + message)
    quit(1)
