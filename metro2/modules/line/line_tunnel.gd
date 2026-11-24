extends Node3D
## Runtime consumes prepared resources. All vertex deformation lives in the CI generator.
const Store = preload("res://modules/line/static_resource_store.gd")
const INDEX := "res://modules/line/prebuilt/tunnels.json"
const VISIBLE_DISTANCE := 120.0
const GUARD_DISTANCE := 32.0
@export var center_x := 0.992
var path: RefCounted
var _train: Node3D
var _camera: Camera3D
var _train_bounds := AABB()
var _route_active: Dictionary={}
var _wanted: Dictionary={}
var prepared_spans: Dictionary={}
var _retry_at: Dictionary={}
var _store: Node
var _busy := false
var _refresh_clock := 0.0
var _direction := 1
var _speed := 0.0

func _ready() -> void:
    _store=Store.shared(self)
    if not prepared_spans.is_empty(): return
    if FileAccess.file_exists(INDEX):
        var index: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(INDEX))
        prepared_spans=index.get("spans",{})
    else:
        push_error("Нет подготовленного тоннеля: сборка ресурсов не завершена")

func configure(train: Node3D, bounds: AABB, camera: Camera3D) -> void:
    _train=train
    _train_bounds=bounds
    _camera=camera
    sync_to_view()

func update_motion(direction: int, speed: float) -> void:
    if direction!=0 and _direction!=direction: _refresh_clock=0.0
    if direction!=0: _direction=direction
    _speed=absf(speed)

func _process(delta: float) -> void:
    _refresh_clock-=delta
    if _refresh_clock<=0.0:
        _refresh_clock=0.2
        sync_to_view()

func _include_slots(required: Dictionary, z0: float, z1: float, ahead: bool=false) -> void:
    var lead: float=clampf(_speed*12.0+_speed*_speed/1.3+64.0,192.0,1024.0) if ahead else 0.0
    var low: float=z0-VISIBLE_DISTANCE-GUARD_DISTANCE-(lead if _direction>0 else 0.0)
    var high: float=z1+VISIBLE_DISTANCE+GUARD_DISTANCE+(lead if _direction<0 else 0.0)
    for slot in range(floori(low/16.0),floori(high/16.0)+1): required[slot]=true

func sync_to_view() -> void:
    if path==null or not is_instance_valid(_train) or not is_instance_valid(_camera): return
    var required: Dictionary={}
    _include_slots(required,_train.global_position.z+_train_bounds.position.z,_train.global_position.z+_train_bounds.end.z,true)
    _include_slots(required,_camera.global_position.z,_camera.global_position.z)
    _wanted.clear()
    for slot in required:
        for span in path.tunnel_pieces(float(slot)*16.0,float(slot+1)*16.0):
            var key: String="%.4f:%.4f" % [span.x,span.y]
            if prepared_spans.has(key): _wanted[key]=prepared_spans[key]
    # Detach retired sections before reserving the next resource slice.
    for key in _route_active.keys():
        if _wanted.has(key): continue
        var section: Node3D=_route_active[key]
        _route_active.erase(key)
        section.hide()
        _store.release_chunk(section)
        section.queue_free()
    if not _busy:
        _busy=true
        call_deferred("_pump")

func _pump() -> void:
    while is_inside_tree():
        var next := ""
        var priority := INF
        for key in _wanted:
            if _route_active.has(key) or Time.get_ticks_msec()<int(_retry_at.get(key,0)): continue
            var description: Dictionary=_wanted[key]
            var middle: float=(float(description.low)+float(description.high))*0.5
            var train_distance: float=absf(middle-_train.global_position.z)
            if (_train.global_position.z-middle)*float(_direction)<0.0: train_distance*=1.25
            var distance: float=minf(train_distance,absf(middle-_camera.global_position.z))
            if distance<priority: priority=distance;next=str(key)
        if next.is_empty(): break
        var section: Node3D=await _store.instantiate_chunk(_wanted[next],self)
        if section==null:
            var retry_delay := 500 if _store.error_message.begins_with("Недостаточно") else 15000
            _retry_at[next]=Time.get_ticks_msec()+retry_delay
            continue
        if not _wanted.has(next):
            _store.release_chunk(section)
            section.queue_free()
            continue
        section.position=Vector3(center_x,0,float(_wanted[next].low))
        add_child(section)
        _route_active[next]=section
        _retry_at.erase(next)
        await get_tree().process_frame
    _busy=false

func approach_limit(z: float, direction: int, bounds: AABB) -> float:
    var limit: float=-INF if direction>0 else INF
    if path==null or direction==0: return limit
    # Inspect every span in the braking horizon, not just the requested cache.
    # Missing metadata is also a barrier; a failed bake never exposes empty space.
    var lead: float=maxf(256.0,_speed*_speed/1.3+VISIBLE_DISTANCE+64.0)
    var low: float=z+bounds.position.z-(lead if direction>0 else VISIBLE_DISTANCE)
    var high: float=z+bounds.end.z+(lead if direction<0 else VISIBLE_DISTANCE)
    for slot in range(floori(low/16.0),floori(high/16.0)+1):
        for span in path.tunnel_pieces(float(slot)*16.0,float(slot+1)*16.0):
            var key: String="%.4f:%.4f" % [span.x,span.y]
            if _route_active.has(key): continue
            var edge: float=span.y-bounds.position.z+GUARD_DISTANCE if direction>0 else span.x-bounds.end.z-GUARD_DISTANCE
            if direction>0 and edge<=z: limit=maxf(limit,edge)
            elif direction<0 and edge>=z: limit=minf(limit,edge)
            elif z+bounds.end.z>=span.x and z+bounds.position.z<=span.y:
                return z # Never move an incompletely protected consist.
    return limit

func constrain_camera(world_position: Vector3) -> Vector3:
    if path.in_station(world_position.z,10.0): return world_position
    if world_position.z>96.0:
        world_position.y=maxf(world_position.y,path.position_at(world_position.z).y+0.35)
        return world_position
    var centre: Vector3=path.position_at(world_position.z,center_x)
    world_position.x=clampf(world_position.x,centre.x-2.95,centre.x+2.95)
    world_position.y=clampf(world_position.y,centre.y+0.15,centre.y+6.6)
    return world_position

func _exit_tree() -> void:
    if is_instance_valid(_store):
        for section in _route_active.values(): _store.release_chunk(section)
    _route_active.clear()
    _wanted.clear()
