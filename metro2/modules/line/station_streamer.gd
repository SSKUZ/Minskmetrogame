extends Node
## Owns only live scene instances. Route geometry belongs to line.path, never nodes.
const Catalog = preload("res://modules/core/module_catalog.gd")
const BuildBudget = preload("res://modules/line/build_budget.gd")
var _building_budget: RefCounted
const Connections = preload("res://modules/line/station_connection_adapter.gd")
signal station_loaded(index: int, station: Node3D)
signal station_unloading(index: int, station: Node3D)
signal loading_changed(message: String)
var line: Node3D
var pack_loader: Node
var instances: Dictionary = {}
var _wanted: Dictionary = {}
var _retry_at: Dictionary = {}
var _busy := false
var _clock := 0.0
var _load_seconds := 20.0
var _loading_id := ""
var _thread_path := ""
var _direction := 1
var _z := 430.0
var _speed := 0.0
var _settings: Dictionary = {}

func configure(owner_line: Node3D, loader: Node) -> void:
    line=owner_line
    pack_loader=loader
    _settings=line.layout.streaming
    _load_seconds=float(_settings.load_estimate_seconds)
    refresh()

func station(index: int) -> Node3D:
    return instances.get(index) as Node3D

func is_loaded(index: int) -> bool:
    return is_instance_valid(station(index))

func _process(delta: float) -> void:
    if not is_instance_valid(line): return
    _clock-=delta
    var direction: int=_direction
    if is_instance_valid(line.train) and is_instance_valid(line.train.cab_runtime):
        direction=int(line.train.cab_runtime.direction)
    if _clock<=0.0 or (direction!=0 and direction!=_direction):
        _clock=float(_settings.get("refresh_seconds",0.25))
        refresh()

func refresh() -> void:
    if not is_instance_valid(line) or line.stations.is_empty(): return
    var camera_z: float=INF
    if is_instance_valid(line.train):
        _z=float(line.train.distance)
        _speed=absf(float(line.train.speed))
        if is_instance_valid(line.train.cab_runtime) and int(line.train.cab_runtime.direction)!=0:
            _direction=int(line.train.cab_runtime.direction)
        if is_instance_valid(line.train.camera): camera_z=line.train.camera.global_position.z
    var nearest: Dictionary=line.path.nearest_station(_z)
    var centre: int=int(nearest.index)
    _wanted.clear()
    # Both neighbours remain available for immediate direction reversal.
    for offset in range(-int(_settings.retain_neighbours),int(_settings.retain_neighbours)+1):
        var index: int=centre+offset
        if index>=0 and index<line.stations.size(): _wanted[index]=true
    var braking: float=_speed*_speed/(2.0*float(_settings.braking_deceleration_mps2))
    var lead: float=maxf(float(_settings.prefetch_min_m),
        _speed*(_load_seconds+float(_settings.load_margin_seconds))+braking+120.0)
    for record in line.stations:
        var index: int=int(record.index)
        var ahead: float=(_z-float(record.stop_z))*float(_direction)
        if ahead>=0.0 and ahead<lead: _wanted[index]=true
        # A platform/free camera pins only the station actually in its view area.
        if camera_z>=float(record.low)-float(_settings.camera_radius_m) and camera_z<=float(record.high)+float(_settings.camera_radius_m):
            _wanted[index]=true
        # Keep the entire consist and all doorway transactions inside a live module.
        if is_instance_valid(line.train):
            var bounds: AABB=line.train._train_bounds
            if _z+bounds.end.z>=float(record.low)-60.0 and _z+bounds.position.z<=float(record.high)+60.0:
                _wanted[index]=true
        if is_instance_valid(line.passengers) and not line.passengers.can_unload_platform(index):
            _wanted[index]=true
    if not _busy:
        _busy=true
        call_deferred("_pump")

func _pump() -> void:
    # A single pump serializes pack downloads, instantiation and eviction.
    # Scene-tree mutation is exclusively on the main thread.
    while is_inside_tree():
        for key in instances.keys():
            var index: int=int(key)
            if _wanted.has(index): continue
            if is_instance_valid(line.passengers) and not line.passengers.can_unload_platform(index): continue
            var node: Node3D=station(index)
            station_unloading.emit(index,node)
            instances.erase(index)
            node.process_mode=Node.PROCESS_MODE_DISABLED
            await _dispose_station(node)
            if is_instance_valid(pack_loader):
                pack_loader.release_module_resources(str(line.stations[index].module_id))
            await get_tree().process_frame
            if not is_inside_tree(): return
        var next: int=-1
        var priority: float=INF
        for key in _wanted:
            var index: int=int(key)
            if is_loaded(index) or Time.get_ticks_msec()<int(_retry_at.get(index,0)): continue
            var distance: float=absf(_z-float(line.stations[index].stop_z))
            if (_z-float(line.stations[index].stop_z))*float(_direction)<0.0: distance*=1.15
            if distance<priority:
                priority=distance
                next=index
        if next<0: break
        if not await _load_station(next):
            _retry_at[next]=Time.get_ticks_msec()+int(float(_settings.retry_seconds)*1000.0)
        else:
            _retry_at.erase(next)
        # Position/direction may have changed during a long HTTP/resource load.
        refresh()
    _busy=false

func _load_station(index: int) -> bool:
    var record: Dictionary=line.stations[index]
    var id: String=str(record.module_id)
    _loading_id=id
    loading_changed.emit("Загрузка станции: "+id)
    var started: int=Time.get_ticks_msec()
    if is_instance_valid(pack_loader):
        if not await pack_loader.ensure_module(id,self):
            loading_changed.emit(pack_loader.error_message)
            pack_loader.release_module_resources(id)
            _loading_id=""
            return false
    if not is_inside_tree(): return false
    if not _wanted.has(index):
        if is_instance_valid(pack_loader): pack_loader.release_module_resources(id)
        _loading_id=""
        return true
    var scene_path: String=str(Catalog.SCENES[id])
    var scene: PackedScene
    if not OS.has_feature("web"):
        # Godot 4.3 single-thread Web export has no worker loader. Native targets
        # can decode resources off-thread; instantiate/_ready stay here.
        var error: Error=ResourceLoader.load_threaded_request(scene_path,"PackedScene",false,ResourceLoader.CACHE_MODE_REUSE)
        if error==OK:
            _thread_path=scene_path
            var state: int=ResourceLoader.load_threaded_get_status(scene_path)
            while state==ResourceLoader.THREAD_LOAD_IN_PROGRESS:
                await get_tree().process_frame
                state=ResourceLoader.load_threaded_get_status(scene_path)
            scene=ResourceLoader.load_threaded_get(scene_path) as PackedScene
            _thread_path=""
    else:
        # The native resource parser cannot be preempted on single-thread Web.
        # Texture dependencies were prepared individually by the pack loader;
        # procedural construction below is cooperatively budgeted, not faked by
        # a yield immediately before one synchronous scene _ready().
        scene=ResourceLoader.load(scene_path,"PackedScene",ResourceLoader.CACHE_MODE_REUSE) as PackedScene
    if scene==null:
        if is_instance_valid(pack_loader): pack_loader.release_module_resources(id)
        loading_changed.emit("Не удалось прочитать станцию: "+id+"; повтор загрузки через 15 с")
        _loading_id=""
        return false
    # Cancelled native requests are still consumed above, releasing their handle.
    if not _wanted.has(index):
        scene=null
        if is_instance_valid(pack_loader): pack_loader.release_module_resources(id)
        _loading_id=""
        return true
    await get_tree().process_frame
    var node: Node3D=scene.instantiate() as Node3D
    scene=null
    if node==null:
        if is_instance_valid(pack_loader): pack_loader.release_module_resources(id)
        _loading_id=""
        return false
    node.position.z=float(record.root_z)
    node.name="LineStation_"+id
    node.set("track_min_z",float(record.exit_local_z))
    node.set("track_max_z",float(record.entry_local_z))
    var budget=BuildBudget.new(self,2000)
    _building_budget=budget
    node.set_meta("metro_line_work",budget)
    budget.register_source(node)
    var active_mode: int=node.process_mode
    node.process_mode=Node.PROCESS_MODE_DISABLED
    node.hide()
    line.add_child(node)
    # _ready notifications may yield. Do not expose a partly built platform or
    # admit the train until this root and all cooperative child builders finish.
    while not budget.pending.is_empty():
        await get_tree().process_frame
        if not _wanted.has(index):
            budget.cancel()
            await _dispose_station(node)
            _building_budget=null
            if is_instance_valid(pack_loader): pack_loader.release_module_resources(id)
            _loading_id=""
            return true
    await Connections.open_connections(node,budget)
    if not _wanted.has(index):
        budget.cancel()
        await _dispose_station(node)
        _building_budget=null
        if is_instance_valid(pack_loader): pack_loader.release_module_resources(id)
        _loading_id=""
        return true
    _building_budget=null
    budget.release_sources()
    node.process_mode=active_mode
    node.show()
    instances[index]=node
    station_loaded.emit(index,node)
    # Only scene/agent owners retain decoded resources; never keep PackedScenes.
    if is_instance_valid(pack_loader): pack_loader.release_module_resources(id)
    await get_tree().process_frame
    var seconds: float=float(Time.get_ticks_msec()-started)/1000.0
    _load_seconds=clampf(maxf(seconds,_load_seconds*0.8),2.0,90.0)
    _loading_id=""
    loading_changed.emit("")
    return true

func _dispose_station(root: Node3D) -> void:
    root.hide()
    root.process_mode=Node.PROCESS_MODE_DISABLED
    var budget=BuildBudget.new(self,2000)
    # Release leaves in bounded batches rather than recursively deleting a
    # complete detailed station at one frame boundary.
    var stack: Array[Node]=[root]
    var count: int=0
    while not stack.is_empty():
        var node: Node=stack[-1]
        if node.get_child_count()>0:
            stack.append(node.get_child(0))
            continue
        stack.pop_back()
        if node!=root: node.get_parent().remove_child(node)
        node.queue_free()
        count+=1
        if count>=64:
            count=0
            await get_tree().process_frame
        elif not await budget.checkpoint():
            return

func approach_limit(z: float, direction: int, bounds: AABB) -> float:
    # Train-root coordinate of the first missing station's protected approach.
    # The route/train/INFO keep working while an HTTP request is outstanding.
    var limit: float=-INF if direction>0 else INF
    for record in line.stations:
        if is_loaded(int(record.index)): continue
        var edge: float=float(record.high)-bounds.position.z+float(_settings.approach_guard_m) if direction>0 else float(record.low)-bounds.end.z-float(_settings.approach_guard_m)
        if direction>0 and edge<=z: limit=maxf(limit,edge)
        elif direction<0 and edge>=z: limit=minf(limit,edge)
    return limit

func _exit_tree() -> void:
    # Child instances are owned by the line, and freed with that subtree.
    if _building_budget!=null: _building_budget.cancel()
    if is_instance_valid(pack_loader) and not _loading_id.is_empty():
        pack_loader.release_module_resources(_loading_id)
    if not _thread_path.is_empty():
        # Godot 4.3 cannot cancel a threaded request. Consume its result exactly
        # once on teardown as well, so its internal handle cannot retain scenes.
        ResourceLoader.load_threaded_get(_thread_path)
        _thread_path=""
    instances.clear()
    _wanted.clear()
