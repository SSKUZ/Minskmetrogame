extends RefCounted
## PassengerAnimator / PassengerBalance: original named clips, blended transitions.
var player: AnimationPlayer
var visual: Node3D
var current := ""
var forward := 0.0
var lateral := 0.0
var vf := 0.0
var vl := 0.0
var phase := 0.0
var _missing := false
var _pace := 1.0

func setup(model: Node3D, id: int) -> void:
    visual = model
    phase = id * 0.731
    _pace=0.94+float(id%5)*0.025
    for node in model.find_children("*", "AnimationPlayer", true, false):
        player = node
        break

func play(clip: String, loop: bool = true) -> void:
    if player==null: _missing=true;return
    if current==clip and not _missing: return
    _missing=true
    for name in player.get_animation_list():
        if str(name).get_slice("/", str(name).get_slice_count("/")-1) == clip:
            var animation := player.get_animation(name)
            animation.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
            _missing=false
            player.speed_scale = _pace
            player.play(name, 0.45)
            if clip in ["Idle","Sit idle (chair)"]:
                # Original idle clips stay alive; each passenger starts at a
                # different phase. Agent pelvis compensation retains the seat.
                player.seek(fposmod(phase,maxf(animation.length,0.01)),true)
            current = clip
            return

func finished() -> bool:
    return _missing or player == null or not player.is_playing()

func balance(dt: float, _time: float, _speed: float, acceleration: float, seated: bool, riding: bool) -> void:
    # Respond to actual acceleration only. Periodic sway made seated riders
    # rock constantly even at a steady speed; the original idle clips remain.
    var target_forward := 0.0
    if riding and not seated:
        target_forward = clampf(acceleration, -1.2, 1.2) * 0.009
    var blend_step := clampf(dt * 3.0, 0.0, 1.0)
    forward = lerpf(forward, target_forward, blend_step)
    lateral = lerpf(lateral, 0.0, blend_step)
    visual.rotation.x = clampf(forward, -0.012, 0.012)
    visual.rotation.z = clampf(lateral, -0.012, 0.012)
