extends "res://scripts/passengers/passenger_manager.gd"
## One shared seat/door reservation system for the whole train and all platforms.
## World-origin platform frame keeps the existing boarding paths in their own units.
var _line: Node3D
var _game: Node3D
var _platforms: Dictionary = {}
var _active_visit := ""
var _active_station := -1
var _travel_direction := 1
var _simulation: Array=[]
var _activity_clock := 0.0
var _spaces: Dictionary = {}
var _was_stopped := false
var _visit_serial := 0
var _next_assignment := 0
var _next_probe := 0
var _probe_index := -1
var _probe_z := NAN
var _next_person_id := 0
var _station_calls: Dictionary={}
const BuildBudget = preload("res://modules/line/build_budget.gd")

func initialize_line(line: Node3D, game: Node3D) -> void:
    _line=line
    _game=game
    layout.configure(game.train,game.door_system)
    boarding.layout=layout
    boarding.platform_root=self
    boarding.navigation=navigation

# Dormant platforms retain only portable scalar passenger descriptors, not Nodes.
var _platform_states: Dictionary = {}

func add_platform(station: Dictionary, instance: Node3D) -> void:
    var index: int=int(station.index)
    if _platforms.has(index):
        while _platforms.has(index) and not bool(_platforms[index].get("ready",true)):
            await get_tree().process_frame
        return
    var budget=BuildBudget.new(self,2000)
    var platform_near: bool=absf(float(_game.distance)-float(station.stop_z))<340.0 or absf(_game.camera.global_position.z-float(station.stop_z))<340.0
    var nav=Navigation.new()
    var fallback:=Rect2(-10.37,float(station.root_z)-12.888,10.0,105.0)
    _platforms[index]={"navigation":nav,"ready":false}
    await nav.read_station(instance,budget,fallback)
    if _platform_states.has(index) and not _platform_states[index].is_empty():
        for saved in _platform_states[index]:
            if not await budget.checkpoint(): return
            var model_path: String=str(saved.model_path)
            if not spawner.cache.has(model_path): spawner.cache[model_path]=load(model_path)
            var scene: PackedScene=spawner.cache[model_path] as PackedScene
            if scene==null: continue
            var person=Spawner.Agent.new()
            add_child(person)
            person.setup(scene,int(saved.id))
            person.id=int(saved.id)
            person.group_id=int(saved.group_id)
            person.walk_speed=float(saved.walk_speed)
            person.wants_board=bool(saved.wants_board)
            person.position=nav.free_point(Vector3(float(saved.position[0]),float(saved.position[1]),float(saved.position[2])))
            person.rotation.y=float(saved.heading)
            person.navigation=nav
            person.set_meta("origin_station",index)
            person.set_meta("travel_destination",int(saved.travel_destination))
            person.set_meta("stream_model",str(saved.model_path))
            person.process_mode=Node.PROCESS_MODE_INHERIT if platform_near else Node.PROCESS_MODE_DISABLED
            agents.append(person)
        _platform_states.erase(index)
    else:
        var spawn_nav=Navigation.new()
        spawn_nav.platform=Rect2(nav.platform.position-Vector2(0,float(station.root_z)),nav.platform.size)
        spawn_nav.height=nav.height
        for obstacle in nav.obstacles:
            spawn_nav.obstacles.append(Rect2(obstacle.position-Vector2(0,float(station.root_z)),obstacle.size))
        var people: Array=[]
        var cohort: int=_next_person_id
        var count: int=int(_line.layout.passengers_per_platform)
        for i in range(count):
            if not await budget.checkpoint(): return
            var person=spawner.spawn_one(self,i,count,spawn_nav,layout.doors,_next_person_id)
            _next_person_id+=1
            people.append(person)
            if person.group_id>=0: person.group_id+=cohort
            person.position.z+=float(station.root_z)
            person.navigation=nav
            person.wants_board=index==0 or i<int(_line.layout.boarding_per_platform)
            person.set_meta("origin_station",index)
            person.set_meta("travel_destination",-1)
            person.set_meta("stream_model",str(person.visual.scene_file_path))
            person.process_mode=Node.PROCESS_MODE_INHERIT if platform_near else Node.PROCESS_MODE_DISABLED
            agents.append(person)
        # Existing visual instances own the resources; the spawner must not retain
        # PackedScenes for models no longer used on a platform or in the train.
    var platform_people: Array=[]
    for person in agents:
        if person.space=="platform" and int(person.get_meta("origin_station",-1))==index: platform_people.append(person)
    spawner.finish_groups(platform_people)
    spawner.cache.clear()
    _platforms[index].ready=true
    _next_probe=0
    _refresh_activity()

func platform_ready(index: int) -> bool:
    return _platforms.has(index) and bool(_platforms[index].get("ready",false))

func complete() -> bool:
    var station: Dictionary=_line.path.nearest_station(float(_game.distance))
    if not station.is_empty() and _platforms.has(int(station.index)) and not bool(_platforms[int(station.index)].get("ready",true)):
        return false
    if exchange_enabled:
        var terminal: bool=(_active_station==0 and _travel_direction<0) or (_active_station==_line.stations.size()-1 and _travel_direction>0)
        var can_board: bool=_active_station+_travel_direction>=0 and _active_station+_travel_direction<_line.stations.size()
        var capacity_available: bool=layout.places.any(func(place):return not place.used and layout.doors.any(func(d):return d.car==place.car and layout.usable(d)))
        for person in agents:
            if person.space=="train" and str(person.get_meta("boarded_visit",""))!=_active_visit:
                var target: int=int(person.get_meta("travel_destination",_active_station))
                if terminal or (target>=0 and (_active_station-target)*_travel_direction>=0): return false
            elif can_board and capacity_available and person.space=="platform" and person.wants_board and int(person.get_meta("origin_station",-1))==_active_station: return false
    return super.complete()

func can_unload_platform(index: int) -> bool:
    if _platforms.has(index) and not bool(_platforms[index].get("ready",true)): return false
    if index!=_active_station: return true
    if not doors_clear(): return false
    for door in layout.doors:
        if not door.exit.is_empty(): return false
    for person in agents:
        if person.space=="train" and person.state in ["standingUp","exitQueued"]: return false
    return true

func remove_platform(index: int) -> void:
    if not _platforms.has(index) or not can_unload_platform(index): return
    var old_navigation: RefCounted=_platforms[index].navigation
    var saved: Array=[]
    for person in agents.duplicate():
        if person.space=="train":
            # Seat/car/destination and boarding state stay untouched.
            if person.navigation==old_navigation: person.navigation=Navigation.new()
            continue
        if int(person.get_meta("origin_station",-1))!=index: continue
        var model_path: String=str(person.get_meta("stream_model",""))
        if model_path.is_empty(): model_path=str(Spawner.MODELS[posmod(person.id,Spawner.MODELS.size())])
        saved.append({"id":person.id,"model_path":model_path,"group_id":person.group_id,
            "walk_speed":person.walk_speed,"wants_board":person.wants_board,
            "travel_destination":int(person.get_meta("travel_destination",-1)),
            "position":[person.position.x,person.position.y,person.position.z],"heading":person.rotation.y})
        for door in layout.doors:
            door.enter.erase(person)
            door.exit.erase(person)
            if door.active==person: door.active=null
        agents.erase(person)
        _spaces.erase(person.id)
        person.path.clear()
        person.detour.clear()
        person.navigation=null
        person.car=null
        person.slot.clear()
        person.queue_free()
    _platform_states[index]=saved
    if navigation==old_navigation: navigation=Navigation.new()
    if boarding.navigation==old_navigation: boarding.navigation=navigation
    _platforms.erase(index)
    if _active_station==index:
        exchange_enabled=false
        boarding.exchange_active=false
        boarding.opened=false
        _active_station=-1
        _active_visit=""
    spawner.cache.clear()
    _refresh_activity()

func update_service(station: Dictionary, velocity: float, change: float) -> void:
    speed=velocity
    acceleration=change
    var stopped: bool=absf(velocity)<0.05
    if not stopped:
        exchange_enabled=false
        if _was_stopped:
            boarding.cancel_waiters()
            # Unstarted exits stay safely aboard when the driver departs.
            for d in layout.doors:
                for person in d.exit.duplicate():
                    if person==d.active: continue
                    person.state="seated" if bool(person.slot.get("seated",false)) else "riding"
                    person.animation.play("Sit idle (chair)" if person.state=="seated" else "Idle")
                    person.door_id=-1
                    d.exit.erase(person)
        _was_stopped=false
        return
    if not _was_stopped: _visit_serial+=1
    _was_stopped=true
    var direction: int=int(_game.cab_runtime.direction)
    if direction!=0: _travel_direction=direction
    if Time.get_ticks_msec()>=_next_probe or not is_finite(_probe_z) or absf(float(_game.distance)-_probe_z)>0.02:
        _next_probe=Time.get_ticks_msec()+250
        _probe_z=float(_game.distance)
        _probe_index=-1
        var candidates: Array=[]
        if not station.is_empty(): candidates.append(int(station.index))
        for key in _platforms:
            if not candidates.has(int(key)): candidates.append(int(key))
        for candidate in candidates:
            if not platform_ready(candidate): continue
            var nav: RefCounted=_platforms[candidate].navigation
            if layout.select_platform(nav.platform_area,nav.height,nav)>0:
                _probe_index=candidate
                break
    var index: int=_probe_index if platform_ready(_probe_index) else -1
    exchange_enabled=index>=0 and layout.doors.any(func(d):return layout.usable(d))
    if not exchange_enabled: return
    var visit := "%d:%d:%d" % [index,_travel_direction,_visit_serial]
    if visit!=_active_visit:
        boarding.cancel_waiters()
        _active_visit=visit
        _active_station=index
        navigation=_platforms[index].navigation
        boarding.navigation=navigation
        boarding.exchange_active=false
        boarding.opened=false
        _next_assignment=0
        if int(_station_calls.get(index,-1))!=_visit_serial:
            if _station_calls.has(index):
                # Existing bystanders can take the next service in either
                # direction. People alighting in this stop do not board again.
                for person in agents:
                    if person.space=="platform" and int(person.get_meta("origin_station",-1))==index and int(person.get_meta("alighted_call",-1))!=_visit_serial:
                        person.wants_board=true
            _station_calls[index]=_visit_serial
    if Time.get_ticks_msec()<_next_assignment: return
    _next_assignment=Time.get_ticks_msec()+750
    var alighters: Array=[]
    var waiters: Array=[]
    var terminal: bool=(index==0 and _travel_direction<0) or (index==_line.stations.size()-1 and _travel_direction>0)
    for person in agents:
        if person.space=="train":
            person.navigation=navigation
            if str(person.get_meta("boarded_visit",""))==_active_visit: continue
            var target: int=int(person.get_meta("travel_destination",index))
            if terminal or (target>=0 and (index-target)*_travel_direction>=0):
                person.set_meta("travel_destination",index)
                alighters.append(person)
        elif int(person.get_meta("origin_station",-1))==index and person.wants_board and person.state in ["waiting","waitingNextTrain"]:
            person.navigation=navigation
            var target: int=clampi(index+_travel_direction*(1+person.id%3),0,_line.stations.size()-1)
            if target==index: continue
            person.set_meta("travel_destination",target)
            waiters.append(person)
    boarding.request_alight(alighters)
    boarding.assign(waiters,0.0)

func guard_doors(doors: Node) -> void:
    if absf(speed)>=0.05: return
    for d in layout.doors:
        if d.active==null: continue
        doors.side_targets[int(d.side)]=true
        doors.target_open=true

func simulation_agents() -> Array:
    return _simulation

func _refresh_activity() -> void:
    _simulation.clear()
    var camera_z: float=_game.camera.global_position.z
    var train_z: float=float(_game.distance)
    for person in agents:
        var active: bool=person.space=="train" or person.state in ["boarding","alighting","returning"]
        if not active:
            var index: int=int(person.get_meta("origin_station",-1))
            if index==_active_station: active=true
            if index>=0 and index<_line.stations.size():
                var stop: float=float(_line.stations[index].stop_z)
                active=active or absf(train_z-stop)<340.0 or absf(camera_z-stop)<340.0
        var mode: int=Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
        if person.process_mode!=mode: person.process_mode=mode
        if active: _simulation.append(person)

func _physics_process(delta: float) -> void:
    _activity_clock-=delta
    if _activity_clock<=0.0:
        _activity_clock=0.2
        _refresh_activity()
    super._physics_process(delta)
    for person in _simulation:
        var old: String=str(_spaces.get(person.id,"platform"))
        if old==str(person.space): continue
        _spaces[person.id]=str(person.space)
        if person.space=="train":
            person.set_meta("was_on_train",true)
            person.set_meta("boarded_visit",_active_visit)
        elif person.state in ["leaving","waitingNextTrain"] and bool(person.get_meta("was_on_train",false)):
            person.wants_board=false
            person.set_meta("origin_station",_active_station)
            person.set_meta("travel_destination",_active_station)
            person.set_meta("was_on_train",false)
            person.set_meta("alighted_call",_visit_serial)

func retire_virtual_service() -> void:
    # Only the offscreen, unoccupied consist is reused. Platform cohorts persist.
    boarding.cancel_waiters()
    for door in layout.doors:
        door.enter.clear()
        door.exit.clear()
        door.active=null
    for person in agents.duplicate():
        if person.space!="train": continue
        if not person.slot.is_empty(): layout.release(person.slot)
        agents.erase(person)
        _simulation.erase(person)
        _spaces.erase(person.id)
        person.queue_free()
    boarding.exchange_active=false
    boarding.opened=false
    _active_visit=""
    _active_station=-1
    _was_stopped=false
    _next_probe=0
