extends SceneTree
## Headless Block A runtime check; no screenshots or APK.
const MAIN_SCENE := "res://scenes/station_v106_first_playable.tscn"

func _initialize() -> void:
    call_deferred("_check")

func _check() -> void:
    var packed := load(MAIN_SCENE) as PackedScene
    if packed == null:
        _fail("first playable scene cannot be imported")
        return
    var root := packed.instantiate()
    if root == null:
        _fail("first playable scene cannot be instantiated")
        return
    get_root().add_child(root)
    await process_frame
    await process_frame
    var train := root.get_node_or_null("PlayerTrainPlacement") as Node3D
    var camera := root.get_node_or_null("OverviewCamera") as Camera3D
    if train == null or camera == null:
        _fail("train or camera missing")
        return
    var adapter := train.get_node_or_null("CabV106Adapter")
    if adapter == null or not adapter.get("ready_for_play"):
        _fail("original cab GLB not instantiated")
        return
    if adapter.get("original_cab") == null or (adapter.get("original_cab") as Node3D).get_parent() != adapter:
        _fail("original cab is not parented to train adapter")
        return
    if (adapter.get("original_cab") as Node3D).scale.distance_to(Vector3.ONE) > 0.001:
        _fail("cab scale must remain 1:1")
        return
    for mode in [0, 1, 2]:
        root.set("camera_mode", mode)
        root.call("_update_camera")
        if not camera.global_position.is_finite():
            _fail("camera position invalid for mode %d" % mode)
            return
        if camera.global_basis.determinant() < 0.9:
            _fail("camera basis invalid for mode %d" % mode)
            return
    root.set("camera_mode", 1)
    root.call("_update_camera")
    var eye := train.to_global(adapter.call("get_eye_position"))
    if camera.global_position.distance_to(eye) > 0.01:
        _fail("cab camera detached from train")
        return
    print("BLOCK_A_PASS: cab instantiated, scale 1:1, 3 cameras and driver eye valid")
    quit(0)

func _fail(reason: String) -> void:
    push_error("BLOCK_A_FAIL: " + reason)
    quit(1)
