extends Node3D
const Builder = preload("res://scripts/depot/depot_builder.gd")
const Route = preload("res://scripts/depot/route_profile.gd")
const EnvironmentUpgrade = preload("res://scripts/depot/depot_environment_v43.gd")
var b: Builder
var grass: Material
var asphalt: Material
var concrete: Material
var brick: Material
var blue: Material
var roof: Material
var window: Material
var steel: Material
var yellow: Material
var red: Material

func _ready() -> void:
    b = Builder.new(self)
    grass = EnvironmentUpgrade.ground_material()
    asphalt = b.mat("WornAsphalt",Color("#505451"),0.97,0.0,3.0)
    concrete = b.mat("YardConcrete",Color("#96978b"),0.96,0.0,4.0)
    brick = b.mat("BelarusIndustrialBrick",Color("#a49b83"),0.95,0.0,1.0)
    blue = b.mat("UtilityPaint",Color("#677f85"),0.75,0.2,2.0)
    roof = b.mat("UtilityRoof",Color("#686c65"),0.8,0.25,2.0)
    window = b.mat("DaytimeWindows",Color("#435d69"),0.26,0.5)
    steel = b.mat("GalvanisedSteel",Color("#7e8885"),0.61,0.65)
    yellow = b.mat("YardSafetyYellow",Color("#baa14e"),0.8)
    red = b.mat("UtilityRed",Color("#8b4c3f"),0.85)
    _terrain(-850,-5,-600,1000)
    _terrain(5,850,-600,1000)
    _terrain(-5,5,-600,96)
    _terrain(-5,5,300,1000)
    # A 300 x 200 m depot yard, service road, crossing and safe walkways.
    b.box(concrete,Vector3(Route.CENTER_X,5.58,450),Vector3(197,0.16,297))
    # Omit the main track corridor in paving: ballast stays exposed outside shed.
    b.box(asphalt,Vector3(Route.CENTER_X-39,5.66,450),Vector3(7.0,0.08,296))
    for side in [-1.0,1.0]:
        b.box(asphalt,Vector3(Route.CENTER_X+side*52,5.665,355),Vector3(92,0.09,7))
        b.box(concrete,Vector3(Route.CENTER_X+side*44.0,5.75,455),Vector3(1.65,0.18,260))
        for z in range(330,570,12): b.box(yellow,Vector3(Route.CENTER_X+side*42.7,5.805,z),Vector3(0.06,0.025,3.0))
    for side in [-1.0,1.0]:
        var xa: float = Route.CENTER_X+side*1.90
        var xb: float = Route.CENTER_X+side*6.0
        b.quad(asphalt,Vector3(xa,5.99,351.5),Vector3(xa,5.99,358.5),Vector3(xb,5.71,358.5),Vector3(xb,5.71,351.5))
        b.box(grass,Vector3(Route.CENTER_X+side*90,5.71,460),Vector3(7.0,0.08,225.0))
    for x in [-83.0,80.0]: b.box(asphalt,Vector3(Route.CENTER_X+x,5.66,480),Vector3(7,0.08,220))
    # Several distinct useful buildings, rather than one empty hangar.
    _building(Vector3(62,5.7,461),Vector3(27,12,18),3,"АДМИНИСТРАЦИЯ",brick)
    _building(Vector3(-66,5.7,484),Vector3(25,8,26),2,"РЕМОНТНАЯ МАСТЕРСКАЯ",brick)
    _building(Vector3(-62,5.7,361),Vector3(29,6,20),1,"СКЛАД ПУТЕВОГО ХОЗЯЙСТВА",blue)
    _building(Vector3(63,5.7,521),Vector3(25,7,22),1,"СЛУЖБА ЭНЕРГОСНАБЖЕНИЯ",brick)
    _building(Vector3(77,5.7,322),Vector3(8,3.5,6),1,"КПП",brick)
    _building(Vector3(57,5.7,374),Vector3(17,6,15),1,"ТЯГОВАЯ ПОДСТАНЦИЯ",brick)
    _substation()
    # Main and railway gates remain open; fences never cross the running route.
    _fence(Vector3(-99,5.7,300),Vector3(-4.5,5.7,300),2.3)
    _fence(Vector3(4.5,5.7,300),Vector3(73,5.7,300),2.3)
    _fence(Vector3(81,5.7,300),Vector3(99,5.7,300),2.3)
    _fence(Vector3(-99,5.7,600),Vector3(99,5.7,600),2.3)
    _fence(Vector3(-99,5.7,300),Vector3(-99,5.7,600),2.3)
    _fence(Vector3(99,5.7,300),Vector3(99,5.7,600),2.3)
    for x in [-4.5,4.5,73.0,81.0]: b.box(steel,Vector3(Route.CENTER_X+x,7.0,300),Vector3(0.24,2.6,0.24))
    for x in [-7.7,7.7]: b.box(steel,Vector3(Route.CENTER_X+x,6.9,300),Vector3(5.8,1.9,0.12))
    b.label("ЭЛЕКТРОДЕПО • СЛУЖЕБНАЯ ТЕРРИТОРИЯ",Vector3(Route.CENTER_X+77,9.0,300),0.006,PI)
    # Storage containers, drums, wheelset stand and modest outdoor equipment.
    for z in [335.0,351.0,542.0]:
        var x := Route.CENTER_X-27.0
        b.box(blue,Vector3(x,7.05,z),Vector3(11.8,2.7,2.45))
        b.box(steel,Vector3(x,8.42,z),Vector3(12.0,0.07,2.6))
        for dx in [-5.65,5.65]: b.box(steel,Vector3(x+dx,7.05,z-1.24),Vector3(0.08,2.55,0.07))
        for k in range(6): b.box(steel,Vector3(x-5.0+float(k)*1.95,7.05,z-1.24),Vector3(0.025,2.45,0.02))
    for i in range(8):
        var x := Route.CENTER_X-55.0+float(i%4)*0.65
        var z := 402.0+float(i/4)*0.75
        b.cylinder(red,Vector3(x,6.18,z),0.25,0.96)
        b.cylinder(steel,Vector3(x,6.675,z),0.255,0.025)
    for z in [390.0,396.0]:
        b.box(concrete,Vector3(Route.CENTER_X-72,5.98,z),Vector3(4.0,0.5,1.8))
        for side in [-1.0,1.0]: b.cylinder(steel,Vector3(Route.CENTER_X-72+side*0.80,6.55,z),0.42,0.15,Basis(Vector3.BACK,PI*0.5))
    # Cable service trench and water/fire distribution, away from vehicle gauge.
    b.box(concrete,Vector3(Route.CENTER_X+29,5.9,451),Vector3(0.65,0.35,260))
    for z in range(324,580,4): b.box(steel,Vector3(Route.CENTER_X+29,6.09,z),Vector3(0.69,0.025,0.025))
    for z in [335.0,405.0,555.0]:
        b.cylinder(red,Vector3(Route.CENTER_X-43,6.22,z),0.085,0.98)
        b.cylinder(red,Vector3(Route.CENTER_X-43,6.72,z),0.12,0.14)
    _light_poles()
    _landscape()
    b.flush()

func _terrain(x0: float,x1: float,z0: float,z1: float) -> void:
    var nx := maxi(1,int(ceil((x1-x0)/24.0)))
    var nz := maxi(1,int(ceil((z1-z0)/24.0)))
    for i in range(nx):
        for j in range(nz):
            var xa := Route.CENTER_X+lerpf(x0,x1,float(i)/float(nx))
            var xb := Route.CENTER_X+lerpf(x0,x1,float(i+1)/float(nx))
            var za := lerpf(z0,z1,float(j)/float(nz))
            var zb := lerpf(z0,z1,float(j+1)/float(nz))
            b.quad(grass,Vector3(xa,Route.ground(xa,za),za),Vector3(xa,Route.ground(xa,zb),zb),Vector3(xb,Route.ground(xb,zb),zb),Vector3(xb,Route.ground(xb,za),za))

func _building(position: Vector3,size: Vector3,floors: int,title: String,wall: Material) -> void:
    position.x += Route.CENTER_X
    b.box(wall,position+Vector3(0,size.y*0.5,0),size)
    b.box(concrete,position+Vector3(0,0.28,0),Vector3(size.x+0.24,0.56,size.z+0.24))
    b.box(roof,position+Vector3(0,size.y+0.13,0),Vector3(size.x+0.6,0.26,size.z+0.6))
    for level in range(floors):
        var yy := position.y+2.25+float(level)*(size.y/float(floors))
        for k in range(maxi(2,int(size.x/3.6))):
            var xx := position.x-size.x*0.5+2.0+float(k)*3.5
            if xx > position.x+size.x*0.5-1.0: continue
            for side in [-1.0,1.0]:
                b.box(window,Vector3(xx,yy,position.z+side*(size.z*0.5+0.018)),Vector3(1.7,1.65,0.055))
                b.box(concrete,Vector3(xx,yy-0.88,position.z+side*(size.z*0.5+0.09)),Vector3(1.88,0.09,0.20))
                b.box(steel,Vector3(xx,yy,position.z+side*(size.z*0.5+0.05)),Vector3(0.05,1.65,0.045))
        b.box(concrete,position+Vector3(0,yy-position.y+1.35,0),Vector3(size.x+0.08,0.12,size.z+0.08))
    b.box(blue,position+Vector3(size.x*0.28,1.15,-size.z*0.5-0.04),Vector3(1.2,2.3,0.12))
    b.box(roof,position+Vector3(size.x*0.28,2.65,-size.z*0.5-0.65),Vector3(2.3,0.12,1.35))
    b.box(concrete,position+Vector3(size.x*0.28,0.12,-size.z*0.5-0.50),Vector3(2.2,0.24,1.0))
    b.label(title,position+Vector3(0,size.y-0.7,-size.z*0.5-0.08),0.005,PI)
    for dx in [-size.x*0.28,size.x*0.28]:
        b.box(steel,position+Vector3(dx,size.y+0.45,0),Vector3(0.9,0.7,0.8))
        b.box(roof,position+Vector3(dx,size.y+0.85,0),Vector3(1.15,0.1,1.05))

func _fence(a: Vector3,c: Vector3,height: float) -> void:
    a.x += Route.CENTER_X
    c.x += Route.CENTER_X
    var delta := c-a
    var count := maxi(1,int(ceil(delta.length()/5.5)))
    for i in range(count+1):
        var p := a.lerp(c,float(i)/float(count))
        b.box(steel,p+Vector3(0,height*0.5,0),Vector3(0.09,height+0.15,0.09))
    for y in [0.5,height-0.28]: b.beam(steel,a+Vector3(0,y,0),c+Vector3(0,y,0),0.045)
    var bars := int(delta.length()/0.58)
    for i in range(bars):
        var p := a.lerp(c,(float(i)+0.5)/float(bars))
        b.box(steel,p+Vector3(0,height*0.5,0),Vector3(0.027,height,0.027))

func _substation() -> void:
    for x in [48.0,57.0,66.0]:
        b.box(concrete,Vector3(Route.CENTER_X+x,5.95,397),Vector3(4.8,0.5,4.0))
        b.box(blue,Vector3(Route.CENTER_X+x,7.0,397),Vector3(2.8,1.8,2.2))
        for side in [-1.0,1.0]:
            for j in range(8): b.box(steel,Vector3(Route.CENTER_X+x+side*1.5,7.0,396.1+float(j)*0.25),Vector3(0.20,1.5,0.07))
        for dx in [-0.7,0.0,0.7]:
            b.cylinder(concrete,Vector3(Route.CENTER_X+x+dx,8.2,397),0.11,0.65)
            for ring in range(4): b.cylinder(roof,Vector3(Route.CENTER_X+x+dx,8.0+float(ring)*0.12,397),0.16,0.04)
    _fence(Vector3(44,5.7,392),Vector3(71,5.7,392),1.9)
    _fence(Vector3(44,5.7,392),Vector3(44,5.7,402),1.9)
    _fence(Vector3(71,5.7,392),Vector3(71,5.7,402),1.9)
    _fence(Vector3(44,5.7,402),Vector3(71,5.7,402),1.9)

func _light_poles() -> void:
    var fixture := b.mat("OutdoorFixture",Color("#d8d9c7"),0.5,0.0,0.0,0.3)
    for z in range(320,590,36):
        for x in [-31.0,32.0]:
            b.cylinder(steel,Vector3(Route.CENTER_X+x,10.1,z),0.08,8.8)
            b.beam(steel,Vector3(Route.CENTER_X+x,14.5,z),Vector3(Route.CENTER_X+x+1.6,14.65,z),0.075)
            b.box(steel,Vector3(Route.CENTER_X+x+1.5,14.59,z),Vector3(0.9,0.15,0.38))
            b.box(fixture,Vector3(Route.CENTER_X+x+1.5,14.5,z),Vector3(0.78,0.025,0.29))
    for z in range(120,301,36):
        var y := Route.ground(Route.CENTER_X+9,z)
        b.cylinder(steel,Vector3(Route.CENTER_X+9,y+3.6,z),0.07,7.2)
        b.box(fixture,Vector3(Route.CENTER_X+8.3,y+7.1,z),Vector3(1.1,0.1,0.34))

func _landscape() -> void:
    var environment := EnvironmentUpgrade.new()
    environment.name = "DepotEnvironmentV43"
    add_child(environment)
