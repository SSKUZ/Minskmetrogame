extends Node3D
const Catalog = preload("res://modules/core/module_catalog.gd")
const PathData = preload("res://modules/line/line_path.gd")
const LineTrain = preload("res://modules/line/line_train.gd")
const LineTunnel = preload("res://modules/line/line_tunnel.gd")
const Passengers = preload("res://modules/line/line_passengers.gd")
const Streamer = preload("res://modules/line/station_streamer.gd")
const LAYOUT := "res://modules/line/route_layout.json"
const INFO_ROUTE := "res://audio/data/route_stations.json"
var pack_loader: Node
var streamer: Streamer
var station_sound_origin: Marker3D
var _stream_status: Label
var path = PathData.new()
var train: Node3D
var passengers: Node3D
var stations: Array[Dictionary] = []
var ready_for_service := false
var layout: Dictionary
var tunnels: Array[Node3D]=[]
var _sun: DirectionalLight3D
var _environment: Environment

func _ready() -> void:
    layout=JSON.parse_string(FileAccess.get_file_as_string(LAYOUT))
    var info: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(INFO_ROUTE))
    _world()
    var depot := Catalog.create_module("depot")
    depot.name="OperatingDepot"
    add_child(depot)
    if not path.configure_route(layout,info): return
    stations=path.stations
    station_sound_origin=Marker3D.new()
    station_sound_origin.name="PersistentStationAudioOrigin"
    add_child(station_sound_origin)
    var layer := CanvasLayer.new()
    add_child(layer)
    _stream_status=Label.new()
    _stream_status.position=Vector2(16,265)
    layer.add_child(_stream_status)
    streamer=Streamer.new()
    streamer.name="StationStreamingService"
    streamer.station_loaded.connect(_station_loaded)
    streamer.station_unloading.connect(_station_unloading)
    streamer.loading_changed.connect(func(message: String): _stream_status.text=message)
    add_child(streamer)
    streamer.configure(self,pack_loader)
    train=LineTrain.new()
    train.name="OperatingV106Consist"
    train.line=self
    train.consist_ready.connect(_consist_ready)
    add_child(train)
    var tunnel_index: Dictionary={}
    if FileAccess.file_exists(LineTunnel.INDEX):
        tunnel_index=JSON.parse_string(FileAccess.get_file_as_string(LineTunnel.INDEX))
    var base_cache: Dictionary={"data":{},"order":[]}
    for track_x in [0.992,-11.732]:
        var tunnel := LineTunnel.new()
        tunnel.path=path
        tunnel.line=self
        tunnel.base_spans=tunnel_index.get("base",{})
        tunnel.base_part_kinds=tunnel_index.get("base_part_kinds",[])
        tunnel.base_cache=base_cache
        tunnel.base_prepared.connect(_start_service_if_ready)
        tunnel.prepared_spans=tunnel_index.get("spans",{})
        tunnel.center_x=float(track_x)
        add_child(tunnel)
        tunnels.append(tunnel)
        tunnel.configure(train.train,train._train_bounds,train.camera)
        if float(track_x)>0.0: train.bind_tunnel(tunnel)

func station_instance(index: int) -> Node3D:
    return streamer.station(index) if is_instance_valid(streamer) else null

func _station_loaded(index: int, station: Node3D) -> void:
    for tunnel in tunnels: tunnel.station_track_changed(index,true)
    if is_instance_valid(passengers): await passengers.add_platform(stations[index],station)
    _start_service_if_ready()

func _station_unloading(index: int, station: Node3D) -> void:
    for tunnel in tunnels: tunnel.station_track_changed(index,false)
    if is_instance_valid(passengers): passengers.remove_platform(index)
    if is_instance_valid(train): train.release_station(station)

func _start_service_if_ready() -> void:
    if ready_for_service or not is_instance_valid(passengers) or not streamer.is_loaded(0): return
    if not passengers.platform_ready(0) or tunnels.size()!=2: return
    for tunnel in tunnels:
        if not tunnel.base_ready: return
    ready_for_service=true
    train.service_ready=true
    train.camera.make_current()

func _consist_ready() -> void:
    # consist_ready is emitted before the inherited train attaches its INFO binding.
    await get_tree().process_frame
    passengers=Passengers.new()
    passengers.name="WholeLinePassengerService"
    add_child(passengers)
    passengers.initialize_line(self,train)
    for index in streamer.instances:
        await passengers.add_platform(stations[int(index)],streamer.station(int(index)))
    _start_service_if_ready()

func _process(_delta: float) -> void:
    if not is_instance_valid(train): return
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
