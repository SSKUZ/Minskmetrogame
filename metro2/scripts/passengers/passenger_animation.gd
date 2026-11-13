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

func setup(model: Node3D, id: int) -> void:
    visual = model
    phase = id * 0.731
    for node in model.find_children("*", "AnimationPlayer", true, false):
        player = node
        break

func play(clip: String, loop: bool = true) -> void:
    if player == null or current == clip: return
    for name in player.get_animation_list():
        if str(name).get_slice("/", str(name).get_slice_count("/")-1) == clip:
            var animation := player.get_animation(name)
            animation.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
            player.speed_scale = 1.0
            player.play(name, 0.45)
            if clip in ["Idle","Sit idle (chair)"]:
                # Stable pelvis; gestures are applied separately to head/arms.
                player.seek(0.45 if clip == "Sit idle (chair)" else 0.6,true)
                player.pause()
            current = clip
            return

func finished() -> bool:
    return player == null or not player.is_playing()

func balance(dt: float, time: float, speed: float, acceleration: float, seated: bool, riding: bool) -> void:
    var sensitivity := 0.04 if seated else 0.16
    var running := clampf(speed*3.6/22.0,0,1)
    var tf := sensitivity*(clampf(acceleration,-1.2,1.2)*0.023+running*(sin(time*0.89+phase)*0.004+sin(time*1.73+phase*2.17)*0.002)) if riding else 0.0
    var tl := sensitivity*running*sin(time*0.72+phase*1.61)*0.006 if riding else 0.0
    var remaining := minf(dt,0.25)
    while remaining > 0.000001:
        var h := minf(remaining,1.0/90.0)
        remaining -= h
        vf += ((tf-forward)*48-vf*12)*h
        forward += vf*h
        vl += ((tl-lateral)*48-vl*12)*h
        lateral += vl*h
    visual.rotation.x = clampf(forward,-0.018,0.018)
    visual.rotation.z = clampf(lateral,-0.018,0.018)
