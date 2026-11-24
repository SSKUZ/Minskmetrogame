extends "res://scripts/infrastructure/station_infrastructure.gd"
## Rebind the prepared clock geometry; never rebuild the platform equipment.
func _ready() -> void:
    _displays.clear()
    for track in range(2):
        for end in range(2):
            var digits := get_node("Track%dPortal%dClock/MinskTimeAndDepartureInterval" % [track+1,end+1]) as MultiMeshInstance3D
            digits.multimesh=digits.multimesh.duplicate() as MultiMesh
            _displays.append(digits.multimesh)
    var saved := ConfigFile.new()
    if saved.load("user://station_departures.cfg")==OK:
        for track in range(2):
            var value := int(saved.get_value(station_id,str(track),0))
            if value<=int(Time.get_unix_time_from_system()): _last_departures[track]=value
