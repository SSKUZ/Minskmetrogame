extends Node3D
const WalkingGeometry = preload("res://modules/gameplay/world_geometry.gd")
## Runtime consumes prepared resources. All vertex deformation lives in the CI generator.
const BuildBudget = preload("res://modules/line/build_budget.gd")
const Store = preload("res://modules/line/static_resource_store.gd")
const INDEX := "res://modules/line/prebuilt/tunnels.json"
const VISIBLE_DISTANCE := 120.0
const GUARD_DISTANCE := 32.0
@export var center_x := 0.992
signal base_prepared
const BASE_POOL_SIZE := 128
var base_spans: Dictionary={}
var base_part_kinds: Array=[]
var base_cache: Dictionary={"data":{},"order":[]}
var base_ready := false
var line: Node3D
var _base_slots: Dictionary={}
var _base_coverage: Dictionary={}
var _base_active: Dictionary={}
var _base_wanted: Dictionary={}
var _base_required_slots: Dictionary={}
var _base_pool: Array[Node3D]=[]
var _base_busy := false
var _pool_ready := false
var _configured := false
var _base_budget: RefCounted
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
    if not prepared_spans.is_empty() and not base_spans.is_empty(): return
    if FileAccess.file_exists(INDEX):
        var index: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(INDEX))
        prepared_spans=index.get("spans",{})
        base_spans=index.get("base",{})
        base_part_kinds=index.get("base_part_kinds",[])
    else:
        push_error("Нет подготовленного тоннеля: сборка ресурсов не завершена")

func configure(train: Node3D, bounds: AABB, camera: Camera3D) -> void:
    _train=train
    _train_bounds=bounds
    _camera=camera
    if _configured:
        sync_to_view()
        return
    _configured=true
    _index_base()
    sync_to_view()
    call_deferred("_prepare_pool")

func update_motion(direction: int, speed: float) -> void:
    if direction!=0 and _direction!=direction: _refresh_clock=0.0
    if direction!=0: _direction=direction
    _speed=absf(speed)
    # Bounds can change while the fourth car finishes attaching.
    if is_instance_valid(line) and is_instance_valid(line.train): _train_bounds=line.train._train_bounds

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
    var player: Node3D=line.gameplay.player if is_instance_valid(line) and is_instance_valid(line.gameplay) else null
    if is_instance_valid(player) and player.active:
        _include_slots(required,player.global_position.z,player.global_position.z)
    _sync_base(required)
    # The long braking horizon belongs to base track only. Detail resources
    # retain the original view distance plus a short time-based prefetch band.
    var detail_slots: Dictionary={}
    var lead: float=clampf(_speed*6.0+32.0,64.0,192.0)
    _include_slots(detail_slots,_train.global_position.z+_train_bounds.position.z-(lead if _direction>0 else 0.0),
        _train.global_position.z+_train_bounds.end.z+(lead if _direction<0 else 0.0))
    _include_slots(detail_slots,_camera.global_position.z,_camera.global_position.z)
    if is_instance_valid(player) and player.active:
        _include_slots(detail_slots,player.global_position.z,player.global_position.z)
    _wanted.clear()
    for slot in detail_slots:
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
        if is_instance_valid(line) and is_instance_valid(line.streamer) and line.streamer.has_priority_work():
            await get_tree().process_frame
            continue
        var next := ""
        var priority := INF
        for key in _wanted:
            if _route_active.has(key) or Time.get_ticks_msec()<int(_retry_at.get(key,0)): continue
            var description: Dictionary=_wanted[key]
            var middle: float=(float(description.low)+float(description.high))*0.5
            var train_distance: float=absf(middle-_train.global_position.z)
            if (_train.global_position.z-middle)*float(_direction)<0.0: train_distance*=1.25
            var camera_distance: float=absf(middle-_camera.global_position.z)
            var distance: float=minf(train_distance,camera_distance)
            # Fill the camera's complete visible corridor before distant extras.
            if camera_distance>VISIBLE_DISTANCE+GUARD_DISTANCE: distance+=1536.0
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

func _index_base() -> void:
    for key in base_spans:
        var desc: Dictionary=base_spans[key]
        var slot: int=floori((float(desc.low)+float(desc.high))*0.5/16.0)
        if not _base_slots.has(slot): _base_slots[slot]=[]
        _base_slots[slot].append(str(key))
    for slot in _base_slots:
        var keys: Array=_base_slots[slot]
        keys.sort_custom(func(a: String,b: String): return float(base_spans[a].low)<float(base_spans[b].low))
        var cursor: float=maxf(float(slot)*16.0,path.lower_z)
        var complete := true
        for key in keys:
            var desc: Dictionary=base_spans[key]
            if absf(float(desc.low)-cursor)>0.001: complete=false
            cursor=float(desc.high)
        _base_coverage[slot]=complete and absf(cursor-minf(float(slot+1)*16.0,96.0))<0.001
    if base_spans.is_empty(): push_error("Отсутствует подготовленный базовый путь")

func _prepare_pool() -> void:
    if base_part_kinds.is_empty(): return
    _base_budget=BuildBudget.new(self,1500)
    # Allocate once before departure; movement only changes resource bindings.
    for i in range(BASE_POOL_SIZE):
        var root := Node3D.new()
        root.name="BasePathPool%d" % i
        root.hide()
        add_child(root)
        _base_pool.append(root)
        for kind in base_part_kinds:
            var part: GeometryInstance3D
            if str(kind)=="MeshInstance3D": part=MeshInstance3D.new()
            elif str(kind)=="MultiMeshInstance3D": part=MultiMeshInstance3D.new()
            else:
                push_error("Неизвестный тип базового пути: "+str(kind))
                return
            root.add_child(part)
            if part is MeshInstance3D:
                var body:=StaticBody3D.new()
                body.name="WalkCollision"
                body.collision_layer=0
                body.collision_mask=0
                part.add_child(body)
                var collision:=CollisionShape3D.new()
                collision.name="Shape"
                body.add_child(collision)
            if not await _base_budget.checkpoint(): return
    _pool_ready=true
    _request_base()

func _release_base(root: Node3D) -> void:
    _base_visible(root,false)
    for part in root.get_children():
        if part is MeshInstance3D:
            part.mesh=null
            part.get_node("WalkCollision/Shape").shape=null
        elif part is MultiMeshInstance3D: part.multimesh=null
        part.material_override=null
    _base_pool.append(root)

func _sync_base(required: Dictionary) -> void:
    _base_wanted.clear()
    _base_required_slots.clear()
    for slot in required:
        if float(slot)*16.0<96.0 and float(slot+1)*16.0>path.lower_z: _base_required_slots[slot]=true
        for key in _base_slots.get(slot,[]): _base_wanted[key]=base_spans[key]
    for key in _base_active.keys():
        if _base_wanted.has(key):
            _base_visible(_base_active[key],not _station_has_track(base_spans[key]))
        else:
            _release_base(_base_active[key])
            _base_active.erase(key)
    _request_base()

func _station_has_track(desc: Dictionary) -> bool:
    var index: int=int(desc.get("station",-1))
    return index>=0 and is_instance_valid(line) and line.streamer.is_loaded(index)

func station_track_changed(index: int, available: bool) -> void:
    # Exchange station-owned rails and pooled rails without a blank frame.
    for key in _base_active:
        if int(base_spans[key].get("station",-1))==index: _base_visible(_base_active[key],not available)

func _request_base() -> void:
    if not _pool_ready or _base_busy: return
    _base_busy=true
    call_deferred("_pump_base")

func _base_data(key: String) -> Resource:
    var resource_path: String=str(base_spans[key].get("track_2_path",base_spans[key].path)) if center_x<0.0 else str(base_spans[key].path)
    key=resource_path # Different conductors, identical shared non-contact meshes.
    if not base_cache.data.has(key):
        var resource: Resource=ResourceLoader.load(resource_path,"Resource",ResourceLoader.CACHE_MODE_REUSE)
        if resource==null or not resource.has_meta("parts"): return null
        base_cache.data[key]=resource
    base_cache.order.erase(key)
    base_cache.order.append(key)
    while base_cache.order.size()>BASE_POOL_SIZE:
        base_cache.data.erase(base_cache.order.pop_front())
    return base_cache.data[key]

func _pump_base() -> void:
    # Base resources are local to the full_line PCK, independent of HTTP detail
    # downloads and their memory quota. Decode one tile, bind within a slice.
    while is_inside_tree() and not _base_pool.is_empty():
        var next := ""
        var priority := INF
        for key in _base_wanted:
            if _base_active.has(key) or Time.get_ticks_msec()<int(_retry_at.get("base:"+str(key),0)): continue
            var desc: Dictionary=base_spans[key]
            var middle: float=(float(desc.low)+float(desc.high))*0.5
            var distance: float=absf(middle-_train.global_position.z)
            # Train's safety corridor always precedes a remote camera's tiles.
            if distance>1536.0: distance+=10000.0
            if distance<priority: next=str(key);priority=distance
        if next.is_empty(): break
        var data: Resource=_base_data(next)
        var parts: Array=data.get_meta("parts",[]) if data!=null else []
        if parts.size()!=base_part_kinds.size():
            _retry_at["base:"+next]=Time.get_ticks_msec()+15000
            continue
        var root: Node3D=_base_pool.pop_back()
        for i in range(parts.size()):
            var part: GeometryInstance3D=root.get_child(i) as GeometryInstance3D
            var payload: Dictionary=parts[i]
            part.transform=payload.transform
            part.visible=bool(payload.visible)
            part.material_override=payload.get("material") as Material
            if part is MeshInstance3D:
                part.mesh=payload.get("mesh") as Mesh
                var body: StaticBody3D=part.get_node("WalkCollision")
                var collision: CollisionShape3D=body.get_node("Shape")
                collision.shape=payload.get("collision") as Shape3D
                body.set_meta("metro_electric",bool(payload.get("electric",false)))
                if not bool(payload.get("electric",false)): body.remove_meta("metro_electric")
            elif part is MultiMeshInstance3D: part.multimesh=payload.get("multimesh") as MultiMesh
            if not await _base_budget.checkpoint(): return
        if not _base_wanted.has(next):
            _release_base(root)
        else:
            root.position=Vector3(center_x,0,float(base_spans[next].low))
            _base_visible(root,not _station_has_track(base_spans[next]))
            _base_active[next]=root
        await get_tree().process_frame
    _base_busy=false
    if not base_ready and _pool_ready and _initial_base_complete():
        base_ready=true
        base_prepared.emit()

func _initial_base_complete() -> bool:
    for slot in _base_required_slots:
        if not bool(_base_coverage.get(slot,false)): return false
    for key in _base_wanted:
        if not _base_active.has(key): return false
    return not base_spans.is_empty()

func approach_limit(z: float, direction: int, bounds: AABB) -> float:
    var limit: float=-INF if direction>0 else INF
    if path==null or direction==0: return limit
    # Decorations and station architecture are deliberately absent here.
    # Missing metadata, decode errors and pool exhaustion still protect the path.
    var lead: float=maxf(256.0,_speed*_speed/1.3+VISIBLE_DISTANCE+64.0)
    var low: float=maxf(z+bounds.position.z-(lead if direction>0 else VISIBLE_DISTANCE),path.lower_z)
    var high: float=minf(z+bounds.end.z+(lead if direction<0 else VISIBLE_DISTANCE),96.0)
    if high<=low: return limit
    for slot in range(floori(low/16.0),ceili(high/16.0)):
        var missing: Array=[]
        if not bool(_base_coverage.get(slot,false)):
            missing.append(Vector2(maxf(float(slot)*16.0,path.lower_z),minf(float(slot+1)*16.0,96.0)))
        else:
            for key in _base_slots[slot]:
                if not _base_active.has(key): missing.append(Vector2(float(base_spans[key].low),float(base_spans[key].high)))
        for span in missing:
            var edge: float=span.y-bounds.position.z+GUARD_DISTANCE if direction>0 else span.x-bounds.end.z-GUARD_DISTANCE
            if direction>0 and edge<=z: limit=maxf(limit,edge)
            elif direction<0 and edge>=z: limit=minf(limit,edge)
            elif z+bounds.end.z>=span.x and z+bounds.position.z<=span.y: return z
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
    if _base_budget!=null: _base_budget.cancel()
    _base_active.clear()
    _base_pool.clear()
    if is_instance_valid(_store):
        for section in _route_active.values(): _store.release_chunk(section)
    _route_active.clear()
    _wanted.clear()

func _base_visible(root: Node3D, available: bool) -> void:
    root.visible=available
    for part in root.get_children():
        var body:=part.get_node_or_null("WalkCollision") as StaticBody3D
        if body==null: continue
        body.collision_layer=(WalkingGeometry.WORLD|(WalkingGeometry.ELECTRIC if body.has_meta("metro_electric") else 0)) if available and part.visible else 0
