extends Node
## Owns only live scene instances. Route geometry belongs to line.path, never nodes.
const Catalog = preload("res://modules/core/module_catalog.gd")
const BuildBudget = preload("res://modules/line/build_budget.gd")
var _building_budget: RefCounted
const WalkLite = preload("res://modules/gameplay/walk_lite.gd")
const Connections = preload("res://modules/line/station_connection_adapter.gd")
signal station_loaded(index: int, station: Node3D)
signal station_unloading(index: int, station: Node3D)
signal loading_changed(message: String)
signal retry_required(index: int, message: String)
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
enum State { NOT_REQUESTED, PACK_LOADING, PACK_READY, RESOURCE_PREPARING, SCENE_CREATING, SCENE_READY, SERVICE_READY, FAILED }
var _states: Dictionary={}
var _attempts: Dictionary={}
var _scene_bounds: Dictionary={}
var _current_index:=-1
var _dispatch_priorities: Dictionary={}
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
    _attempts.erase(index)
    if is_loaded(index) and is_instance_valid(line.passengers): line.passengers.retry_platform(index)
    _retry_at.erase(index)
    _clock=0.0
    refresh() # The existing single pump owns the in-flight request.

func station_error(index: int) -> String:
    if _errors.has(index): return str(_errors[index])
    return line.passengers.platform_error(index) if is_instance_valid(line.passengers) else ""

func _load_failed(index: int, message: String) -> bool:
    message="Этап %s · %s" % [State.keys()[state(index)],message]
    _errors[index]=message
    _states[index]=State.FAILED
    push_error("Station streaming %d: %s" % [index,message])
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

func state(index: int) -> int:
    return int(_states.get(index,State.NOT_REQUESTED))

func is_service_ready(index: int) -> bool:
    return is_loaded(index) and state(index)==State.SERVICE_READY and is_instance_valid(line.passengers) and line.passengers.platform_ready(index)

func has_priority_work() -> bool:
    return _busy and (_loading_id!="" or (_next_index>=0 and not is_service_ready(_next_index)))

func player_station_index() -> int:
    var player: Node3D=_player.get_ref() as Node3D if _player!=null else null
    if not is_instance_valid(player) or not bool(player.get("active")) or is_instance_valid(player.get("aboard")): return -1
    for key in _scene_bounds:
        if (_scene_bounds[key] as AABB).grow(1.0).has_point(player.global_position): return int(key)
    # The physical walking character owns its safe platform even while using
    # a different camera or exploring that station's adjoining passage.
    if is_instance_valid(line.gameplay) and not line.gameplay.direct_driver:
        return int(line.gameplay._safe_station)
    return -1

func station_camera_bounds(index: int) -> AABB:
    return _scene_bounds.get(index,AABB())

func movement_guard(direction: int, actor: Node3D=null) -> Dictionary:
    if direction==0: return {}
    var ordered: Array=line.stations.duplicate()
    if direction<0: ordered.reverse()
    var vehicle: Node3D=actor if is_instance_valid(actor) else line.train
    var bounds: AABB=vehicle._train_bounds
    var leading: float=float(vehicle.distance)+(bounds.position.z if direction>0 else bounds.end.z)
    var trailing: float=float(vehicle.distance)+(bounds.end.z if direction>0 else bounds.position.z)
    for record in ordered:
        var index: int=int(record.index)
        if (direction>0 and trailing<float(record.low)) or (direction<0 and trailing>float(record.high)): continue
        if is_service_ready(index) and vehicle.line.passengers.platform_ready(index): continue
        var edge: float=float(record.high)+float(_settings.approach_guard_m) if direction>0 else float(record.low)-float(_settings.approach_guard_m)
        return {"index":index,"remaining":maxf(0.0,(leading-edge)*float(direction))}
    return {}

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
    # The role menu must not start downloading Uruchye (or any station) before
    # the player selects a role. Passenger startup explicitly pins its station;
    # direct driver startup needs the existing cab, not a station download.
    if not is_instance_valid(line.gameplay) and _startup_target<0: return
    if is_instance_valid(line.gameplay) and not line.gameplay.running and not line.gameplay._starting and _startup_target<0:
        # Drop requests from an earlier refresh, including those queued while
        # an asynchronous pack download was still yielding.
        _wanted.clear()
        _retention.clear()
        _next_index=-1
        return
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
    _current_index=-1
    for record in line.stations:
        if _z>=float(record.low) and _z<=float(record.high):
            _current_index=int(record.index)
            break
    # A dwelling train already requests the NEXT platform, in either direction.
    # The current platform is separately retained by the train envelope below.
    var platform_shuttle: bool=is_instance_valid(line.gameplay) and line.gameplay.timetable.platform_shuttle_station()>=0
    if not virtual_parked and not platform_shuttle:
        if _current_index>=0:
            var following: int=_current_index+_direction
            if following>=0 and following<line.stations.size(): _next_index=following
        else:
            var ordered: Array=line.stations.duplicate()
            if _direction<0: ordered.reverse()
            for record in ordered:
                if (_z-float(record.stop_z))*float(_direction)>float(line.layout.stop_tolerance_m):
                    _next_index=int(record.index)
                    break
        if _next_index>=0: _wanted[_next_index]=true
    if is_instance_valid(line.gameplay) and line.gameplay.role=="passenger" and not virtual_parked and not platform_shuttle:
        var automatic: Node=line.gameplay.automatic
        if automatic.phase==automatic.Phase.RUN:
            _next_index=int(automatic.target)
            # Rebuild the future demand below from the single authoritative
            # target. Do not retain a position-derived second future station.
            _wanted.clear()
            if _next_index>=0: _wanted[_next_index]=true
    if is_instance_valid(line.train): line.train.release_distant_platform_camera()
    var platform: Node3D=line.train.retained_platform_station() if is_instance_valid(line.train) else null
    var player_station: int=player_station_index()
    for record in line.stations:
        var index: int=int(record.index)
        var low: float=float(record.low)
        var high: float=float(record.high)
        var reasons: int=0
        if not virtual_parked and is_instance_valid(line.train) and _z+bounds.end.z>=low and _z+bounds.position.z<=high:
            reasons|=TRAIN
        if is_instance_valid(line.passengers) and (not line.passengers.can_unload_platform(index) or not line.gameplay.timetable.can_unload_platform(index)): reasons|=TRAIN
        if index==player_station:
            reasons|=PLAYER
        var visible_from_train:=false
        if not virtual_parked and is_instance_valid(line.train) and _scene_bounds.has(index) and is_instance_valid(line.train.camera):
            var actual: AABB=_scene_bounds[index]
            var camera: Camera3D=line.train.camera
            var eye: Vector3=camera.global_position
            var nearest:=Vector3(clampf(eye.x,actual.position.x,actual.end.x),clampf(eye.y,actual.position.y,actual.end.y),clampf(eye.z,actual.position.z,actual.end.z))
            visible_from_train=eye.distance_to(nearest)<=float(camera.far)
        if visible_from_train or index==player_station or (is_instance_valid(platform) and platform==station(index)):
            reasons|=CAMERA
        if reasons!=0:
            _retention[index]=reasons
            _wanted[index]=true
    _dispatch_priorities.clear()
    if is_instance_valid(line.gameplay):
        for request in line.gameplay.timetable.streaming_requests():
            var index: int=int(request.index)
            if index<0 or index>=line.stations.size(): continue
            if player_station>=0 and index!=player_station: continue
            if player_station<0 and index!=_next_index and not _retention.has(index): continue
            _wanted[index]=true
            _dispatch_priorities[index]=maxf(float(_dispatch_priorities.get(index,0.0)),float(request.priority))
    if not _busy:
        _busy=true
        call_deferred("_pump")

func _pump() -> void:
    # A single pump serializes pack downloads, instantiation and eviction.
    # Scene-tree mutation is exclusively on the main thread.
    # A deferred pump queued before the role menu became idle must not start
    # a station download. Passenger startup explicitly sets _startup_target.
    if is_instance_valid(line.gameplay) and not line.gameplay.running and not line.gameplay._starting and _startup_target<0:
        _busy=false
        return
    while is_inside_tree():
        # An awaited download may finish after gameplay has returned to the
        # role menu. Re-evaluate ownership before evicting or loading modules.
        if is_instance_valid(line.gameplay) and not line.gameplay.running and not line.gameplay._starting and _startup_target<0:
            _wanted.clear()
            _retention.clear()
            break
        for key in instances.keys():
            var index: int=int(key)
            refresh() # Re-evaluate TRAIN/PLAYER/CAMERA after every awaited disposal.
            if _wanted.has(index): continue
            if is_instance_valid(line.passengers) and (not line.passengers.can_unload_platform(index) or not line.gameplay.timetable.can_unload_platform(index)): continue
            var node: Node3D=station(index)
            station_unloading.emit(index,node)
            instances.erase(index)
            _scene_bounds.erase(index)
            _states[index]=State.NOT_REQUESTED
            _attempts.erase(index)
            _errors.erase(index)
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
            if is_service_ready(index) or Time.get_ticks_msec()<int(_retry_at.get(index,0)): continue
            if int(_attempts.get(index,0))>=int(_settings.get("max_attempts",3)): continue
            var distance: float=absf(_z-float(line.stations[index].stop_z))
            if index==_next_index: distance-=10000.0
            if index==_current_index and not is_service_ready(index): distance-=50000.0
            distance-=float(_dispatch_priorities.get(index,0.0))
            if int(_retention.get(index,0))&PLAYER: distance-=100000.0
            if (_z-float(line.stations[index].stop_z))*float(_direction)<0.0: distance*=1.15
            if distance<priority:
                priority=distance
                next=index
        if next<0: break
        _attempts[next]=int(_attempts.get(next,0))+1
        var store: Node=get_tree().root.get_node_or_null("MetroStaticResourceStore")
        if is_instance_valid(store): store.set_meta("station_preparing",true)
        var success: bool=await _load_station(next)
        # The store may first be created by the new station's _ready().
        store=get_tree().root.get_node_or_null("MetroStaticResourceStore")
        if is_instance_valid(store): store.set_meta("station_preparing",false)
        if not success:
            # An initial player request reports failure to the role menu.
            # Only an explicit retry restarts it; normal route streaming retries.
            _retry_at[next]=9223372036854775807 if next==_startup_target else Time.get_ticks_msec()+int(float(_settings.retry_seconds)*1000.0)
            if int(_attempts[next])>=int(_settings.get("max_attempts",3)):
                retry_required.emit(next,station_error(next))
        else:
            _retry_at.erase(next)
            if not is_loaded(next):
                # Cancellation on reversal/menu selection is not a failed try.
                _attempts.erase(next)
                _states[next]=State.NOT_REQUESTED
        # Position/direction may have changed during a long HTTP/resource load.
        refresh()
    _busy=false

func _load_station(index: int) -> bool:
    var record: Dictionary=line.stations[index]
    var id: String=str(record.module_id)
    _errors.erase(index)
    if is_loaded(index): return await _prepare_service(index,station(index))
    _states[index]=State.PACK_LOADING
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
    _states[index]=State.PACK_READY
    var prepared_data: Dictionary=Catalog.prepared_station_data(id)
    _states[index]=State.RESOURCE_PREPARING
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
    _states[index]=State.SCENE_CREATING
    var node: Node3D=Catalog.create_module(id,prepared_data) if prepared else scene.instantiate() as Node3D
    scene=null
    if node==null:
        if is_instance_valid(pack_loader): pack_loader.release_module_resources(id)
        _loading_id=""
        return _load_failed(index,"Не удалось создать станцию: "+id)
    node.set_meta("metro_station_loading",true)
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
        var walking_lite: Dictionary=await WalkLite.new().describe_station(node)
        node.set_meta("metro_walk_lite_data",walking_lite)
    if not _wanted.has(index):
        budget.cancel()
        await _dispose_station(node)
        _building_budget=null
        if is_instance_valid(pack_loader): pack_loader.release_module_resources(id)
        _loading_id=""
        return true
    var geometry: AABB=await _measure_station(node,budget)
    if geometry.size.length_squared()<=0.001:
        budget.cancel()
        await _dispose_station(node)
        _building_budget=null
        if is_instance_valid(pack_loader): pack_loader.release_module_resources(id)
        _loading_id=""
        return _load_failed(index,"Нет обязательной геометрии станции: "+id)
    _scene_bounds[index]=geometry
    _building_budget=null
    budget.release_sources()
    node.process_mode=active_mode
    node.show()
    instances[index]=node
    _states[index]=State.SCENE_READY
    station_loaded.emit(index,node)
    # Only scene/agent owners retain decoded resources; never keep PackedScenes.
    if is_instance_valid(pack_loader): pack_loader.release_module_resources(id)
    await get_tree().process_frame
    var seconds: float=float(Time.get_ticks_msec()-started)/1000.0
    _load_seconds=clampf(maxf(seconds,_load_seconds*0.8),2.0,90.0)
    _loading_id=""
    return await _prepare_service(index,node)

func _prepare_service(index: int, node: Node3D) -> bool:
    var walking: Dictionary=node.get_meta("metro_walk_lite_data",{})
    if not WalkLite.verify_floor(walking):
        return _load_failed(index,"Нет подтверждённых опорных плит пола: "+str(line.stations[index].module_id))
    _states[index]=State.SCENE_READY
    var deadline: int=Time.get_ticks_msec()+int(float(_settings.get("service_timeout_seconds",180.0))*1000.0)
    while is_inside_tree() and is_instance_valid(node):
        if not _wanted.has(index): return true
        if is_instance_valid(line.passengers):
            line.prepare_station_service(index,node)
            var failure: String=line.passengers.platform_error(index)
            if not failure.is_empty(): return _load_failed(index,failure)
            if line.passengers.platform_navigation_ready(index) and line.passengers.platform_ready(index):
                _states[index]=State.SERVICE_READY
                _errors.erase(index)
                _retry_at.erase(index)
                loading_changed.emit("")
                refresh()
                return true
        if Time.get_ticks_msec()>=deadline:
            return _load_failed(index,"Не завершена подготовка обслуживания: "+str(line.stations[index].module_id)+"; повторите загрузку станции")
        await get_tree().process_frame
    return false

func _measure_station(root: Node3D, budget: RefCounted) -> AABB:
    var measured:=AABB()
    var found:=false
    var stack: Array[Node]=[root]
    while not stack.is_empty():
        var node: Node=stack.pop_back()
        var bounds:=AABB()
        var mesh_node:=false
        if node is MeshInstance3D and node.mesh!=null:
            bounds=node.get_aabb()
            mesh_node=true
        elif node is MultiMeshInstance3D and node.multimesh!=null:
            bounds=node.get_aabb()
            mesh_node=true
        if mesh_node and bounds.size.length_squared()>0.000001:
            bounds=(node as Node3D).global_transform*bounds
            measured=measured.merge(bounds) if found else bounds
            found=true
        for child in node.get_children(): stack.append(child)
        if not await budget.checkpoint(): return AABB()
    return measured

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
    _scene_bounds.clear()
    _states.clear()
    var store: Node=get_tree().root.get_node_or_null("MetroStaticResourceStore")
    if is_instance_valid(store): store.set_meta("station_preparing",false)
    _wanted.clear()

