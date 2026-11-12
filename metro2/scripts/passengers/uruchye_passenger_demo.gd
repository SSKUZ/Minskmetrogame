extends Node3D
const Train=preload("res://scripts/passengers/passenger_demo_train.gd")
const Passengers=preload("res://modules/passengers/passengers.tscn")
const Station=preload("res://modules/stations/uruchye/uruchye.tscn")
const Camera=preload("res://viewers/inspection_camera.gd")
const Joystick=preload("res://viewers/flight_joystick.gd")
@export var passenger_count := 18
var train: Node3D
var passengers: Node3D
var camera: Node3D
var phase := "waiting"
var time := 0.0
var stop_z := 0.0
var start_z := 0.0
var end_z := 0.0
var previous_z := 0.0
var previous_speed := 0.0
var label: Label
var alight_button: Button
var want_exit := false

func _ready() -> void:
    var station=Station.instantiate()
    # Only short entry/exit track extensions. Station architecture stays intact.
    station.track_min_z=-110.0;station.track_max_z=184.0
    add_child(station)
    var world:=WorldEnvironment.new()
    var environment:=Environment.new()
    environment.background_mode=Environment.BG_COLOR
    environment.background_color=Color("#111720")
    environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color=Color("#dce7f0")
    environment.ambient_light_energy=0.8
    world.environment=environment;add_child(world)
    var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-65,-20,0)
    light.light_energy=0.6;light.shadow_enabled=false;add_child(light)
    train=Train.new();add_child(train)
    # Fit the whole four-car body within the actual 105 m platform.
    stop_z=39.612-(train.front+train.back)*0.5
    start_z=stop_z+92.0
    end_z=stop_z-110.0
    train.move_to(start_z);previous_z=start_z
    passengers=Passengers.instantiate();passengers.passenger_count=passenger_count;add_child(passengers)
    var footprints: Array[Rect2]=[]
    for i in range(19):
        var z: float=-1.0+i*4.5
        if absf(z-17)<3 or absf(z-39.5)<3 or absf(z-62)<3 or z>74:continue
        footprints.append(Rect2(-5.90,z-0.53,1.06,1.06))
    for z in [17.0,39.5,62.0]: footprints.append(Rect2(-6.65,z-2.8,2.56,5.6))
    passengers.configure(train.train,train.door_system,stop_z-start_z,footprints)
    camera=Camera.new();add_child(camera)
    camera.frame_point(Vector3(-0.8,2.4,30),12.0)
    camera.camera.global_position=Vector3(-3.1,2.9,17)
    camera.yaw=-2.7;camera.pitch=0.05;camera._apply(false)
    make_ui()

func make_ui() -> void:
    var layer:=CanvasLayer.new();add_child(layer)
    label=Label.new();label.position=Vector2(12,10)
    label.add_theme_font_size_override("font_size",18);layer.add_child(label)
    var row:=HBoxContainer.new();row.position=Vector2(12,40);layer.add_child(row)
    var repeat:=Button.new();repeat.text="Повторить";row.add_child(repeat)
    repeat.pressed.connect(func():get_tree().reload_current_scene())
    alight_button=Button.new();alight_button.text="Высадить пассажиров";alight_button.disabled=true
    row.add_child(alight_button)
    alight_button.pressed.connect(func():want_exit=true;alight_button.disabled=true)
    var pad=Joystick.new();pad.size=Vector2(132,132)
    pad.set_anchors_preset(Control.PRESET_BOTTOM_LEFT);pad.position=Vector2(12,get_viewport().get_visible_rect().size.y-148)
    layer.add_child(pad)
    get_viewport().size_changed.connect(func():pad.position.y=get_viewport().get_visible_rect().size.y-148)
    pad.axis_changed.connect(func(axis):camera.move_axis=Vector3(axis.x,0,axis.y))
    var vertical:=VBoxContainer.new();vertical.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
    vertical.position=Vector2(get_viewport().get_visible_rect().size.x-65,get_viewport().get_visible_rect().size.y-145)
    layer.add_child(vertical)
    get_viewport().size_changed.connect(func():vertical.position=Vector2(get_viewport().get_visible_rect().size.x-65,get_viewport().get_visible_rect().size.y-145))
    for record in [["↑",Vector3.UP],["↓",Vector3.DOWN]]:
        var button:=Button.new();button.text=record[0];button.custom_minimum_size=Vector2(52,52)
        vertical.add_child(button)
        var axis: Vector3=record[1]
        button.button_down.connect(func():camera.hold_motion(axis,true))
        button.button_up.connect(func():camera.hold_motion(axis,false))

func transition(next: String) -> void:
    phase=next;time=0

func _physics_process(delta: float) -> void:
    var dt:=minf(delta,0.1)
    time+=dt
    var doors: Node=train.door_system
    var z: float=train.train.position.z
    match phase:
        "waiting":
            if time>4:transition("arrival")
        "arrival":
            var u:=clampf(time/18.0,0,1)
            z=lerpf(start_z,stop_z,u*u*(3-2*u))
            if u>=1:transition("opening")
        "opening":
            doors.request_side(-1,0.0)
            if doors.openness>0.98:passengers.exchange_enabled=true;transition("boarding")
        "boarding":
            if passengers.complete():alight_button.disabled=false;transition("dwell")
        "dwell":
            if want_exit:
                passengers.request_alight();transition("alighting")
            elif time>9:transition("closing")
        "alighting":
            if passengers.complete():transition("closing")
        "closing":
            passengers.exchange_enabled=false
            doors.request_close()
            if doors.can_move():transition("departure")
        "departure":
            var u:=clampf(time/20,0,1)
            z=lerpf(stop_z,end_z,u*u)
            if u>=1:transition("complete")
    train.move_to(z)
    var speed:=absf(z-previous_z)/maxf(dt,0.001)
    passengers.speed=speed
    passengers.acceleration=clampf((speed-previous_speed)/maxf(dt,0.001),-3.2,2.2)
    previous_z=z;previous_speed=speed
    var names: Dictionary={"waiting":"Ожидание поезда","arrival":"Прибытие V106","opening":"Открытие дверей","boarding":"Посадка","dwell":"Посадка завершена · отправление через несколько секунд","alighting":"Высадка","closing":"Закрытие дверей","departure":"Отправление","complete":"Демонстрация завершена"}
    label.text="УРУЧЬЕ · %d пассажиров · %s"%[passenger_count,names.get(phase,phase)]
