extends RefCounted
class_name MetroStationPositionTracker
## Route positions are authored in metres; station IDs are never inferred from array index.
## The train position and each stop marker MUST use the same world coordinate space.
var stations: Array[Dictionary] = []
var direction: String = "forward"
var active_index: int = -1
var visit_number: int = 0
var approach_radius_m: float = 100.0
var stop_radius_m: float = 0.5
var release_radius_m: float = 125.0

func configure(markers: Array[Dictionary], travel_direction: String = "forward") -> void:
    stations.clear()
    direction = travel_direction if travel_direction == "reverse" else "forward"
    for marker in markers:
        var id: String = str(marker.get("id", ""))
        if id == "" or not marker.has("position"):
            continue
        var pos: Variant = marker["position"]
        if not pos is Vector3:
            continue
        stations.append({"id": id, "position": pos})
    active_index = -1
    visit_number = 0

func update(train_world_position: Vector3) -> Dictionary:
    if stations.is_empty():
        return {}
    var nearest: int = -1
    var nearest_distance: float = INF
    for i in range(stations.size()):
        var distance: float = train_world_position.distance_to(stations[i]["position"])
        if distance < nearest_distance:
            nearest = i
            nearest_distance = distance
    if nearest < 0 or nearest_distance > approach_radius_m:
        # Leaving the station area releases the visit; returning creates a new one.
        if active_index >= 0 and (nearest < 0 or nearest_distance > release_radius_m):
            active_index = -1
        return {}
    if active_index != nearest:
        active_index = nearest
        visit_number += 1
    var next_index: int = nearest + (-1 if direction == "reverse" else 1)
    var following: String = ""
    if next_index >= 0 and next_index < stations.size():
        following = str(stations[next_index]["id"])
    return {
        "station_id": str(stations[nearest]["id"]),
        "next_station_id": following,
        "direction": direction,
        "visit_id": "%s_%d" % [str(stations[nearest]["id"]), visit_number],
        "distance_m": nearest_distance,
        "approaching": nearest_distance > stop_radius_m,
        "at_station": nearest_distance <= stop_radius_m
    }
