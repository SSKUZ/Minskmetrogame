extends "res://scripts/passengers/passenger_manager.gd"
## One shared seat/door reservation system for the whole train and all platforms.
## World-origin platform frame keeps the existing boarding paths in their own units.
var _line: Node3D
var _game: Node3D
var _platforms: Dictionary = {}
var _active_visit := ""
var _active_station := -1
var _travel_direction := 1

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
    if _platforms.has(index): return
    var nav=Navigation.new()
    nav.platform=Rect2(-10.0,float(station.low)+0.5,9.1,float(station.high)-float(station.low)-1.0)
    for shape in instance.find_children("*","CollisionShape3D",true,false):
        var collider := shape as CollisionShape3D
        if not collider.shape is BoxShape3D: continue
        var size: Vector3=(collider.shape as BoxShape3D).size
        var box: AABB=collider.global_transform*AABB(-size*0.5,size)
        if box.end.y<1.30 or box.position.y>2.9 or box.size.x>8.0 or box.size.z>18.0: continue
        nav.obstacles.append(Rect2(box.position.x,box.position.z,box.size.x,box.size.z))
    _platforms[index]={"navigation":nav}
    if _platform_states.has(index):
        for saved in _platform_states[index]:
            var scene: PackedScene=load(str(saved.model_path)) as PackedScene
            if scene==null: continue
            var person=Spawner.Agent.new()
            add_child(person)
            person.setup(scene,int(saved.id))
            person.id=int(saved.id)
            person.group_id=int(saved.group_id)
            person.walk_speed=float(saved.walk_speed)
            person.wants_board=bool(saved.wants_board)
            person.position=Vector3(float(saved.position[0]),float(saved.position[1]),float(saved.position[2]))
            person.rotation.y=float(saved.heading)
            person.navigation=nav
            person.set_meta("origin_station",index)
            person.set_meta("travel_destination",int(saved.travel_destination))
            person.set_meta("stream_model",str(saved.model_path))
            agents.append(person)
        _platform_states.erase(index)
    else:
        var spawn_nav=Navigation.new()
        for obstacle in nav.obstacles:
            spawn_nav.obstacles.append(Rect2(obstacle.position-Vector2(0,float(station.root_z)),obstacle.size))
        var people: Array=spawner.spawn(self,int(_line.layout.passengers_per_platform),spawn_nav,layout.doors)
        for i in range(people.size()):
            var person=people[i]
            person.id=index*1000+i
            if person.group_id>=0: person.group_id+=index*100
            person.position.z+=float(station.root_z)
            person.navigation=nav
            person.wants_board=i<int(_line.layout.boarding_per_platform)
            person.set_meta("origin_station",index)
            person.set_meta("travel_destination",-1)
            person.set_meta("stream_model",str(person.visual.scene_file_path))
            agents.append(person)
        # Existing visual instances own the resources; the spawner must not retain
        # PackedScenes for models no longer used on a platform or in the train.
        spawner.cache.clear()

func can_unload_platform(index: int) -> bool:
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

func update_service(station: Dictionary, velocity: float, change: float) -> void:
    speed=velocity
    acceleration=change
    if station.is_empty():
        exchange_enabled=false
        return
    var index: int=int(station.index)
    if not _platforms.has(index):
        exchange_enabled=false
        return
    var stopped: bool=velocity<0.05 and absf(float(_game.distance)-float(station.stop_z))<=0.5
    var open: bool=float(_game.door_system.side_open[-1])>=0.99
    exchange_enabled=stopped and open
    if not exchange_enabled: return
    var direction: int=int(_game.cab_runtime.direction)
    var visit := "%d:%d:%s" % [index,direction,str(_game.info_binding.audio.info.visit_id)]
    if visit==_active_visit: return
    _active_visit=visit
    _active_station=index
    _travel_direction=direction
    navigation=_platforms[index].navigation
    boarding.navigation=navigation
    boarding.exchange_active=false
    boarding.opened=false
    var alighters: Array=[]
    var waiters: Array=[]
    for a in agents:
        if a.space=="train":
            a.navigation=navigation
            var target: int=int(a.get_meta("travel_destination",index))
            if target==index or index==0 or index==_line.stations.size()-1: alighters.append(a)
        elif int(a.get_meta("origin_station",-1))==index and a.wants_board and a.state in ["waiting","waitingNextTrain"]:
            a.navigation=navigation
            var target := clampi(index+direction*(1+a.id%3),0,_line.stations.size()-1)
            if target==index: continue
            a.set_meta("travel_destination",target)
            waiters.append(a)
    for a in alighters: a.set_meta("travel_destination",index)
    # Discard only stale platform queue paths, retaining all onboard reservations.
    for door in layout.doors:
        for person in door.enter:
            if person.space=="platform":
                person.path.clear()
                person.detour.clear()
                person.state="waiting"
        door.enter.clear()
    boarding.request_alight(alighters)
    boarding.assign(waiters,0.0)

func guard_doors(doors: Node) -> void:
    if speed<0.05 and not doors_clear():
        doors.side_targets[-1]=true
        doors.target_open=true

func _physics_process(delta: float) -> void:
    super._physics_process(delta)
    for a in agents:
        if a.space=="train":
            a.set_meta("was_on_train",true)
        elif a.state in ["leaving","waitingNextTrain"] and bool(a.get_meta("was_on_train",false)):
            a.wants_board=false
            a.set_meta("origin_station",_active_station)
            a.set_meta("travel_destination",_active_station)
            a.set_meta("was_on_train",false)
