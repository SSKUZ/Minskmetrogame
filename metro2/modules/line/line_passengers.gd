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
    for station in line.stations:
        var nav=Navigation.new()
        nav.platform=Rect2(-10.0,float(station.low)+0.5,9.1,float(station.high)-float(station.low)-1.0)
        # Honour authored physical stairs, columns and furniture where colliders exist.
        for shape in station.node.find_children("*","CollisionShape3D",true,false):
            var collider := shape as CollisionShape3D
            if not collider.shape is BoxShape3D: continue
            var size: Vector3=(collider.shape as BoxShape3D).size
            var box := collider.global_transform*AABB(-size*0.5,size)
            if box.end.y<1.30 or box.position.y>2.9 or box.size.x>8.0 or box.size.z>18.0: continue
            nav.obstacles.append(Rect2(box.position.x,box.position.z,box.size.x,box.size.z))
        _platforms[int(station.index)]={"navigation":nav,"station":station}
        var people: Array=spawner.spawn(self,int(line.layout.passengers_per_platform),nav,layout.doors)
        for a in people:
            var number: int=agents.size()
            a.id=number
            if a.group_id>=0: a.group_id+=int(station.index)*100
            a.position.z+=float(station.root_z)
            a.navigation=nav
            a.wants_board=people.find(a)<int(line.layout.boarding_per_platform)
            a.set_meta("origin_station",int(station.index))
            a.set_meta("travel_destination",-1)
            agents.append(a)
        await get_tree().process_frame
    boarding.navigation=navigation

func update_service(station: Dictionary, velocity: float, change: float) -> void:
    speed=velocity
    acceleration=change
    if station.is_empty():
        exchange_enabled=false
        return
    var index: int=int(station.index)
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
    boarding.request_alight(alighters)
    # Clear only platform queues left by a past completed visit.
    for door in layout.doors: door.enter.clear()
    boarding.assign(waiters,0.0)

func guard_doors(doors: Node) -> void:
    if speed<0.05 and not doors_clear():
        doors.side_targets[-1]=true
        doors.target_open=true

func _physics_process(delta: float) -> void:
    super._physics_process(delta)
    for a in agents:
        if a.space=="platform" and a.state in ["leaving","waitingNextTrain"] and int(a.get_meta("travel_destination",-1))==_active_station:
            a.wants_board=false
            a.set_meta("origin_station",_active_station)
