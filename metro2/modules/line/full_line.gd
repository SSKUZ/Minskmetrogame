extends Node3D
const Catalog = preload("res://modules/core/module_catalog.gd")
const PathData = preload("res://modules/line/line_path.gd")
const LineTrain = preload("res://modules/line/line_train.gd")
const LineTunnel = preload("res://modules/line/line_tunnel.gd")
const Passengers = preload("res://modules/line/line_passengers.gd")
const StationConnections = preload("res://modules/line/station_connection_adapter.gd")
const LAYOUT := "res://modules/line/route_layout.json"
const INFO_ROUTE := "res://audio/data/route_stations.json"
var path = PathData.new()
var train: Node3D
var passengers: Node3D
var stations: Array[Dictionary] = []
var ready_for_service := false
var layout: Dictionary
var _sun: DirectionalLight3D
var _environment: Environment

func _ready() -> void:
    layout=JSON.parse_string(FileAccess.get_file_as_string(LAYOUT))
    var info: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(INFO_ROUTE))
    _world()
    var depot := Catalog.create_module("depot")
    depot.name="OperatingDepot"
    add_child(depot)
    var previous_exit := float(layout.first_station_root_z)
    for i in range(layout.station_module_ids.size()):
        var id: String=str(layout.station_module_ids[i])
        var station := Catalog.create_module(id)
        var entry := station.get_node("Connections/Entry") as Node3D
        var exit := station.get_node("Connections/Exit") as Node3D
        var root_z := float(layout.first_station_root_z) if i==0 else previous_exit-float(layout.tunnel_lengths_m[i-1])-entry.position.z
        station.position.z=root_z
        station.name="LineStation_"+id
        # The source contains redundant approach rails for its standalone viewer.
        # Confine those rails to the existing portal contract in this world only.
        station.set("track_min_z",exit.position.z)
        station.set("track_max_z",entry.position.z)
        add_child(station)
        var stop_z := _stop_datum(station)
        if not is_finite(stop_z):
            push_error("TZ55: missing existing STOP_Z for "+id)
            return
        var record := {"module_id":id,"info_id":str(info.station_ids[i]),"node":station,"index":i,
            "root_z":root_z,"stop_z":root_z+stop_z,"high":root_z+entry.position.z,"low":root_z+exit.position.z}
        var throat: Dictionary=StationConnections.open_connections(station)
        if not throat.is_empty():
            record.low=root_z+float(throat.low)
            record.high=root_z+float(throat.high)
            record.low_profile=throat.low_profile
            record.high_profile=throat.high_profile
        stations.append(record)
        if i>0:
            path.spans.append({"high":float(stations[i-1].low),"low":float(record.high),"bend_m":float(layout.tunnel_bends_m[i-1]),
                "high_profile":stations[i-1].get("low_profile",Vector2(3.15,7.0)),"low_profile":record.get("high_profile",Vector2(3.15,7.0))})
        previous_exit=float(record.low)
        await get_tree().process_frame
    path.stations=stations
    path.lower_z=float(stations[-1].low)-160.0
    path.spans.push_front({"high":96.0,"low":float(stations[0].high),"bend_m":0.0})
    train=LineTrain.new()
    train.name="OperatingV106Consist"
    train.line=self
    train.consist_ready.connect(_consist_ready)
    add_child(train)
    for track_x in [0.992,-11.732]:
        var tunnel := LineTunnel.new()
        tunnel.path=path
        tunnel.center_x=float(track_x)
        add_child(tunnel)
        tunnel.configure(train.train,train._train_bounds,train.camera)
        if float(track_x)>0.0: train.bind_tunnel(tunnel)

func _stop_datum(station: Node3D) -> float:
    var script: Script=station.get_script()
    while script!=null:
        var constants: Dictionary=script.get_script_constant_map()
        if constants.has("STOP_Z"): return float(constants.STOP_Z)
        script=script.get_base_script()
    return NAN

func _consist_ready() -> void:
    passengers=Passengers.new()
    passengers.name="WholeLinePassengerService"
    add_child(passengers)
    await passengers.initialize_line(self,train)
    ready_for_service=true
    train.service_ready=true
    train.camera.make_current()

func _process(_delta: float) -> void:
    if not is_instance_valid(train): return
    var z: float=train.distance
    for s in stations:
        var visible_now: bool=absf(z-float(s.stop_z))<340.0 or absf(train.camera.global_position.z-float(s.stop_z))<340.0
        s.node.visible=visible_now
        s.node.process_mode=Node.PROCESS_MODE_INHERIT if visible_now else Node.PROCESS_MODE_DISABLED
    var outside := smoothstep(75.0,170.0,train.camera.global_position.z)
    _sun.light_energy=lerpf(0.0,1.05,outside)
    _environment.ambient_light_energy=lerpf(0.12,0.65,outside)
    _environment.background_color=Color(0.006,0.008,0.012).lerp(Color(0.40,0.58,0.72),outside)

func _world() -> void:
    var world := WorldEnvironment.new()
    _environment=Environment.new()
    _environment.background_mode=Environment.BG_COLOR
    _environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
    _environment.ambient_light_color=Color(0.85,0.90,1.0)
    world.environment=_environment
    add_child(world)
    _sun=DirectionalLight3D.new()
    _sun.rotation_degrees=Vector3(-47,-38,0)
    _sun.shadow_enabled=true
    _sun.directional_shadow_max_distance=180.0
    add_child(_sun)
