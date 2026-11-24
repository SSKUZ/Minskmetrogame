extends Node
## Three reusable non-spatial players: cab controls, doors and one quiet footstep.
var bank: MetroAudioResources
var master_volume: float=1.0
var listener_mode: String="cab"
var train_distance_gain: float=1.0
var _events: Dictionary={}
var _players: Dictionary={}
var _last: Dictionary={}
var _foot_positions: Dictionary={}
var _foot_tick: float=0.0

func _ready() -> void:
    for channel in ["cab","doors","footsteps"]:
        var player: AudioStreamPlayer=AudioStreamPlayer.new()
        player.name="Effect_"+channel
        player.max_polyphony=1
        player.playback_type=AudioServer.PLAYBACK_TYPE_SAMPLE if OS.has_feature("web") else AudioServer.PLAYBACK_TYPE_STREAM
        add_child(player)
        _players[channel]=player

func configure(events: Dictionary) -> void:
    _events=events.duplicate()

func play_event(event: String) -> void:
    var id: String=str(_events.get(event,""))
    if bank==null or id.is_empty(): return
    var channel: String="doors" if event.begins_with("door.") else "footsteps" if event=="passenger.footstep" else "cab"
    if channel=="cab" and listener_mode=="platform": return
    var now: int=Time.get_ticks_msec()
    var cooldown: int=400 if channel=="footsteps" else 160 if channel=="doors" else 55
    if now-int(_last.get(channel,-1000))<cooldown: return
    var stream: AudioStream=bank.stream_for(id)
    if stream==null: return
    _last[channel]=now
    var player: AudioStreamPlayer=_players[channel]
    player.stream=stream
    player.set_meta("gain_db",float(bank.event_data(id).get("gain_db",-18.0)))
    _apply_gain(channel,player)
    player.play()

func refresh_gains() -> void:
    for channel in _players: _apply_gain(str(channel),_players[channel])

func _apply_gain(channel: String, player: AudioStreamPlayer) -> void:
    var perspective: float=-14.0 if channel=="cab" and listener_mode=="salon" else 0.0
    var distance: float=train_distance_gain if channel=="doors" and listener_mode=="platform" else 1.0
    player.volume_db=float(player.get_meta("gain_db",-18.0))+perspective+linear_to_db(maxf(0.00001,master_volume*distance))

func observe_passengers(delta: float, manager: Node, camera: Camera3D) -> void:
    _foot_tick+=delta
    if _foot_tick<0.45: return
    _foot_tick=0.0
    if not is_instance_valid(manager) or camera==null:
        _foot_positions.clear()
        return
    var agents: Array=manager.get("agents")
    var next_positions: Dictionary={}
    var audible: bool=false
    var sampled: int=0
    for agent in agents:
        if not is_instance_valid(agent) or not agent is Node3D: continue
        if (agent as Node3D).global_position.distance_squared_to(camera.global_position)>49.0: continue
        var state: String=str(agent.get("state"))
        if state in ["seated","riding","standingUp","sittingDown","queued","waitingNextTrain"]: continue
        var id: int=agent.get_instance_id()
        var position: Vector3=(agent as Node3D).global_position
        next_positions[id]=position
        if _foot_positions.has(id):
            var previous: Vector3=_foot_positions[id]
            var travel: float=Vector2(position.x-previous.x,position.z-previous.z).length()
            if travel>0.05 and travel<1.8: audible=true
        sampled+=1
        if sampled>=16: break
    _foot_positions=next_positions
    if audible: play_event("passenger.footstep")

func stop_all() -> void:
    for player in _players.values():
        (player as AudioStreamPlayer).stop()
        (player as AudioStreamPlayer).stream=null
    _foot_positions.clear()
