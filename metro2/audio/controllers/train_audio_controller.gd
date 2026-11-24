extends Node
class_name MetroTrainAudioController
## Shared V106 state; each car has a spatial source, not another state machine.
var router: MetroAudioEventRouter
var origin: Node3D
var origins: Array[Node3D] = []
var speed_mps: float = 0.0
var acceleration_mps2: float = 0.0
var traction_command: float = 0.0
var brake_command: float = 0.0
var powered: bool = false
var travel_direction: int = 1
var _events: Dictionary = {}
var _profiles: Dictionary = {}
var _layers: Dictionary = {}
var _mix: Dictionary = {"traction":0.0,"rolling":0.0,"brake":0.0,"idle":0.0}
@export var response_seconds: float = 0.35

func set_state(speed: float, acceleration: float, traction: float, brake: float, power: bool, direction: int = 1) -> void:
    speed_mps=absf(speed)
    acceleration_mps2=acceleration
    traction_command=clampf(traction,0.0,1.0)
    brake_command=clampf(brake,0.0,1.0)
    powered=power
    travel_direction=direction

func configure_layers(layer_events: Dictionary, profiles: Dictionary = {}) -> void:
    stop_layers()
    # Keep the configuration even when load_catalog precedes bind_origins.
    _events=layer_events.duplicate(true)
    _profiles=profiles.duplicate(true)

func _start_layer(layer: String) -> void:
    if router==null or router.bank==null: return
    if _layers.has(layer):
        for existing in _layers[layer]:
            if is_instance_valid(existing): existing.stream_paused=false
        return
    var event_id: String=str(_events.get(layer,""))
    if event_id.is_empty() or not router.bank.has_event(event_id): return
    var sources: Array[Node3D]=origins.duplicate()
    if sources.is_empty() and is_instance_valid(origin): sources.append(origin)
    var players: Array[AudioStreamPlayer3D]=[]
    # Identical recordings from four cars need one audible nearest source.
    # Keep all physical origins; retarget without restarting the stream.
    var source: Node3D=_nearest_origin(sources)
    if is_instance_valid(source):
        var player: AudioStreamPlayer3D=router.bank.play_at(event_id,source,Vector3.ZERO,-60.0,true)
        if player!=null: players.append(player)
    if not players.is_empty(): _layers[layer]=players

func _process(delta: float) -> void:
    var moving: float=pow(clampf(speed_mps/16.0,0.0,1.0),0.55) if speed_mps>0.05 else 0.0
    var targets: Dictionary={
        "traction":traction_command*moving if powered else 0.0,
        "rolling":moving,
        "brake":maxf(brake_command,clampf(-acceleration_mps2/1.05,0.0,1.0))*moving,
        "idle":1.0-moving if powered else 0.0}
    var blend: float=1.0-exp(-minf(delta,0.1)/maxf(response_seconds,0.01))
    for layer in targets:
        _mix[layer]=lerpf(float(_mix[layer]),float(targets[layer]),blend)
        if float(_mix[layer])>0.003: _start_layer(str(layer))
        if not _layers.has(layer): continue
        if float(_mix[layer])<0.002 and float(targets[layer])==0.0:
            for sleeping in _layers[layer]:
                if is_instance_valid(sleeping): sleeping.stream_paused=true
            continue
        var profile: Dictionary=_profiles.get(layer,{})
        var ratio: float=clampf(speed_mps/22.0,0.0,1.0)
        var pitch: float=lerpf(float(profile.get("pitch_min",1.0)),float(profile.get("pitch_max",1.0)),ratio)
        var category: String="rolling" if layer=="rolling" else "traction"
        var perspective: float=float(router.perspective_gain_db[router.listener_mode].get(category,0.0))
        for player in _layers[layer]:
            if not is_instance_valid(player): continue
            var nearest: Node3D=_nearest_origin(origins)
            if is_instance_valid(nearest) and player.get_parent()!=nearest:
                player.reparent(nearest,false)
                player.position=Vector3.ZERO
            if player.pitch_scale!=pitch: player.pitch_scale=pitch
            router.bank.set_player_gain(player,linear_to_db(maxf(0.00001,float(_mix[layer])))+perspective)

func _nearest_origin(sources: Array[Node3D]) -> Node3D:
    var nearest: Node3D=origin
    var camera: Camera3D=get_viewport().get_camera_3d()
    if camera==null: return nearest
    var distance: float=INF
    for source in sources:
        if not is_instance_valid(source): continue
        var d: float=source.global_position.distance_squared_to(camera.global_position)
        if d<distance:
            distance=d
            nearest=source
    return nearest

func _stop_layer(layer: String) -> void:
    for player in _layers.get(layer,[]):
        if is_instance_valid(player):
            if is_instance_valid(router) and is_instance_valid(router.bank): router.bank.release_player(player)
            else: player.queue_free()
    _layers.erase(layer)

func stop_layers() -> void:
    for layer in _layers.keys(): _stop_layer(str(layer))

func _exit_tree() -> void:
    stop_layers()
