extends SceneTree
## Inspect imported car geometry, never edit original GLBs.
const CAR_PATHS := [
    "res://assets/v106_lod1/v106_car01_lod1_mesh289_normals_fixed.glb",
    "res://assets/v106_original/car02/v106_car_02.glb",
    "res://assets/v106_original/car03/v106_car_03.glb",
    "res://assets/v106_original/car04/v106_car_04.glb"
]

func _initialize() -> void:
    call_deferred("_inspect")

func _inspect() -> void:
    for i in range(CAR_PATHS.size()):
        var scene: PackedScene = load(CAR_PATHS[i]) as PackedScene
        if scene == null:
            push_error("BLOCK_B_CAR_AUDIT: missing imported scene %d" % (i + 1))
            quit(1)
            return
        var car: Node3D = scene.instantiate() as Node3D
        if car == null:
            push_error("BLOCK_B_CAR_AUDIT: invalid root %d" % (i + 1))
            quit(1)
            return
        root.add_child(car)
        var bounds := AABB()
        var found := [false]
        _visit(car, car, bounds, found)
        # Bounds are logged for calibration, not treated as safe pivot coordinates.
        print("BLOCK_B_CAR_%02d: meshes=%d" % [i + 1, _mesh_count(car)])
        car.queue_free()
    print("BLOCK_B_CAR_AUDIT_PASS: all four original imports inspected")
    quit(0)

func _mesh_count(node: Node) -> int:
    var count := 1 if node is MeshInstance3D else 0
    for child in node.get_children():
        count += _mesh_count(child)
    return count

func _visit(node: Node, car: Node3D, bounds: AABB, found: Array) -> void:
    if node is MeshInstance3D and node.mesh != null:
        var mesh: MeshInstance3D = node as MeshInstance3D
        var local_bounds: AABB = mesh.get_aabb()
        var to_car: Transform3D = car.global_transform.affine_inverse() * mesh.global_transform
        var center: Vector3 = to_car * local_bounds.get_center()
        if not found[0]:
            print("  first mesh centre in car coordinates: ", center)
            found[0] = true
    for child in node.get_children():
        _visit(child, car, bounds, found)
