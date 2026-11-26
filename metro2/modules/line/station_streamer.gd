extends Node
## Owns only live scene instances. Route geometry belongs to line.path, never nodes.
const Catalog = preload("res://modules/core/module_catalog.gd")
const BuildBudget = preload("res://modules/line/build_budget.gd")
var _building_budget: RefCounted
const WalkingGeometry = preload("res://modules/gameplay/world_geometry.gd")
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
const TRAIN := 1
const PLAYER := 2
const CAMERA := 4
var _retention: Dictionary = {}
var _next_index := -1
var _player: WeakRef
var _startup_target:=-1
var _errors: Dictionary={}

func set_startup_target(index: int) -> void:
    _startup_target=index
    refresh()

func clear_startup_target() -> void:
    if int(_retry_at.get(_startup_target,0))==9223372036854775807: _retry_at.erase(_startup_target)
    _startup_target=-1
    refresh()

func register_player(player: Node3D) -> void:
    _player=weakref(player) if is_instance_valid(player) else null
    refresh()

func retry_station(index: int) -> void:
    if index<0 or index>=line.stations.size(): return
    _errors.erase(index)
    if is_loaded(index):
        if is_instance_valid(line.passengers): line.passengers.retry_platform(index)
        return
    _retry_at.erase(index)
    _clock=0.0
    refresh() # The existing single pump owns the in-flight request.

func station_error(index: int) -> String:
    if _errors.has(index): return str(_errors[index])
    return line.passengers.platform_error(index) if is_instance_valid(line.passengers) else ""

func _load_failed(index: int, message: String) -> bool:
    _errors[index]=message
    loading_changed.emit(message)
    return false

func retention_reasons(index: int) -> PackedStringArray:
    var result := PackedStringArray()
    var reasons: int=int(_retention.get(index,0))
    if reasons&TRAIN: result.append("TRAIN")
    if reasons&PLAYER: result.append("PLAYER")
    if reasons&CAMERA: result.append("CAMERA")
    return result

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
    _wanted.clear()
    _retention.clear()
    if _startup_target>=0 and _startup_target<line.stations.size() and is_instance_valid(line.gameplay) and not line.gameplay.running:
        _wanted[_startup_target]=true
        _retention[_startup_target]=PLAYER
        if not _busy:
            _busy=true
            call_deferred("_pump")
        return
    _next_index=-1
    var bounds := AABB()
    if is_instance_valid(line.train): bounds=line.train._train_bounds
    var virtual_parked: bool=is_instance_valid(line.gameplay) and line.gameplay.virtual_wait
    var front: float=_z+(bounds.position.z if _direction>0 else bounds.end.z)
    # First unpassed platform only. Direction reversal recomputes this selection.
    var ordered: Array=line.stations.duplicate()
    if _direction<0: ordered.reverse()
    for record in ordered:
        if virtual_parked: break
        if (_direction>0 and front>float(record.low)) or (_direction<0 and front<float(record.high)):
            _next_index=int(record.index)
            _wanted[_next_index]=true
            break
    var player: Node3D=_player.get_ref() as Node3D if _player!=null else null
    if not is_instance_valid(player):
        player=get_tree().get_first_node_in_group("metro_player") as Node3D
    # Current walking inspection uses the free camera as its physical anchor.
    # A separate pedestrian controller can register its own independent anchor.
    if not is_instance_valid(player) and is_instance_valid(line.train) and line.train.camera_mode=="flight":
        player=line.train.camera
    var platform: Node3D=line.train.retained_platform_station() if is_instance_valid(line.train) else null
    for record in line.stations:
        var index: int=int(record.index)
        var low: float=float(record.low)
        var high: float=float(record.high)
        var reasons: int=0
        if not virtual_parked and is_instance_valid(line.train) and _z+bounds.end.z>=low-152.0 and _z+bounds.position.z<=high+152.0:
            reasons|=TRAIN
        if is_instance_valid(line.passengers) and not line.passengers.can_unload_platform(index): reasons|=TRAIN
        if is_instance_valid(player) and player.global_position.z>=low-30.0 and player.global_position.z<=high+30.0:
            reasons|=PLAYER
        if (camera_z>=low-152.0 and camera_z<=high+152.0) or (is_instance_valid(platform) and platform==station(index)):
            reasons|=CAMERA
        if reasons!=0:
            _retention[index]=reasons
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
            refresh() # Re-evaluate TRAIN/PLAYER/CAMERA after every awaited disposal.
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
            if int(_retention.get(index,0))&PLAYER: distance-=100000.0
            if (_z-float(line.stations[index].stop_z))*float(_direction)<0.0: distance*=1.15
            if distance<priority:
                priority=distance
                next=index
        if next<0: break
        if not await _load_station(next):
            # An initial player request reports failure to the role menu.
            # Only an explicit retry restarts it; normal route streaming retries.
            _retry_at[next]=9223372036854775807 if next==_startup_target else Time.get_ticks_msec()+int(float(_settings.retry_seconds)*1000.0)
        else:
            _retry_at.erase(next)
        # Position/direction may have changed during a long HTTP/resource load.
        refresh()
    _busy=false

func _load_station(index: int) -> bool:
    var record: Dictionary=line.stations[index]
    var id: String=str(record.module_id)
    _errors.erase(index)
    if not Catalog.SCENES.has(id): return _load_failed(index,"Станция не зарегистрирована: "+id)
    _loading_id=id
    loading_changed.emit("Загрузка станции: "+id)
    var started: int=Time.get_ticks_msec()
    if is_instance_valid(pack_loader):
        if not await pack_loader.ensure_module(id,self):
            var failure: String=pack_loader.error_message
            pack_loader.release_module_resources(id)
            _loading_id=""
            return _load_failed(index,failure)
    if not is_inside_tree(): return false
    if not _wanted.has(index):
        if is_instance_valid(pack_loader): pack_loader.release_module_resources(id)
        _loading_id=""
        return true
    var prepared_data: Dictionary=Catalog.prepared_station_data(id)
    var prepared: bool=not prepared_data.is_empty()
    var scene_path: String=str(Catalog.SCENES[id])
    var scene: PackedScene
    if prepared:
        pass # Prepared fragments are decoded one at a time below.
    elif not OS.has_feature("web"):
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
    if scene==null and not prepared:
        if is_instance_valid(pack_loader): pack_loader.release_module_resources(id)
        _loading_id=""
        return _load_failed(index,"Не удалось прочитать сцену станции: "+id+" · "+scene_path)
    # Cancelled native requests are still consumed above, releasing their handle.
    if not _wanted.has(index):
        scene=null
        if is_instance_valid(pack_loader): pack_loader.release_module_resources(id)
        _loading_id=""
        return true
    await get_tree().process_frame
    var node: Node3D=Catalog.create_module(id,prepared_data) if prepared else scene.instantiate() as Node3D
    scene=null
    if node==null:
        if is_instance_valid(pack_loader): pack_loader.release_module_resources(id)
        _loading_id=""
        return _load_failed(index,"Не удалось создать станцию: "+id)
    node.position.z=float(record.root_z)
    node.name="LineStation_"+id
    if prepared:
        node.set("line_open",true)
    else:
        node.set("track_min_z",float(record.low)-float(record.root_z))
        node.set("track_max_z",float(record.high)-float(record.root_z))
        node.set_meta("metro_line_datum",line.layout.station_datums[id])
    var budget=BuildBudget.new(self,2000)
    _building_budget=budget
    node.set_meta("metro_line_work",budget)
    budget.register_source(node)
    var active_mode: int=node.process_mode
    node.process_mode=Node.PROCESS_MODE_DISABLED
    node.hide()
    if prepared:
        node.static_progress.connect(func(message: String): loading_changed.emit(id+" · "+message))
    line.add_child(node)
    # Publish the platform only after every cooperative child builder finishes.
    # The independent prepared base path remains available during this work.
    var preparation_deadline: int=Time.get_ticks_msec()+180000
    while not budget.pending.is_empty() and not (prepared and bool(node.get("static_failed"))):
        await get_tree().process_frame
        var expired: bool=Time.get_ticks_msec()>=preparation_deadline
        if not _wanted.has(index) or expired:
            budget.cancel()
            await _dispose_station(node)
            _building_budget=null
            if is_instance_valid(pack_loader): pack_loader.release_module_resources(id)
            _loading_id=""
            if expired:
                return _load_failed(index,"Не завершена подготовка геометрии станции: "+id+"; доступен повтор")
            return true
    if prepared and bool(node.get("static_failed")):
        var failure: String=str(node.get("static_error"))
        budget.cancel()
        await _dispose_station(node)
        _building_budget=null
        if is_instance_valid(pack_loader): pack_loader.release_module_resources(id)
        _loading_id=""
        return _load_failed(index,"Станция "+id+": "+failure)
    if not prepared:
        await Connections.open_connections(node,budget)
        await WalkingGeometry.new().prepare(node,false,true)
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
    if root.has_method("release_static_resources"): root.call("release_static_resources")
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
