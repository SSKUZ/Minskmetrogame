extends Node3D
const Animator = preload("res://scripts/passengers/passenger_animation.gd")
var id := 0
var group_id := -1
var state := "waiting"
var space := "platform"
var walk_speed := 1.1
var radius := 0.24
var door_id := -1
var car: Node3D
var slot: Dictionary = {}
var path: Array[Vector3] = []
var animation = Animator.new()
var visual: Node3D
var clock := 0.0
var destination := 1
var wants_board := true
var skeleton: Skeleton3D
var hips := -1
var pelvis_rest := Vector3.ZERO

func setup(scene: PackedScene, number: int) -> void:
    id = number
    walk_speed = 0.96 + float(number%5)*0.065
    visual = scene.instantiate()
    add_child(visual)
    animation.setup(visual,id)
    animation.play("Idle")
    process_priority=20
    for node in visual.find_children("*","Skeleton3D",true,false):
        skeleton=node
        for i in skeleton.get_bone_count():
            if str(skeleton.get_bone_name(i)).to_lower().ends_with("hips"):
                hips=i;pelvis_rest=skeleton.get_bone_global_rest(i).origin;break
        if hips>=0: break

func _process(_delta: float) -> void:
    if skeleton==null or hips<0: return
    # Original chair clips move the pelvis backward. Keep the reserved bench
    # anchor at the pelvis and fit the seat height as in PassengerAnimator.
    var pelvis: Vector3=skeleton.transform*skeleton.get_bone_global_pose(hips).origin
    visual.position.x=-pelvis.x
    visual.position.z=-pelvis.z if state in ["sittingDown","seated","standingUp"] else -(pelvis.z-pelvis_rest.z)
    if state=="seated": visual.position.y=float(slot.get("height",position.y))-position.y-pelvis.y
    elif state not in ["sittingDown","standingUp"]: visual.position.y=0

func follow(points: Array[Vector3], next_state: String) -> void:
    path = points
    state = next_state
    animation.play("Walk")

func step(dt: float, agents: Array) -> bool:
    if path.is_empty(): return true
    var goal := path[0]
    var offset := goal-position
    var amount := minf(offset.length(),walk_speed*dt)
    var desired := position + offset.normalized()*amount
    # Same-space body clearance from PassengerNavigation; active doorway lanes
    # have exclusive ownership so nobody can route around a jamb.
    for other in agents:
        if other == self or other.get_parent() != get_parent(): continue
        var separation: Vector3 = desired-other.position
        separation.y = 0
        if separation.length() < radius+other.radius and separation.dot(offset) < 0:
            return false
    position = desired
    if Vector2(offset.x,offset.z).length() > 0.01:
        rotation.y = lerp_angle(rotation.y,atan2(offset.x,offset.z),minf(1,dt*7))
    if position.distance_to(goal) < 0.015:
        position = goal
        path.pop_front()
    return path.is_empty()

func idle(dt: float, speed: float, acceleration: float) -> void:
    clock += dt
    animation.balance(dt,clock,speed,acceleration,state=="seated",space=="train" and path.is_empty())
    if state == "waiting" or state == "queued":
        animation.play("Talk" if group_id>=0 and int(clock+id)%12<3 else "Idle")
