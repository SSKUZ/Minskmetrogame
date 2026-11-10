extends SceneTree
const Catalog = preload("res://modules/core/module_catalog.gd")
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func check(value: bool, message: String) -> void:
    if not value:
        failures.append(message)
        push_error("V47_CHECK_FAILED " + message)

func _run() -> void:
    var train_module := Catalog.create_module("v106")
    root.add_child(train_module)
    for i in range(4): await process_frame
    var state: Dictionary = train_module.call("diagnostic_state")
    check(state.cars == 4,"independent train has four cars")
    check(state.cab_loaded and state.cab_cleanup_ready,"original cab initialized")
    check(state.door_system_ready,"shared door controller initialized")
    check(train_module.get("door_system").get("leaves").size() == 64,"64 door leaves")
    check(state.saloon_cars == 4 and state.saloon_lights == 12,"all saloon lighting retained")
    check(state.headlights == 2,"headlights retained")
    check(train_module.get("_tunnel") == null and train_module.get("_station") == null,"train creates no route")
    check(train_module.find_children("*","WorldEnvironment",true,false).is_empty(),"train creates no world environment")
    var consist: Node3D = train_module.get("train")
    var artwork := artwork_state(consist)
    var bogies := 0
    for car in consist.get_children():
        for child in car.get_children():
            if child.has_meta("bogie_visual"): bogies += 1
    check(bogies == 8,"existing detailed bogies retained")
    check(train_module.has_node("PassengerSaloonEquipment"),"passenger displays retained")
    print("V47_TRAIN_INDEPENDENT ",JSON.stringify(state))
    if not failures.is_empty():
        quit(1)
        return

    var station := Catalog.create_module("uruchye")
    root.add_child(station)
    check(station.get("uruchye_architecture") == true,"Uruchye architecture retained")
    check(station.has_node("Track1") and station.has_node("Track2"),"station builds both tracks")
    var section := Catalog.create_module("tunnel_16m")
    root.add_child(section)
    check(section.has_node("Section16m/ConcreteArch"),"section has current lining geometry")
    check(is_equal_approx(Catalog.connection(section,"Entry").origin.distance_to(Catalog.connection(section,"Exit").origin),16.0),"section length 16 m")
    station.position.z = -220.112
    Catalog.align_connection(section,"Exit",Catalog.connection(station,"Entry"))
    check(Catalog.connection(section,"Exit").origin.is_equal_approx(Catalog.connection(station,"Entry").origin),"track connections align")
    var depot := Catalog.create_module("depot")
    root.add_child(depot)
    for name in ["DepotTerritoryAndSurroundings","FiveBayMaintenanceHall","ContinuousSurfaceTracks","RetainedCuttingAndTunnelPortal"]:
        check(depot.has_node(name) and depot.get_node(name).get_child_count() > 0,"depot builds " + name)
    check(depot.find_children("*","Camera3D",true,false).is_empty(),"depot has no game camera")
    check(depot.find_children("*","CanvasLayer",true,false).is_empty(),"depot has no train controller UI")
    var tunnels := Catalog.create_module("tunnels")
    root.add_child(tunnels)
    train_module.call("bind_tunnel",tunnels)
    check(tunnels.call("active_module_count") > 0,"existing tunnel system configured by train")
    check(tunnels.call("coverage_is_valid"),"tunnel covers four cars and camera")
    check(train_module.get("door_system") == train_module.get("cab_runtime").get("doors"),"cab shares the single door controller")
    print("V47_MODULES_COMPATIBLE")
    for node in [train_module,station,section,depot,tunnels]: node.queue_free()
    for i in range(2): await process_frame
    if not failures.is_empty():
        quit(1)
        return

    # Original entry point remains runnable with exactly the original defaults.
    var original := load("res://scenes/depot/surface_depot_v40.tscn").instantiate() as Node3D
    root.add_child(original)
    for i in range(4): await process_frame
    var old_state: Dictionary = original.call("diagnostic_state")
    check(old_state.cars == 4 and old_state.cab_loaded and old_state.door_system_ready,"legacy entry point still initializes")
    check(original.get("_station") != null and original.get("_tunnel") != null,"legacy route retained")
    check(artwork == artwork_state(original.get("train")),"artwork matches legacy state without fixes")
    print("V47_ARTWORK_UNCHANGED ",JSON.stringify(artwork))
    print("V47_LEGACY ",JSON.stringify(old_state))
    original.queue_free()
    for i in range(2): await process_frame
    print("V47_RESULT ","PASS" if failures.is_empty() else "FAIL", " failures=",failures)
    quit(0 if failures.is_empty() else 1)

func artwork_state(consist: Node3D) -> Array:
    var result: Array = []
    for i in range(1,5):
        var car := consist.get_node("OriginalV106Car%02d" % i)
        var holder := car.get_node_or_null("SaloonArtworkV46")
        result.append([0,0,0] if holder == null else [holder.get_meta("advertisements",0),holder.get_meta("network_maps",0),holder.get_meta("line_diagrams",0)])
    return result
