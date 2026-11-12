extends Node3D
## Playable game entry: original cab/controller, player-operated arrival and doors.
const Train=preload("res://scripts/passengers/uruchye_playable_train.gd")
const Station=preload("res://modules/stations/uruchye/uruchye.tscn")
const Passengers=preload("res://modules/passengers/passengers.tscn")
var train: Node3D
var station: Node3D
var passengers: Node3D

func _ready() -> void:
    _boot_stage("Создание станции Уручье")
    station=Station.instantiate()
    station.track_min_z=-150.0;station.track_max_z=250.0
    add_child(station)
    await get_tree().process_frame
    _boot_stage("Подготовка четырёх вагонов V106")
    train=Train.new()
    train._station=station;train._station_stop_z=9.603
    train.consist_ready.connect(func():call_deferred("_prepare_passengers"))
    add_child(train)

func _prepare_passengers() -> void:
    _boot_stage("Подготовка пассажиров и посадки")
    await get_tree().process_frame
    passengers=Passengers.instantiate()
    passengers.passenger_count=18;passengers.boarding_count=12
    add_child(passengers)
    var footprints: Array[Rect2]=[]
    for i in range(19):
        var z: float=-1.0+i*4.5
        if absf(z-17)<3 or absf(z-39.5)<3 or absf(z-62)<3 or z>74:continue
        footprints.append(Rect2(-5.90,z-0.53,1.06,1.06))
    for z in [17.0,39.5,62.0]:footprints.append(Rect2(-6.65,z-2.8,2.56,5.6))
    passengers.configure(train.train,train.door_system,9.603-train.distance,footprints)
    train.passenger_manager=passengers
    get_viewport().disable_3d=false
    train.camera.cull_mask=(1<<20)-1
    train.camera.make_current()
    _boot_stage("ready")

func _boot_stage(message: String) -> void:
    if OS.has_feature("web"):JavaScriptBridge.eval("window.metroBootStage && window.metroBootStage("+JSON.stringify(message)+")",true)
