extends Node3D
## A vehicle view of the SAME route and streamer; no second station loader.
var world: Node3D
var path: RefCounted
var stations: Array[Dictionary]=[]
var layout: Dictionary
var train: Node3D
var passengers: Node3D
var gameplay: Node
var streamer: Node
var tunnels: Array[Node3D]=[]
var station_sound_origin: Marker3D
var _stream_status: Label
var ready_for_service:=false

func configure(source: Node3D) -> void:
    world=source
    path=source.path
    stations=source.stations
    layout=source.layout
    streamer=source.streamer
    tunnels=source.tunnels
    _stream_status=source._stream_status
    station_sound_origin=Marker3D.new()
    add_child(station_sound_origin)

func station_instance(index: int) -> Node3D:
    return world.station_instance(index)
