extends RefCounted
class_name MetroStationPositionTracker
## Station points and the train reference use world coordinates, in metres.
var stations: Array[Dictionary] = []
var route_ids: Array = []
var direction: String = "forward"
var active_index: int = -1
var visit_number: int = 0
var approach_radius_m: float = 100.0
var stop_radius_m: float = 0.5
var release_radius_m: float = 125.0

func set_direction(value: String) -> void:
    if value not in ["forward", "reverse"] or value == direction:
        return
    direction = value
    active_index = -1

func configure(markers: Array[Dictionary], travel_direction: String = "forward") -> void:
    stations.clear()
    direction = travel_direction if travel_direction == "reverse" else "forward"
    for marker in markers:
        var id: String = str(marker.get("id", ""))
        var pos: Variant = marker.get("position")
        if id == "" or not pos is Vector3:
            continue
        stations.append({"id": id, "position": pos, "side": int(marker.get("side", -1))})
    if not route_ids.is_empty():
        stations.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return route_ids.find(a["id"]) < route_ids.find(b["id"]))
    active_index = -1
    # Preserve the serial across registration changes to avoid duplicate visit IDs.

func update(train_world_position: Vector3) -> Dictionary:
    var nearest: int = -1
    var nearest_distance: float = INF
    for i in range(stations.size()):
        var separation: float = train_world_position.distance_to(stations[i]["position"])
        if separation < nearest_distance:
            nearest = i
            nearest_distance = separation
    if nearest < 0 or nearest_distance > approach_radius_m:
        if active_index >= 0 and nearest_distance > release_radius_m:
            active_index = -1
        return {}
    if active_index != nearest:
        active_index = nearest
        visit_number += 1
    var id: String = str(stations[nearest]["id"])
    var order: Array = route_ids
    if order.is_empty():
        order = stations.map(func(s: Dictionary) -> String: return str(s["id"]))
    var next_index: int = order.find(id) + (-1 if direction == "reverse" else 1)
    var following: String = str(order[next_index]) if next_index >= 0 and next_index < order.size() else ""
    return {"station_id": id, "next_station_id": following, "direction": direction,
        "visit_id": "%s_%s_%d" % [id, direction, visit_number], "distance_m": nearest_distance,
        "approaching": nearest_distance > stop_radius_m, "at_station": nearest_distance <= stop_radius_m,
        "platform_side": stations[nearest]["side"]}

func configure_from_nodes(marker_root: Node, travel_direction: String = "forward") -> int:
    var markers: Array[Dictionary] = []
    if marker_root != null:
        for child in marker_root.get_children():
            if child is Node3D and child.has_meta("station_id"):
                markers.append({"id": str(child.get_meta("station_id")), "position": (child as Node3D).global_position,
                    "side": int(child.get_meta("platform_side", -1))})
    configure(markers, travel_direction)
    return stations.size()
