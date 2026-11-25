extends CharacterBody3D
const Geometry = preload("res://modules/gameplay/world_geometry.gd")
var service: Node
var rules: Dictionary
var stick:=Vector2.ZERO
var yaw:=0.0
var pitch:=0.0
var active:=false
var seated:=false
var aboard: Node3D
var eye: Node3D
var capsule: CollisionShape3D
var _climb: Array[Vector3]=[]
var _safe_position:=Vector3.ZERO

func initialize(owner_service: Node, settings: Dictionary) -> void:
    service=owner_service
    rules=settings
    name="GameplayCharacter"
    add_to_group("metro_player")
    collision_layer=Geometry.PLAYER
    collision_mask=Geometry.WORLD|Geometry.TRAIN|Geometry.ELECTRIC
    platform_floor_layers=0
    platform_wall_layers=0
    platform_on_leave=CharacterBody3D.PLATFORM_ON_LEAVE_DO_NOTHING
    floor_snap_length=0.24
    floor_max_angle=deg_to_rad(48.0)
    capsule=CollisionShape3D.new()
    var shape:=CapsuleShape3D.new()
    shape.radius=float(rules.radius)
    shape.height=float(rules.height)
    capsule.shape=shape
    capsule.disabled=true
    capsule.position.y=shape.height*0.5
    add_child(capsule)
    eye=Node3D.new()
    eye.name="HumanEye"
    eye.position.y=float(rules.eye_height)
    add_child(eye)
    process_priority=10

func look(relative: Vector2) -> void:
    if not active: return
    yaw-=relative.x*0.004
    pitch=clampf(pitch-relative.y*0.004,-1.30,1.30)
    _eye_pose()

func _eye_pose() -> void:
    eye.rotation=Vector3(pitch,yaw,0)

func attach_car(car: Node3D) -> void:
    if aboard==car: return
    var view: Basis=eye.global_basis
    reparent(car if is_instance_valid(car) else service.line,true)
    aboard=car
    var local_view: Basis=global_basis.inverse()*view
    yaw=local_view.get_euler().y
    pitch=local_view.get_euler().x
    velocity=Vector3.ZERO
    _eye_pose()

func spawn_at(point: Vector3) -> void:
    if is_instance_valid(aboard): attach_car(null)
    global_position=point+Vector3.UP*0.04
    _safe_position=global_position
    velocity=Vector3.ZERO
    _climb.clear()
    active=true
    capsule.set_deferred("disabled",false)

func climb_door(points: Array[Vector3]) -> void:
    if not seated and _climb.is_empty(): _climb=points

func _physics_process(delta: float) -> void:
    if not active: return
    if service.driver_seated or seated:
        velocity=Vector3.ZERO
        _eye_pose()
        return
    var previous: Vector3=global_position
    if not _climb.is_empty():
        var motion: Vector3=global_position.direction_to(_climb[0])*minf(1.1*delta,global_position.distance_to(_climb[0]))
        if move_and_collide(motion)!=null:
            _climb.clear()
        elif global_position.distance_to(_climb[0])<0.025: _climb.pop_front()
    else:
        var keyboard:=Vector2(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
        var input: Vector2=(stick+keyboard).limit_length() if service.train.camera_mode=="walk" else Vector2.ZERO
        var forward: Basis=global_basis*Basis(Vector3.UP,yaw)
        var desired: Vector3=(forward.x*input.x+forward.z*input.y)*float(rules.speed)
        velocity.x=move_toward(velocity.x,desired.x,float(rules.acceleration)*delta)
        velocity.z=move_toward(velocity.z,desired.z,float(rules.acceleration)*delta)
        velocity.y=-0.5 if is_on_floor() else velocity.y-float(rules.gravity)*delta
        if not service.walking_area_ready(global_position+Vector3(velocity.x,0,velocity.z)*delta):
            velocity.x=0.0
            velocity.z=0.0
            service.request_walk_area()
        _step(delta)
        move_and_slide()
    service.interaction.update_car_membership(previous)
    for i in range(get_slide_collision_count()):
        var object: Object=get_slide_collision(i).get_collider()
        if object!=null and object.has_meta("metro_electric"):
            service.respawn("Контактный рельс · поражение током")
            return
    var electric:=PhysicsShapeQueryParameters3D.new()
    electric.shape=capsule.shape
    electric.transform=capsule.global_transform
    electric.collision_mask=Geometry.ELECTRIC
    electric.margin=0.025
    if not get_world_3d().direct_space_state.intersect_shape(electric,1).is_empty():
        service.respawn("Контактный рельс · поражение током")
        return
    if global_position.y<service.line.path.position_at(global_position.z).y-8.0:
        service.respawn("Возвращение на безопасную платформу")
        return
    _eye_pose()

func _step(delta: float) -> void:
    if not is_on_floor(): return
    var horizontal:=Vector3(velocity.x,0,velocity.z)*delta
    if horizontal.length_squared()<0.000001 or not test_move(global_transform,horizontal): return
    var rise:=Vector3.UP*float(rules.step)
    if test_move(global_transform,rise): return
    var raised:=global_transform
    raised.origin+=rise
    if test_move(raised,horizontal): return
    var result:=PhysicsTestMotionResult3D.new()
    var parameters:=PhysicsTestMotionParameters3D.new()
    parameters.from=raised.translated(horizontal)
    parameters.motion=-rise-Vector3.UP*0.08
    if PhysicsServer3D.body_test_motion(get_rid(),parameters,result) and result.get_collision_normal().dot(Vector3.UP)>0.65:
        global_position+=rise+result.get_travel()
