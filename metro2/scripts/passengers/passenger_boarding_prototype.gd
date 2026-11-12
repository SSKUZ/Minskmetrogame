extends Node3D
## Isolated Godot 4.3 boarding prototype. Assign original imported passenger GLB
## as passenger_scene and configure physical Marker3D paths in the inspector.
## Does not modify V106, station geometry, or door animation.
signal boarding_finished(boarded: int)
@export_range(1, 20) var passenger_count := 18
@export var passenger_scene: PackedScene
@export var waiting_markers: Array[NodePath] = []
@export var doorway_markers: Array[NodePath] = []
@export var interior_markers: Array[NodePath] = []
@export_range(0.2, 3.0) var walking_speed := 1.15
var _agents: Array[Node3D] = []
var _boarding := false

func _ready() -> void:
    if passenger_scene == null:
        push_warning("Passenger prototype: assign an imported passenger GLB scene first.")
        return
    if waiting_markers.is_empty() or doorway_markers.is_empty() or interior_markers.is_empty():
        push_warning("Passenger prototype: waiting, doorway and interior anchors are required.")
        return
    for i in range(passenger_count):
        var instance := passenger_scene.instantiate() as Node3D
        if instance == null:
            push_error("Passenger scene root must inherit Node3D")
            return
        add_child(instance)
        var marker := get_node_or_null(waiting_markers[i % waiting_markers.size()]) as Marker3D
        if marker == null:
            push_error("Missing waiting marker")
            return
        instance.global_position = marker.global_position
        _agents.append(instance)
        _play_animation(instance, "Idle")

func begin_boarding(doors_open: bool) -> void:
    if _boarding or not doors_open or _agents.is_empty():
        return
    _boarding = true
    var boarded := 0
    for i in range(_agents.size()):
        if not is_inside_tree(): break
        var agent := _agents[i]
        if not is_instance_valid(agent): continue
        var doorway := get_node_or_null(doorway_markers[i % doorway_markers.size()]) as Marker3D
        var inside := get_node_or_null(interior_markers[i % interior_markers.size()]) as Marker3D
        if doorway == null or inside == null:
            push_error("Boarding anchor missing; aborting")
            break
        _play_animation(agent, "Walk")
        await _walk_to(agent, doorway.global_position)
        await _walk_to(agent, inside.global_position)
        _play_animation(agent, "Idle")
        boarded += 1
    _boarding = false
    boarding_finished.emit(boarded)

func _walk_to(agent: Node3D, destination: Vector3) -> void:
    while is_inside_tree() and is_instance_valid(agent) and agent.global_position.distance_to(destination) > 0.08:
        var delta := get_process_delta_time()
        var direction := destination - agent.global_position
        if direction.length_squared() > 0.0001:
            agent.global_position = agent.global_position.move_toward(destination, walking_speed * delta)
            agent.look_at(agent.global_position + Vector3(direction.x, 0.0, direction.z), Vector3.UP)
        await get_tree().process_frame

func _play_animation(agent: Node3D, name: String) -> void:
    var players := agent.find_children("*", "AnimationPlayer", true, false)
    if players.is_empty(): return
    var player := players[0] as AnimationPlayer
    for animation_name in player.get_animation_list():
        if animation_name.to_lower() == name.to_lower():
            player.play(animation_name)
            return
