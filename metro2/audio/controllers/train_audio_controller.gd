extends Node
class_name MetroTrainAudioController
## Four mutually exclusive states. Two permanent players serve only crossfades.
var bank: MetroAudioResources
var master_volume: float=1.0
var perspective_db: float=0.0
var distance_gain: float=1.0
var duck_gain: float=1.0
var _events: Dictionary={}
var _players: Array[AudioStreamPlayer]=[]
var _weights: Array[float]=[0.0,0.0]
var _start_weights: Array[float]=[0.0,0.0]
var _target: int=-1
var _state: String=""
var _requested: String=""
var _powered: bool=false
var _elapsed: float=0.0
var _fading: bool=false
var _braking: bool=false
@export var response_seconds: float=0.35

func _ready() -> void:
    for index in range(2):
        var player: AudioStreamPlayer=AudioStreamPlayer.new()
        player.name="TrainState%d" % index
        player.max_polyphony=1
        player.playback_type=AudioServer.PLAYBACK_TYPE_SAMPLE if OS.has_feature("web") else AudioServer.PLAYBACK_TYPE_STREAM
        add_child(player)
        _players.append(player)

func configure_states(events: Dictionary, fade_seconds: float) -> void:
    stop_layers()
    _events=events.duplicate()
    response_seconds=maxf(0.05,fade_seconds)

func set_state(speed: float, acceleration: float, traction: float, brake: float, power: bool, _direction: int=1) -> void:
    _powered=power
    var moving: bool=absf(speed)>0.15
    if not moving:
        _braking=false
        _requested="idle"
    else:
        # A small release hysteresis avoids chattering on noisy brake inputs.
        _braking=brake>0.025 or acceleration<(-0.04 if _braking else -0.10)
        _requested="braking" if _braking else "acceleration" if power and traction>0.04 else "cruise"

func _process(delta: float) -> void:
    var audible: String=_requested if _powered or _requested!="idle" else ""
    if not _fading and audible!=_state: _begin_transition(audible)
    if _fading:
        _elapsed+=delta
        var t: float=clampf(_elapsed/response_seconds,0.0,1.0)
        var blend: float=t*t*(3.0-2.0*t)
        for index in range(2):
            _weights[index]=lerpf(_start_weights[index],1.0 if index==_target else 0.0,blend)
        if t>=1.0:
            _fading=false
            for index in range(2):
                if index!=_target:
                    _players[index].stop()
                    _players[index].stream=null
    for index in range(2):
        if not _players[index].playing: continue
        var mix: float=_weights[index]*master_volume*distance_gain*duck_gain
        var id: String=str(_players[index].get_meta("event_id",""))
        _players[index].volume_db=linear_to_db(maxf(0.00001,mix))+perspective_db+float(bank.event_data(id).get("gain_db",-12.0))

func _begin_transition(state: String) -> void:
    var next: int=-1
    if not state.is_empty():
        next=0 if _target!=0 else 1
        var id: String=str(_events.get(state,""))
        var stream: AudioStream=bank.stream_for(id,true) if bank!=null else null
        if stream==null: return
        _players[next].stream=stream
        _players[next].set_meta("event_id",id)
        _players[next].volume_db=-80.0
        _players[next].play()
    _start_weights.assign(_weights)
    _target=next
    _state=state
    _elapsed=0.0
    _fading=true

func stop_layers() -> void:
    for player in _players:
        player.stop()
        player.stream=null
    _weights=[0.0,0.0]
    _start_weights=[0.0,0.0]
    _target=-1
    _state=""
    _requested=""
    _fading=false
