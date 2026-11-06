extends Node3D
const Builder = preload("res://scripts/depot/depot_builder.gd")
const Route = preload("res://scripts/depot/route_profile.gd")
const Tunnel = preload("res://scripts/tunnel_lightweight_straight.gd")

func _ready() -> void:
    var b := Builder.new(self)
    var concrete := b.mat("RetainingConcrete",Color("#94958b"),0.95,0.0,4.0)
    var dark := b.mat("DrainChannels",Color("#3c4544"),0.88,0.3)
    var steel := b.mat("PortalGuardrails",Color("#687570"),0.6,0.6)
    var edge := b.mat("ConcreteExpansionJoints",Color("#50564f"),0.98)
    var yellow := b.mat("PortalSafety",Color("#bf9d4f"),0.85)
    var lamp := b.mat("PortalLamps",Color("#e1d6af"),0.5,0.0,0.0,0.75)
    var x0 := Route.CENTER_X
    # Cut-and-cover approach. Track grade and retaining walls share the profile.
    for z in range(96,300,4):
        var end := float(z)+4.0
        var floor_a := Route.height(z)-0.34
        var floor_b := Route.height(end)-0.34
        b.quad(concrete,Vector3(x0-4.8,floor_a,z),Vector3(x0-4.8,floor_b,end),Vector3(x0+4.8,floor_b,end),Vector3(x0+4.8,floor_a,z))
        for side in [-1.0,1.0]:
            var x: float = x0+side*4.8
            var top_a := Route.ground(x,z)+0.035
            var top_b := Route.ground(x,end)+0.035
            b.quad(concrete,Vector3(x,floor_a,z),Vector3(x,top_a,z),Vector3(x,top_b,end),Vector3(x,floor_b,end))
            b.quad(concrete,Vector3(x,top_a,z),Vector3(x+side*0.5,top_a,z),Vector3(x+side*0.5,top_b,end),Vector3(x,top_b,end))
            b.beam(dark,Vector3(x0+side*3.85,Route.height(z)-0.09,z),Vector3(x0+side*3.85,Route.height(end)-0.09,end),0.21,0.08)
            b.beam(concrete,Vector3(x0+side*3.0,Route.height(z)-0.10,z),Vector3(x0+side*3.0,Route.height(end)-0.10,end),0.85,0.20)
            if z % 12 == 0:
                b.beam(edge,Vector3(x,floor_a,z),Vector3(x,top_a,z),0.017,0.022)
                b.cylinder(steel,Vector3(x+side*0.23,top_a+0.58,z),0.034,1.16)
            b.beam(steel,Vector3(x+side*0.23,top_a+1.10,z),Vector3(x+side*0.23,top_b+1.10,end),0.045)
            b.beam(steel,Vector3(x+side*0.23,top_a+0.55,z),Vector3(x+side*0.23,top_b+0.55,end),0.028)
    # Portal uses the EXISTING tunnel profile, with a 30 mm reveal clearance.
    var profile: Array[Vector2] = []
    for step in range((Tunnel.PROFILE.size()-1)*4+1):
        profile.append(_smooth_profile(float(step)/4.0))
    for i in range(profile.size()-1):
        var a := profile[i]+(profile[i]-Vector2(0,3.3)).normalized()*0.03
        var c := profile[i+1]+(profile[i+1]-Vector2(0,3.3)).normalized()*0.03
        for z in [95.2,97.0]:
            if absf(c.x-a.x) > 0.0001:
                b.quad(concrete,Vector3(x0+a.x,a.y,z),Vector3(x0+a.x,8.65,z),Vector3(x0+c.x,8.65,z),Vector3(x0+c.x,c.y,z))
        b.quad(concrete,Vector3(x0+a.x,a.y,95.2),Vector3(x0+c.x,c.y,95.2),Vector3(x0+c.x,c.y,97.0),Vector3(x0+a.x,a.y,97.0))
    for side in [-1.0,1.0]:
        b.box(concrete,Vector3(x0+side*5.58,4.15,96.1),Vector3(4.84,9.0,1.8))
        b.box(yellow,Vector3(x0+side*3.25,1.50,97.025),Vector3(0.12,3.5,0.04))
        for z in [99.0,105.0,111.0]:
            b.box(steel,Vector3(x0+side*3.8,Route.height(z)+3.4,z),Vector3(0.12,0.5,0.28))
            b.box(lamp,Vector3(x0+side*3.72,Route.height(z)+3.4,z),Vector3(0.035,0.36,0.22))
        b.box(steel,Vector3(x0+side*6.0,9.23,96.2),Vector3(0.07,1.16,0.07))
    b.box(concrete,Vector3(x0,8.6,96.1),Vector3(16.0,0.25,2.2))
    b.box(steel,Vector3(x0,9.78,96.2),Vector3(15.0,0.05,0.05))
    b.box(steel,Vector3(x0,9.23,96.2),Vector3(15.0,0.04,0.04))
    b.label("МИНСК • СЛУЖЕБНЫЙ ТОННЕЛЬ",Vector3(x0,7.95,97.045),0.011)
    b.label("ГАБАРИТ • КОНТАКТНЫЙ РЕЛЬС",Vector3(x0+5.65,3.6,97.045),0.0045,0.0,Color("#dec076"))
    b.flush()

func _smooth_profile(t: float) -> Vector2:
    var source: Array = Tunnel.PROFILE
    var i := mini(int(floor(t)),source.size()-2)
    var f := clampf(t-float(i),0.0,1.0)
    var a: Vector2 = source[maxi(i-1,0)]
    var c: Vector2 = source[i]
    var d: Vector2 = source[i+1]
    var e: Vector2 = source[mini(i+2,source.size()-1)]
    return 0.5*((2.0*c)+(-a+d)*f+(2.0*a-5.0*c+4.0*d-e)*f*f+(-a+3.0*c-3.0*d+e)*f*f*f)
