extends SceneTree
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func check(value: bool, message: String) -> void:
    if not value:
        failures.append(message)
        push_error("V48_CHECK_FAILED " + message)

func _run() -> void:
    var viewer := load("res://viewers/module_viewer.tscn").instantiate() as Node3D
    root.add_child(viewer)
    check(viewer.get("active_module") == null,"menu starts without a module")
    # A static module must not cause the train factory or GLBs to load.
    await viewer.open_module("uruchye")
    check(not ResourceLoader.has_cached("res://assets/v106_original/car04/v106_car_04.glb"),"station loads without train")
    check(viewer.active_module.has_node("Track1"),"Uruchye built")
    var previous: WeakRef = weakref(viewer.active_module)
    await viewer.open_module("v106")
    check(previous.get_ref() == null,"previous station freed before train")
    check(viewer.diagnostic_state().loaded_modules == 1,"only one active module")
    var state: Dictionary = viewer.active_module.diagnostic_state()
    check(state.cars == 4 and state.cab_loaded and state.door_system_ready,"four cars cab and shared doors initialized")
    check(viewer.active_module.get("_station") == null and viewer.active_module.get("_tunnel") == null,"train has no route modules")
    check(not viewer.active_module.is_physics_processing(),"inspection never drives train")
    check(viewer.diagnostic_state().advertising == "ADVERTISING: ENABLED — V49 FIXED MOUNTS","enabled advertising diagnosis")
    check(viewer.active_module.get("train").find_children("SaloonArtworkV46","Node3D",true,false).size() == 4,"artwork attached to all four cars")
    for i in range(1,5):
        viewer.focus_car(i)
        check(viewer.selected_car == i,"focus car %d" % i)
        check(viewer.rig.camera.global_position.is_finite(),"camera finite")
    viewer.inspect_interior("salon")
    check(viewer.rig.free_mode,"saloon opens in diagnostic free mode")
    viewer.inspect_interior("cab")
    check(viewer.rig.free_mode,"cab opens in diagnostic free mode")
    viewer.reset_view()
    var before: Vector3 = viewer.rig.camera.global_position
    viewer.rig.orbit(Vector2(1500,20))
    check(viewer.rig.camera.global_position.is_equal_approx(before),"finger look rotates in place")
    check(viewer.rig.free_mode,"free flight is always active")
    var distance_before: float = viewer.rig.distance
    viewer.rig.zoom(1.2)
    check(viewer.rig.distance < distance_before,"zoom changes distance")
    # Exercise the touch path, including its release/reset logic.
    var touch := InputEventScreenTouch.new()
    touch.index = 0; touch.position = Vector2(900,400); touch.pressed = true
    viewer.rig._unhandled_input(touch)
    var drag := InputEventScreenDrag.new()
    drag.index = 0; drag.position = Vector2(930,400); drag.relative = Vector2(30,0)
    var yaw_before: float = viewer.rig.yaw
    viewer.rig._unhandled_input(drag)
    check(not is_equal_approx(yaw_before,viewer.rig.yaw),"touch orbit")
    touch.index = 1; touch.position = Vector2(1000,400)
    viewer.rig._unhandled_input(touch)
    drag.index = 1; drag.position = Vector2(1030,400)
    viewer.rig._unhandled_input(drag)
    drag.position = Vector2(1080,400)
    viewer.rig._unhandled_input(drag)
    check(viewer.rig.distance < distance_before,"two-finger pinch")
    viewer.rig.clear_gestures()
    print("V48_TRAIN_PASS ",JSON.stringify(viewer.diagnostic_state()))
    previous = weakref(viewer.active_module)
    await viewer.open_module("car2")
    check(previous.get_ref() == null,"old train subtree freed")
    check(viewer.diagnostic_state().single_car_full_consist,"single car fallback is explicit")
    var consist := viewer.active_module.get("train") as Node3D
    check(not consist.get_node("OriginalV106Car01").visible and consist.get_node("OriginalV106Car02").visible,"single-car selection visibility")
    viewer.focus_car(3)
    check(consist.get_node("OriginalV106Car03").visible and not consist.get_node("OriginalV106Car02").visible,"switch single-car focus")
    previous = weakref(viewer.active_module)
    await viewer.open_module("tunnel_16m")
    check(previous.get_ref() == null,"train subtree freed before tunnel")
    check(viewer.active_module.has_node("Section16m/ConcreteArch"),"one tunnel section opens")
    check(not ResourceLoader.has_cached("res://assets/v106_original/car04/v106_car_04.glb"),"train resources released after switch")
    await viewer.open_module("depot")
    check(viewer.active_module.has_node("FiveBayMaintenanceHall"),"depot opens")
    check(viewer.diagnostic_state().collision_proxies == 0,"free-flight viewer creates no camera barriers")
    print("V48_DEPOT_PASS ",JSON.stringify(viewer.diagnostic_state()))
    await viewer.unload_module()
    check(viewer.active_module == null,"return to empty module state")
    viewer.queue_free()
    for i in range(2): await process_frame
    print("V48_RESULT ","PASS" if failures.is_empty() else "FAIL", " failures=",failures)
    quit(0 if failures.is_empty() else 1)
