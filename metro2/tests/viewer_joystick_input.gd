extends SceneTree
const Rig = preload("res://viewers/inspection_camera.gd")
const Stick = preload("res://viewers/flight_joystick.gd")
var failures: Array[String] = []
func _initialize() -> void:
    call_deferred("_run")
func check(value: bool, label: String) -> void:
    if not value: failures.append(label)
func touch(index: int, point: Vector2, pressed: bool) -> void:
    var event := InputEventScreenTouch.new()
    event.index=index; event.position=point; event.pressed=pressed
    Input.parse_input_event(event)
func drag(index: int, point: Vector2, delta: Vector2) -> void:
    var event := InputEventScreenDrag.new()
    event.index=index; event.position=point; event.relative=delta
    Input.parse_input_event(event)
func _run() -> void:
    root.size=Vector2i(480,1000)
    var rig := Rig.new()
    root.add_child(rig)
    var stick := Stick.new()
    stick.position=Vector2(20,800)
    stick.size=Vector2(160,160)
    root.add_child(stick)
    stick.axis_changed.connect(func(axis: Vector2): rig.move_axis=Vector3(axis.x,0,axis.y))
    rig.frame_point(Vector3.ZERO,10)
    rig.set_process(false)
    for i in range(2): await process_frame
    touch(0,Vector2(100,880),true)
    drag(0,Vector2(100,824),Vector2(0,-56))
    await process_frame
    check(stick.axis.y < -0.9,"joystick forward axis")
    check(rig.get("_touches").is_empty(),"joystick finger excluded from camera gestures")
    var before: Vector3=rig.camera.global_position
    var ahead: Vector3=-rig.camera.global_basis.z
    rig._process(0.05)
    var motion: Vector3=rig.camera.global_position-before
    check(motion.normalized().dot(ahead)>0.999,"forward follows camera pitch and yaw")
    touch(1,Vector2(350,500),true)
    var yaw_before: float=rig.yaw
    drag(1,Vector2(380,510),Vector2(30,10))
    await process_frame
    check(not is_equal_approx(rig.yaw,yaw_before),"look while holding joystick")
    check(stick.axis.y < -0.9,"look finger does not change joystick")
    touch(0,Vector2(100,824),false)
    await process_frame
    check(rig.move_axis.is_zero_approx(),"release stops movement")
    # The remaining look finger joins a second look finger for pinch zoom.
    touch(2,Vector2(440,510),true)
    before=rig.camera.global_position
    yaw_before=rig.yaw
    drag(2,Vector2(470,510),Vector2(30,0))
    await process_frame
    check(not rig.camera.global_position.is_equal_approx(before),"pinch moves along sight line")
    check(is_equal_approx(rig.yaw,yaw_before),"pinch does not rotate camera")
    touch(1,Vector2(380,510),false)
    touch(2,Vector2(470,510),false)
    touch(3,Vector2(100,880),true)
    drag(3,Vector2(120,880),Vector2(20,0))
    await process_frame
    check(stick.axis.length() > 0.1 and stick.axis.length() < 0.5,"analog deflection yields partial speed")
    stick.reset()
    check(rig.move_axis.is_zero_approx(),"focus/resize reset stops joystick")
    rig.clear_gestures()
    stick.queue_free();rig.queue_free()
    for i in range(2): await process_frame
    print("JOYSTICK_", "PASS" if failures.is_empty() else "FAIL",failures)
    quit(0 if failures.is_empty() else 1)
