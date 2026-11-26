extends Node3D
## Animation only. Geometry, opening, hinge and physical leaf arrive from CI.
signal state_changed
@export var car_number:=1
@export var threshold:=Vector3.ZERO
@export var side:=-1
@export var angle:=1.65
@export var duration:=0.8
var state:="closed"
var fraction:=0.0
var open:=false
var vehicle: WeakRef

func set_open(value: bool) -> bool:
    var game: Node=vehicle.get_ref() as Node if vehicle!=null else null
    if value and is_instance_valid(game) and absf(float(game.get("speed")))>0.05: return false
    if not value and _obstructed(): return false
    if value==open: return true
    open=value
    state="opening" if open else "closing"
    state_changed.emit()
    return true

func toggle() -> bool:
    return set_open(not open)

func _obstructed() -> bool:
    var car:=get_parent() as Node3D
    for player in get_tree().get_nodes_in_group("metro_player"):
        if not player.active or player.seated: continue
        var local: Vector3=car.to_local(player.global_position)
        if absf(local.x-threshold.x)<0.48 and absf(local.z-threshold.z)<0.48 and absf(local.y-threshold.y)<0.65:
            return true
    return false

func _process(delta: float) -> void:
    var target: float=1.0 if open else 0.0
    if is_equal_approx(fraction,target): return
    if not open and _obstructed():
        open=true
        state="opening"
        state_changed.emit()
    fraction=move_toward(fraction,1.0 if open else 0.0,delta/maxf(duration,0.01))
    var eased: float=fraction*fraction*(3.0-2.0*fraction)
    $DoorPivot.rotation.y=angle*eased
    var next: String=("opened" if open else "closed") if is_equal_approx(fraction,1.0 if open else 0.0) else ("opening" if open else "closing")
    if next!=state:
        state=next
        state_changed.emit()

func interaction_record() -> Dictionary:
    return {"car":get_parent(),"native":self,"pivot":$DoorPivot,"threshold":threshold,
        "side":side,"angle":angle,"open":open,"fraction":fraction}
