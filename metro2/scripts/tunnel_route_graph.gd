extends RefCounted
## Tunnel route graph: metadata and transforms for future curves and junctions.
## Coordinates use Godot metres; the current playable train still follows straight -Z.
## This file does not change rails, train physics or create junction geometry.

const STRAIGHT := "straight"
const CURVE := "curve"
const JUNCTION := "junction"
const VISUAL_BRANCH := "visual_branch"

var segments: Dictionary = {}
var links: Dictionary = {}

func add_straight(id: String, start: Vector3, heading: float, length: float) -> void:
    _add(id, STRAIGHT, start, heading, length, 0.0, {})

func add_curve(id: String, start: Vector3, heading: float,
        length: float, turn_radians: float) -> void:
    # Positive turn = turn left relative to the local forward direction.
    _add(id, CURVE, start, heading, length, turn_radians, {})

func add_junction(id: String, start: Vector3, heading: float,
        length: float, exit_ids: Array[String], selected_exit: String = "") -> void:
    _add(id, JUNCTION, start, heading, length, 0.0,
        {"exits": exit_ids.duplicate(), "selected_exit": selected_exit})

func add_visual_branch(id: String, start: Vector3, heading: float,
        length: float, side: int, angle_radians: float) -> void:
    # Decorative side bore only. Never routes a moving train by itself.
    _add(id, VISUAL_BRANCH, start, heading, length, angle_radians,
        {"side": clampi(side, -1, 1), "drivable": false})

func connect_segments(from_id: String, to_id: String) -> bool:
    if not segments.has(from_id) or not segments.has(to_id):
        return false
    if not links.has(from_id):
        links[from_id] = []
    if not links[from_id].has(to_id):
        links[from_id].append(to_id)
    return true

func sample(id: String, distance: float) -> Transform3D:
    # Sample the centreline for tunnel mesh generation, sleepers and cameras.
    var data: Dictionary = segments.get(id, {})
    if data.is_empty():
        return Transform3D.IDENTITY
    var length: float = data["length"]
    var d: float = clampf(distance, 0.0, length)
    var heading: float = data["heading"]
    var total_turn: float = data["turn"]
    var theta: float = total_turn * d / length
    var pos: Vector3 = data["start"]
    if absf(total_turn) < 0.00001:
        pos += Vector3(-sin(heading), 0.0, -cos(heading)) * d
    else:
        var radius: float = length / total_turn
        pos.x += radius * (cos(heading + theta) - cos(heading))
        pos.z += -radius * (sin(heading + theta) - sin(heading))
    return Transform3D(Basis(Vector3.UP, heading + theta), pos)

func get_exits(id: String) -> Array:
    return links.get(id, []).duplicate()

func validate() -> PackedStringArray:
    var errors := PackedStringArray()
    for id in segments:
        var seg: Dictionary = segments[id]
        if seg["length"] <= 0.0:
            errors.append("%s: length must be positive" % id)
        if seg["type"] == JUNCTION:
            for exit_id in seg["meta"]["exits"]:
                if not segments.has(exit_id):
                    errors.append("%s: missing exit %s" % [id, exit_id])
        for next_id in links.get(id, []):
            if not segments.has(next_id):
                errors.append("%s: broken link to %s" % [id, next_id])
    return errors

func _add(id: String, kind: String, start: Vector3, heading: float,
        length: float, turn: float, meta: Dictionary) -> void:
    if id.is_empty() or length <= 0.0:
        push_warning("TunnelGraph: invalid segment id or length")
        return
    segments[id] = {
        "type": kind, "start": start, "heading": heading,
        "length": length, "turn": turn, "meta": meta
    }
