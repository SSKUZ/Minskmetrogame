extends Node3D
const Builder = preload("res://scripts/depot/depot_builder.gd")
const Route = preload("res://scripts/depot/route_profile.gd")
var b: Builder
var rail: Material
var side_steel: Material
var ties: Material
var ballast: Material
var clip: Material
var concrete: Material
var yellow: Material

func _ready() -> void:
    b = Builder.new(self)
    rail = b.mat("PolishedRunningRail",Color("#8d9595"),0.27,0.86)
    side_steel = b.mat("RailWeb",Color("#544941"),0.76,0.65)
    ties = b.mat("DarkSleepers",Color("#3a342c"),0.96,0.0,3.0)
    ballast = b.mat("Ballast",Color("#69665b"),0.99,0.0,3.0)
    clip = b.mat("Fastenings",Color("#394044"),0.70,0.65)
    concrete = b.mat("CableTrough",Color("#93938b"),0.95,0.0,4.0)
    yellow = b.mat("TrackSafetyPaint",Color("#c3a142"),0.73)
    _straight(0.0,Route.PORTAL_Z,528.0,true)
    for x in [-10.8,10.8]:
        _straight(x,360.0,528.0,false)
        _buffer(x,360.0)
    for side in [-1.0,1.0]:
        var start := 332.0 if side < 0.0 else 316.0
        var end := start+68.0
        _branch(side,start,end)
        _straight(side*5.4,end,528.0,false)
    for x in [-10.8,-5.4,0.0,5.4,10.8]: _buffer(x,525.5)
    # Supply starts at every track's first geometry segment, including sidings.
    b.label("КОНТАКТНЫЙ РЕЛЬС • 750 В",Vector3(Route.CENTER_X+3.1,7.0,350),0.005,0.0,Color("#e2c261"))
    for z in range(100,405,16):
        var yy := Route.height(z)
        for x in [-2.4,2.4]:
            b.box(concrete,Vector3(Route.CENTER_X+x,yy-0.16,z+8),Vector3(0.30,0.25,15.96),Basis(Vector3.RIGHT,-atan(Route.grade(z+8))))
            for dz in range(0,16,2): b.box(clip,Vector3(Route.CENTER_X+x,Route.height(z+dz)-0.025,z+dz),Vector3(0.31,0.008,0.012))
    b.flush()

func _rail_pair(a: Vector3,c: Vector3) -> void:
    var direction := (c-a).normalized()
    var lateral := Vector3(direction.z,0,-direction.x).normalized()
    var basis := Basis(lateral,direction,lateral.cross(direction))
    var length := a.distance_to(c)
    for side in [-1.0,1.0]:
        var middle: Vector3 = (a+c)*0.5+lateral*side*Route.RAIL_CENTER
        b.box(side_steel,middle+Vector3(0,-0.1475,0),Vector3(0.14,length,0.025),basis)
        b.box(side_steel,middle+Vector3(0,-0.09,0),Vector3(0.04,length,0.09),basis)
        b.box(rail,middle+Vector3(0,-0.0225,0),Vector3(0.095,length,0.045),basis)

func _straight(x: float,z0: float,z1: float,main: bool) -> void:
    var z := z0
    while z < z1-0.01:
        var end := minf(z+4.0,z1)
        var a := Vector3(Route.CENTER_X+x,Route.height(z),z)
        var c := Vector3(Route.CENTER_X+x,Route.height(end),end)
        _supply(a,c)
        # A beam's local X is the rail width, local Z its vertical thickness.
        _rail_pair(a,c)
        if z < 410.0:
            var low_a := a+Vector3(-1.85,-0.39,0)
            var low_c := c+Vector3(-1.85,-0.39,0)
            b.quad(ballast,low_a,low_c,c+Vector3(-1.25,-0.245,0),a+Vector3(-1.25,-0.245,0))
            b.quad(ballast,a+Vector3(-1.25,-0.245,0),c+Vector3(-1.25,-0.245,0),c+Vector3(1.25,-0.245,0),a+Vector3(1.25,-0.245,0))
            b.quad(ballast,a+Vector3(1.25,-0.245,0),c+Vector3(1.25,-0.245,0),c+Vector3(1.85,-0.39,0),a+Vector3(1.85,-0.39,0))
        z = end
    var count := int((z1-z0)/0.64)
    for i in range(count):
        var zz := z0+0.32+float(i)*0.64
        var basis := Basis(Vector3.RIGHT,-atan(Route.grade(zz)))
        b.box(ties,Vector3(Route.CENTER_X+x,Route.height(zz)-0.22,zz),Vector3(2.30,0.12,0.23),basis)
        for side in [-1.0,1.0]:
            b.box(clip,Vector3(Route.CENTER_X+x+side*Route.RAIL_CENTER,Route.height(zz)-0.145,zz),Vector3(0.23,0.035,0.18),basis)
    if main:
        # Level-crossing infill at railhead level; the running rails remain open.
        var crossing := b.mat("CrossingRubber",Color("#424743"),0.96)
        b.box(crossing,Vector3(Route.CENTER_X,5.965,355),Vector3(1.47,0.06,7.0))
        for side in [-1.0,1.0]: b.box(crossing,Vector3(Route.CENTER_X+side*1.40,5.965,355),Vector3(0.97,0.06,7.0))

func _branch(side: float,z0: float,z1: float) -> void:
    var previous := Vector3(Route.CENTER_X,6.0,z0)
    for i in range(1,35):
        var u := float(i)/34.0
        var x := side*5.4*u*u*(3.0-2.0*u)
        var point := Vector3(Route.CENTER_X+x,6.0,lerpf(z0,z1,u))
        if absf(x) > 0.08:
            _rail_pair(previous,point)
            _supply(previous,point)
        previous = point
    var count := int((z1-z0)/0.64)
    for i in range(count):
        var u := (float(i)+0.5)/float(count)
        var x := side*5.4*u*u*(3.0-2.0*u)
        var z := lerpf(z0,z1,u)
        if absf(x) < 2.6:
            b.box(ties,Vector3(Route.CENTER_X+x*0.5,5.775,z),Vector3(2.30+absf(x),0.11,0.23))
        else:
            var angle := atan(side*5.4*6.0*u*(1.0-u)/(z1-z0))
            b.box(ties,Vector3(Route.CENTER_X+x,5.78,z),Vector3(2.30,0.12,0.23),Basis(Vector3.UP,angle))
    var frog_z := lerpf(z0,z1,0.37)
    b.beam(clip,Vector3(Route.CENTER_X+side*0.75,5.96,frog_z-2.0),Vector3(Route.CENTER_X+side*1.0,5.96,frog_z+2.0),0.05)
    b.box(clip,Vector3(Route.CENTER_X-side*2.35,5.93,z0+9.0),Vector3(0.8,0.28,0.48))
    b.box(yellow,Vector3(Route.CENTER_X-side*2.35,6.09,z0+9.0),Vector3(0.55,0.055,0.32))

func _buffer(x: float,z: float) -> void:
    for side in [-1.0,1.0]:
        b.beam(clip,Vector3(Route.CENTER_X+x+side*0.81,5.93,z-1.1),Vector3(Route.CENTER_X+x+side*0.81,6.8,z),0.18)
    b.box(clip,Vector3(Route.CENTER_X+x,6.8,z),Vector3(2.0,0.28,0.28))
    for i in range(6): b.box(yellow,Vector3(Route.CENTER_X+x-0.8+float(i)*0.32,6.81,z-0.15),Vector3(0.17,0.24,0.025))

func _supply(a: Vector3,c: Vector3) -> void:
    var d := (c-a).normalized()
    var lateral := Vector3(d.z,0,-d.x).normalized()
    var offset := lateral*1.48
    var cover := b.mat("ContinuousContactCover",Color("#76664a"),0.92)
    b.beam(side_steel,a+offset+Vector3(0,0.225,0),c+offset+Vector3(0,0.225,0),0.085,0.12)
    b.beam(side_steel,a+offset+Vector3(0,0.15,0),c+offset+Vector3(0,0.15,0),0.13,0.035)
    b.beam(cover,a+offset+Vector3(0,0.325,0),c+offset+Vector3(0,0.325,0),0.27,0.055)
    var porcelain := b.mat("ContinuousContactInsulators",Color("#c5c3b0"),0.65)
    b.cylinder(porcelain,(a+c)*0.5+offset+Vector3(0,0.025,0),0.075,0.16)
