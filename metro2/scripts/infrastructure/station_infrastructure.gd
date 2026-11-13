extends Node3D
## Shared station equipment. Four portal clocks; independent intervals per track.
@export var station_id := "station"
@export var clock_height := 3.93
@export var track_min_z := -20.888
@export var track_max_z := 100.112
@export var portal_min_z := -12.888
@export var portal_max_z := 92.112
const TRACKS := [0.992,-11.732]
const DIGITS := [0x3f,0x06,0x5b,0x4f,0x66,0x6d,0x7d,0x07,0x7f,0x6f]
var _displays: Array[MultiMesh] = []
var _last_departures: Array[int] = [0,0]
var _observations: Dictionary = {}
var _last_second := -1
var _tick := 0.0
var _amber := Color(1.0,0.61,0.05)

func _ready() -> void:
    _contact_rails()
    var saved := ConfigFile.new()
    if saved.load("user://station_departures.cfg") == OK:
        for track in range(2):
            var value := int(saved.get_value(station_id,str(track),0))
            if value <= int(Time.get_unix_time_from_system()): _last_departures[track]=value
    for track in range(2):
        for end in range(2): _clock(track,end)

func _mat(color: Color,metallic: float=0.0) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color=color
    m.metallic=metallic
    m.roughness=0.6
    return m

func _box(size: Vector3,p: Vector3,mat: Material) -> void:
    var mesh := BoxMesh.new()
    mesh.size=size
    mesh.material=mat
    var n := MeshInstance3D.new()
    n.mesh=mesh
    n.position=p
    add_child(n)

func _contact_rails() -> void:
    var conductor := _mat(Color("#555b5a"),0.78)
    var cover := _mat(Color("#594d39"))
    var porcelain := _mat(Color("#c5c3b0"))
    var length := track_max_z-track_min_z
    var middle := (track_max_z+track_min_z)*0.5
    for track in range(2):
        var side := 1.0 if track==0 else -1.0
        var x: float = TRACKS[track]+side*1.48
        _box(Vector3(0.085,0.12,length),Vector3(x,0.225,middle),conductor)
        _box(Vector3(0.13,0.035,length),Vector3(x,0.15,middle),conductor)
        _box(Vector3(0.27,0.055,length),Vector3(x,0.325,middle),cover)
        _box(Vector3(0.025,0.16,length),Vector3(x+side*0.145,0.245,middle),cover)
        var mesh := CylinderMesh.new()
        mesh.top_radius=0.07
        mesh.bottom_radius=0.07
        mesh.height=0.16
        mesh.radial_segments=10
        mesh.material=porcelain
        var mm := MultiMesh.new()
        mm.transform_format=MultiMesh.TRANSFORM_3D
        mm.mesh=mesh
        mm.instance_count=int(ceil(length/2.0))
        for i in range(mm.instance_count): mm.set_instance_transform(i,Transform3D(Basis(),Vector3(x,0.025,track_min_z+float(i)*2.0)))
        var n := MultiMeshInstance3D.new()
        n.name="ContactRailInsulators%d" % track
        n.multimesh=mm
        add_child(n)

func _clock(track: int,end: int) -> void:
    var panel := Node3D.new()
    panel.name="Track%dPortal%dClock" % [track+1,end+1]
    panel.position=Vector3(TRACKS[track],clock_height,portal_min_z+0.2 if end==0 else portal_max_z-0.2)
    panel.rotation.y=0.0 if end==0 else PI
    add_child(panel)
    var case_mesh := BoxMesh.new()
    case_mesh.size=Vector3(2.30,0.46,0.15)
    case_mesh.material=_mat(Color("#111315"))
    var case_node := MeshInstance3D.new()
    case_node.mesh=case_mesh
    panel.add_child(case_node)
    var material := _mat(Color.WHITE)
    material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
    material.vertex_color_use_as_albedo=true
    var bar := BoxMesh.new()
    bar.size=Vector3.ONE
    bar.material=material
    var mm := MultiMesh.new()
    mm.transform_format=MultiMesh.TRANSFORM_3D
    mm.use_colors=true
    mm.mesh=bar
    mm.instance_count=76
    var centers := [-0.96,-0.79,-0.54,-0.37,-0.12,0.05,0.43,0.60,0.85,1.02]
    var points := [Vector2(0,0.13),Vector2(0.055,0.065),Vector2(0.055,-0.065),Vector2(0,-0.13),Vector2(-0.055,-0.065),Vector2(-0.055,0.065),Vector2.ZERO]
    for digit in range(10):
        for segment in range(7):
            var size := Vector3(0.10,0.024,0.012) if segment in [0,3,6] else Vector3(0.022,0.10,0.012)
            var p: Vector2=points[segment]
            mm.set_instance_transform(digit*7+segment,Transform3D(Basis.from_scale(size),Vector3(float(centers[digit])+p.x,p.y,0.085)))
    for colon in range(3):
        var x: float=[-0.665,-0.245,0.725][colon]
        for dot in range(2):
            mm.set_instance_transform(70+colon*2+dot,Transform3D(Basis.from_scale(Vector3(0.022,0.022,0.012)),Vector3(x,0.045 if dot==0 else -0.045,0.085)))
            mm.set_instance_color(70+colon*2+dot,_amber)
    var digits := MultiMeshInstance3D.new()
    digits.name="MinskTimeAndDepartureInterval"
    digits.multimesh=mm
    digits.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    panel.add_child(digits)
    _displays.append(mm)

## Public hook for future dispatch/passenger systems. track is 1 or 2.
func record_departure(track: int,unix_time: int=0) -> void:
    if track<1 or track>2: return
    _last_departures[track-1]=unix_time if unix_time>0 else int(Time.get_unix_time_from_system())
    var saved := ConfigFile.new()
    saved.load("user://station_departures.cfg")
    saved.set_value(station_id,str(track-1),_last_departures[track-1])
    saved.save("user://station_departures.cfg")
    _last_second=-1

func _observe_trains() -> void:
    var candidates: Array[Node] = get_tree().get_nodes_in_group("metro_trains")
    var ancestor: Node=get_parent()
    while ancestor!=null:
        var train := ancestor.get_node_or_null("PlayerTrainPlacement")
        if train!=null and not candidates.has(train): candidates.append(train)
        ancestor=ancestor.get_parent()
    var now_ms := Time.get_ticks_msec()
    for node in candidates:
        if not node is Node3D: continue
        var train := node as Node3D
        var p := to_local(train.global_position)
        var track := 0 if absf(p.x-TRACKS[0])<absf(p.x-TRACKS[1]) else 1
        if absf(p.x-TRACKS[track])>2.0: continue
        var id := train.get_instance_id()
        var state: Dictionary=_observations.get(id,{"p":p,"time":now_ms,"armed":false,"stopped":0.0})
        var dt := maxf(0.001,float(now_ms-int(state.time))/1000.0)
        var speed := p.distance_to(state.p)/dt
        var length := float(train.get_meta("train_length",79.224))
        var axis := global_basis.inverse()*train.global_basis.z
        var rear := p.z+axis.z*length
        var lower := minf(p.z,rear)
        var upper := maxf(p.z,rear)
        var overlaps := upper>portal_min_z and lower<portal_max_z
        if overlaps and speed<0.05:
            state.stopped=float(state.stopped)+dt
            if float(state.stopped)>1.0: state.armed=true
        else: state.stopped=0.0
        if bool(state.armed) and not overlaps:
            record_departure(track+1)
            state.armed=false
        state.p=p
        state.time=now_ms
        _observations[id]=state

func _process(delta: float) -> void:
    _tick+=delta
    if _tick<0.25: return
    _tick=0.0
    _observe_trains()
    var now := int(Time.get_unix_time_from_system())
    if now==_last_second: return
    _last_second=now
    var date := Time.get_datetime_dict_from_unix_time(now+10800)
    for track in range(2):
        var values: Array[int]=[int(date.hour)/10,int(date.hour)%10,int(date.minute)/10,int(date.minute)%10,int(date.second)/10,int(date.second)%10,-1,-1,-1,-1]
        if _last_departures[track]>0:
            var elapsed := maxi(0,now-_last_departures[track])
            var minutes := mini(99,elapsed/60)
            values[6]=minutes/10
            values[7]=minutes%10
            values[8]=(elapsed%60)/10
            values[9]=elapsed%10
        for end in range(2):
            var mm := _displays[track*2+end]
            for digit in range(10):
                var bits: int=DIGITS[values[digit]] if values[digit]>=0 else 0x40
                for segment in range(7): mm.set_instance_color(digit*7+segment,_amber if (bits & (1<<segment))!=0 else Color(0.055,0.035,0.015))
