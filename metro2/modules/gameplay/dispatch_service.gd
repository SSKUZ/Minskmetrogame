extends Node
## Background authority for an existing V106 controller, doors and INFO binding.
## Foreground authority always remains the original gameplay_service.
const WalkLite=preload("res://modules/gameplay/walk_lite.gd")
var coordinator: RefCounted
var line: Node3D
var train: Node3D
var automatic: Node
var rules: Dictionary
var timetable: RefCounted
var ui: CanvasLayer
var player: CharacterBody3D
var interaction: RefCounted
var running:=false
var role:="passenger"
var virtual_wait:=false
var direct_driver:=false
var driver_seated:=false
var _geometry=WalkLite.new()

class DoorGuard extends RefCounted:
    var owner_service: Node
    func close_cab_for_departure() -> bool:
        return true # Existing authored cab transfer points have no door animation.
    func doorway_clear() -> bool:
        var actor: CharacterBody3D=owner_service.coordinator.service.player
        if not is_instance_valid(actor) or not actor.active: return true
        for door in owner_service.line.passengers.layout.doors:
            var point: Vector3=door.car.to_local(actor.global_position)
            if absf(point.x-door.marker.position.x)<0.44 and absf(point.z-door.marker.position.z)<0.92 and absf(point.y-door.marker.position.y)<0.65: return false
        return true

func configure(dispatcher: RefCounted, context: Node3D) -> void:
    coordinator=dispatcher
    line=context
    train=context.train
    rules=dispatcher.service.rules
    timetable=dispatcher
    ui=dispatcher.service.ui
    player=dispatcher.service.player
    interaction=DoorGuard.new()
    interaction.owner_service=self
    running=true

func station_at_train() -> int:
    return coordinator.station_at_vehicle(train,line.passengers)

func _physics_process(_delta: float) -> void:
    if not running or virtual_wait: return
    player=coordinator.service.player
    _geometry.update_doors(self)
