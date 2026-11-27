extends Node3D
## Standalone phone showcase: reuses the actual passenger-phone UI without
## loading a train, station, cab, passenger NPCs or game startup.
const Phone = preload("res://modules/gameplay/passenger_phone.gd")

class PreviewPlayer extends Node3D:
    var active := true
    var stick := Vector2.ZERO
    var velocity := Vector3.ZERO
    var aboard: Node3D
    var eye: Node3D

class PreviewTrain extends Node3D:
    var speed := 11.5
    var camera_mode := "walk"

class PreviewService extends Node:
    var running := true
    var role := "passenger"
    var player: PreviewPlayer
    var train: PreviewTrain
    var ui: Node
    var line: Node
    var start_station := 0

var phone: Control

func _ready() -> void:
    name="PassengerPhoneViewer"
    var camera:=Camera3D.new()
    camera.current=true
    camera.fov=65.0
    add_child(camera)
    var background:=WorldEnvironment.new()
    var env:=Environment.new()
    env.background_mode=Environment.BG_COLOR
    env.background_color=Color("#28333f")
    background.environment=env
    add_child(background)
    var service:=PreviewService.new()
    add_child(service)
    var player:=PreviewPlayer.new()
    service.player=player
    add_child(player)
    player.eye=Node3D.new()
    player.add_child(player.eye)
    service.train=PreviewTrain.new()
    add_child(service.train)
    service.line=Node.new()
    add_child(service.line)
    service.ui=Node.new()
    add_child(service.ui)
    service.ui.set("camera_touch_id",-1)
    # The preview needs the same lightweight touch-control surface as gameplay.
    var stick:=Control.new()
    stick.set_script(preload("res://viewers/flight_joystick.gd"))
    service.ui.add_child(stick)
    service.ui.set_meta("preview_stick",stick)
    var controls:=CanvasLayer.new()
    add_child(controls)
    var root:=Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter=Control.MOUSE_FILTER_IGNORE
    controls.add_child(root)
    phone=Phone.new()
    phone.initialize(service,root)
    # Standalone preview opens the actual phone immediately.
    phone.open_phone()
