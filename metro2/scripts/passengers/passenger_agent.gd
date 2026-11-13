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
var navigation: RefCounted
var aisle:=Rect2()
var detour: Array[Vector3]=[]
var blocked_for:=0.0
var replan_delay:=0.0
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
    detour.clear()
    blocked_for=0.0
    path = points
    state = next_state
    animation.play("Walk")

func step(dt: float,agents: Array) -> bool:
    replan_delay=maxf(0,replan_delay-dt)
    if path.is_empty():return true
    var goal: Vector3=detour[0] if not detour.is_empty() else path[0]
    var offset:=goal-position
    var amount:=minf(offset.length(),walk_speed*dt)
    var desired:=position+offset.normalized()*amount
    var blocker: Node3D
    var frame:=get_parent() as Node3D
    var inverse:=frame.global_transform.affine_inverse()
    for other in agents:
        if other==self:continue
        var other_point: Vector3=inverse*other.global_position
        var center:=Vector2(other_point.x,other_point.z)
        var start:=Vector2(position.x,position.z)
        var finish:=Vector2(desired.x,desired.z)
        var clearance: float=radius+other.radius+0.025
        # Swept separation protects bodies even at a low animation rate.
        if start.distance_to(center)<clearance and (finish-start).dot(start-center)>0:continue
        if navigation.distance_to_segment(center,start,finish)<clearance:
            blocker=other;break
    if is_instance_valid(blocker):
        blocked_for+=dt
        animation.play("Idle")
        var may_detour: bool=space=="platform" and path[0].x<=navigation.platform.end.x
        if space=="train":
            may_detour=aisle.has_point(Vector2(position.x,position.z)) and aisle.has_point(Vector2(path[0].x,path[0].z))
        if may_detour and blocked_for>0.30 and replan_delay<=0:
            # A stable ID priority lets one head-on walker pass a waiting peer.
            var yield_time:=1.1 if not blocker.path.is_empty() and blocker.id<id else 0.30
            if blocked_for>=yield_time:
                var people: Array=[]
                for other in agents:
                    if other==self:continue
                    var other_point: Vector3=inverse*other.global_position
                    people.append({"position":other_point,"clearance":radius+other.radius+0.07})
                var region: Rect2=navigation.platform if space=="platform" else aisle
                var replacement: Array[Vector3]=navigation.route(position,path[0],people,region,space=="platform")
                if not replacement.is_empty():detour=replacement
                replan_delay=0.7+float(id%3)*0.12
        return false
    blocked_for=0.0
    animation.play("Walk")
    position=desired
    if Vector2(offset.x,offset.z).length()>0.01:
        rotation.y=lerp_angle(rotation.y,atan2(offset.x,offset.z),minf(1,dt*7))
    if position.distance_to(goal)<0.015:
        position=goal
        if not detour.is_empty():detour.pop_front()
        if detour.is_empty() and position.distance_to(path[0])<0.02:path.pop_front()
    return path.is_empty()

func idle(dt: float, speed: float, acceleration: float) -> void:
    clock += dt
    animation.balance(dt,clock,speed,acceleration,state=="seated",space=="train" and path.is_empty())
    if state == "waiting" or state == "queued":
        animation.play("Talk" if group_id>=0 and int(clock+id)%12<3 else "Idle")
