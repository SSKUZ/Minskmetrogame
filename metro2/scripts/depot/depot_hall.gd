extends Node3D
const Builder = preload("res://scripts/depot/depot_builder.gd")
const Route = preload("res://scripts/depot/route_profile.gd")

func _ready() -> void:
    var b := Builder.new(self)
    var concrete := b.mat("HallConcrete",Color("#888b88"),0.94,0.0,4.0)
    var steel := b.mat("TrussSteel",Color("#596865"),0.65,0.55)
    var cladding := b.mat("GreyBlueCladding",Color("#738487"),0.72,0.25,2.0)
    var roof := b.mat("StandingSeamRoof",Color("#626b6c"),0.75,0.45,2.0)
    var brick := b.mat("IndustrialBrick",Color("#a39b87"),0.94,0.0,1.0)
    var glass := b.mat("IndustrialGlazing",Color("#455f65"),0.24,0.48)
    var yellow := b.mat("SafetyYellow",Color("#bb963d"),0.73,0.1)
    var dark := b.mat("PitDarkSteel",Color("#303b3d"),0.8,0.45)
    var red := b.mat("FireEquipment",Color("#973f34"),0.76,0.15)
    var lamp := b.mat("HallLamp",Color("#e4debf"),0.5,0.0,0.0,1.0)
    var x0 := Route.CENTER_X
    # 120 x 40 m, five bays. Two inspection channels are actual gaps in the slab.
    for strip in [Vector2(-20,-6.025),Vector2(-4.775,4.775),Vector2(6.025,20)]:
        b.box(concrete,Vector3(x0+(strip.x+strip.y)*0.5,5.56,472.5),Vector3(strip.y-strip.x,0.32,95))
    b.box(concrete,Vector3(x0,5.56,417.5),Vector3(40,0.32,15))
    b.box(concrete,Vector3(x0,5.56,525),Vector3(40,0.32,10))
    for x in [-5.4,5.4]:
        b.box(dark,Vector3(x0+x,4.45,472.5),Vector3(1.25,0.16,95))
        for side in [-1.0,1.0]:
            b.box(concrete,Vector3(x0+x+side*0.66,5.0,472.5),Vector3(0.07,1.35,95))
            b.box(yellow,Vector3(x0+x+side*0.77,5.74,472.5),Vector3(0.08,0.025,95))
        for step in range(6):
            b.box(steel,Vector3(x0+x,4.6+float(step)*0.18,426.0+float(step)*0.26),Vector3(0.85,0.06,0.25))
    # Marked pedestrian routes, kept outside all vehicle clearances.
    for x in [-16.0,-8.1,8.1,16.0]:
        for edge in [-0.48,0.48]: b.box(yellow,Vector3(x0+x+edge,5.738,470),Vector3(0.045,0.012,114))
    for z in range(416,529,12):
        for x in [-18.8,-8.1,8.1,18.8]:
            b.box(concrete,Vector3(x0+x,10.65,z),Vector3(0.38,9.9,0.48))
            b.box(yellow,Vector3(x0+x,6.3,z),Vector3(0.44,1.2,0.54))
            for mark in range(3): b.box(dark,Vector3(x0+x,5.95+float(mark)*0.32,z-0.278),Vector3(0.45,0.11,0.014))
        # Full-span triangulated roof trusses, not decorative floating bars.
        b.beam(steel,Vector3(x0-20,15.7,z),Vector3(x0+20,15.7,z),0.16,0.22)
        b.beam(steel,Vector3(x0-20,16.7,z),Vector3(x0,17.45,z),0.15,0.2)
        b.beam(steel,Vector3(x0,17.45,z),Vector3(x0+20,16.7,z),0.15,0.2)
        for j in range(10):
            var xa := -20.0+float(j)*4.0
            var xb := xa+4.0
            var roof_y := 17.45-absf((xa+xb)*0.5)*0.0375
            b.beam(steel,Vector3(x0+xa,15.7,z),Vector3(x0+(xa+xb)*0.5,roof_y,z),0.07)
            b.beam(steel,Vector3(x0+(xa+xb)*0.5,roof_y,z),Vector3(x0+xb,15.7,z),0.07)
    # Side walls and long industrial window bands.
    for side in [-1.0,1.0]:
        b.box(brick,Vector3(x0+side*20.0,8.2,470),Vector3(0.34,5.0,120))
        b.box(cladding,Vector3(x0+side*20.0,15.55,470),Vector3(0.28,2.3,120))
        for z in range(413,530,6):
            b.box(glass,Vector3(x0+side*20.02,12.55,z),Vector3(0.10,3.65,5.8))
            b.box(steel,Vector3(x0+side*20.0,12.55,float(z)+2.95),Vector3(0.17,3.8,0.12))
            b.box(steel,Vector3(x0+side*20.09,12.55,z),Vector3(0.13,0.08,5.85))
        b.box(steel,Vector3(x0+side*14,14.3,470),Vector3(0.4,0.16,114))
        b.cylinder(steel,Vector3(x0+side*16.5,14.65,470),0.26,112,Basis(Vector3.RIGHT,PI*0.5))
        for z in range(418,528,8):
            b.beam(steel,Vector3(x0+side*19.7,13.9,z),Vector3(x0+side*14,13.9,z),0.065)
        # Repair workbenches, rack shelves and electrical cabinets.
        for z in [433.0,465.0,497.0,521.0]:
            b.box(cladding,Vector3(x0+side*18.1,6.65,z),Vector3(0.65,1.9,1.45))
            b.box(dark,Vector3(x0+side*17.75,6.7,z+0.32),Vector3(0.04,0.38,0.035))
            b.box(yellow,Vector3(x0+side*17.74,7.25,z-0.36),Vector3(0.025,0.13,0.14))
        for z in [445.0,480.0,508.0]:
            for dz in [-1.4,1.4]:
                for xx in [-0.45,0.45]: b.box(steel,Vector3(x0+side*17.5+xx,6.7,z+dz),Vector3(0.065,2.0,0.065))
            for y in [5.9,6.6,7.3]:
                b.box(steel,Vector3(x0+side*17.5,y,z),Vector3(1.0,0.07,2.95))
                for k in range(3): b.box(cladding,Vector3(x0+side*17.5,y+0.20,z-0.9+float(k)*0.85),Vector3(0.65,0.32,0.65))
        for z in [420.0,472.0,524.0]:
            b.box(red,Vector3(x0+side*19.65,6.8,z),Vector3(0.20,0.8,0.62))
            b.box(lamp,Vector3(x0+side*19.5,7.5,z),Vector3(0.07,0.13,0.25))
    # Gabled metal roof, flashing, ventilators and rainwater pipes.
    b.quad(roof,Vector3(x0-20.3,16.75,408.8),Vector3(x0-20.3,16.75,531.2),Vector3(x0,17.5,531.2),Vector3(x0,17.5,408.8))
    b.quad(roof,Vector3(x0,17.5,408.8),Vector3(x0,17.5,531.2),Vector3(x0+20.3,16.75,531.2),Vector3(x0+20.3,16.75,408.8))
    for side in [-1.0,1.0]:
        b.box(steel,Vector3(x0+side*20.2,16.65,470),Vector3(0.22,0.20,123))
        for z in [412.0,442.0,472.0,502.0,528.0]: b.cylinder(steel,Vector3(x0+side*20.35,11.2,z),0.075,11.0)
    for z in [430.0,460.0,490.0,520.0]:
        b.box(cladding,Vector3(x0,17.9,z),Vector3(2.3,0.8,3.0))
        b.box(dark,Vector3(x0,18.35,z),Vector3(2.55,0.12,3.25))
    # Five front gates, central three open. The player's route is never blocked.
    b.box(brick,Vector3(x0,13.9,410.0),Vector3(40.0,5.6,0.40))
    b.box(brick,Vector3(x0,11.2,530.0),Vector3(40,11.0,0.40))
    for x in [-19.2,-13.5,-8.1,-2.7,2.7,8.1,13.5,19.2]:
        b.box(concrete,Vector3(x0+x,8.45,409.9),Vector3(0.65,5.5,0.55))
    for x in [-16.6,16.6]: b.box(brick,Vector3(x0+x,8.45,410.0),Vector3(5.2,5.5,0.4))
    for i in range(5):
        var x := x0+float(i-2)*5.4
        for edge in [-2.25,2.25]: b.box(yellow,Vector3(x+edge,8.5,409.65),Vector3(0.10,5.6,0.12))
        b.box(cladding,Vector3(x,11.35,409.85),Vector3(4.65,0.65,0.55))
        if i in [0,4]: b.box(cladding,Vector3(x,8.45,409.90),Vector3(4.45,5.5,0.10))
        b.label("%02d" % (i+1),Vector3(x,12.2,409.72),0.022,PI,Color("#e0c271"))
    b.label("ЭЛЕКТРОДЕПО  •  МИНСК",Vector3(x0,15.1,409.72),0.021,PI)
    b.label("СЛУЖЕБНАЯ ЗОНА • БЕЗОПАСНЫЙ ПРОХОД",Vector3(x0-17,8.5,414),0.006,PI*0.5)
    # Repeated fixture geometry, only four real lamps.
    for z in range(420,528,8):
        for x in [-13.5,0.0,13.5]:
            b.box(dark,Vector3(x0+x,15.50,z),Vector3(0.22,0.13,2.0))
            b.box(lamp,Vector3(x0+x,15.42,z),Vector3(0.17,0.045,1.85))
    for z in [428.0,456.0,484.0,512.0]:
        var light := OmniLight3D.new()
        light.position = Vector3(x0,13.8,z)
        light.light_color = Color(1.0,0.96,0.84)
        light.light_energy = 1.1
        light.omni_range = 19.0
        light.omni_attenuation = 1.3
        light.shadow_enabled = false
        add_child(light)
    _finish_envelope(b)
    b.flush()

func _finish_envelope(b: Builder) -> void:
    # Cover envelope joints, not inspection channels or the three open gates.
    var x0 := Route.CENTER_X
    var trim := b.mat("FoldedZincFlashings",Color("#9ba7a3"),0.48,0.62)
    var blue := b.mat("HallBlueGreyPaint",Color("#557c8c"),0.70,0.18)
    var wall := b.mat("GableCladding",Color("#809194"),0.76,0.20,2.0)
    var rubber := b.mat("GateRubberSeals",Color("#252e31"),0.95)
    var red := b.mat("SmallFireDetails",Color("#a04d3b"),0.80)
    var pale := b.mat("InteriorPlasterBand",Color("#c4c7ba"),0.91)
    var grille := b.mat("VentGrille",Color("#424e51"),0.78,0.35)
    for side in [-1.0,1.0]:
        var x: float=x0+side*20.0
        # Existing window bands start 25 mm above brick and end 25 mm below cladding.
        for y in [10.71,14.39]:
            b.box(trim,Vector3(x,y,470),Vector3(0.42,0.14,120.3))
        b.box(wall,Vector3(x,16.74,470),Vector3(0.38,0.18,120.35))
        b.box(blue,Vector3(x-side*0.19,7.05,470),Vector3(0.035,0.72,119.8))
        b.box(pale,Vector3(x-side*0.195,8.45,470),Vector3(0.03,0.12,119.8))
        for z in range(413,530,6):
            # Full perimeter glazing rebates and fine vertical mullions.
            for dz in [-2.90,0.0,2.90]:
                b.box(trim,Vector3(x,12.55,float(z)+dz),Vector3(0.22,3.79,0.065))
        for z in range(416,530,12):
            b.box(trim,Vector3(x+side*0.19,13.68,z),Vector3(0.06,5.95,0.14))
        for z in [410.0,530.0]:
            b.box(trim,Vector3(x,11.3,z),Vector3(0.52,11.2,0.52))
        # Two horizontal pipe runs and supports: modest reusable details.
        for y in [8.85,9.18]:
            b.cylinder(blue,Vector3(x-side*0.28,y,470),0.045,117.5,Basis(Vector3.RIGHT,PI*0.5))
        for z in range(420,529,12):
            b.box(trim,Vector3(x-side*0.30,9.02,z),Vector3(0.10,0.50,0.055))
        # Weathered sill caps and feet connect the existing downpipes to the wall.
        for z in [412.0,442.0,472.0,502.0,528.0]:
            for y in [7.0,11.5,15.9]:
                b.box(trim,Vector3(x+side*0.24,y,z),Vector3(0.25,0.07,0.20))
            b.box(trim,Vector3(x+side*0.35,5.78,z),Vector3(0.24,0.18,0.32))
    # Close the missing triangular gable faces at both ends of the existing roof.
    for z in [409.79,530.21]:
        var a := Vector3(x0-20.16,16.66,z)
        var peak := Vector3(x0,17.51,z)
        var c := Vector3(x0+20.16,16.66,z)
        _triangle(b,wall,a,peak,c)
        b.beam(trim,a,peak,0.12,0.10)
        b.beam(trim,peak,c,0.12,0.10)
        b.box(trim,Vector3(x0,16.69,z),Vector3(40.3,0.10,0.12))
        for x in [-13.0,-6.5,0.0,6.5,13.0]:
            b.box(grille,Vector3(x0+x,14.25,z),Vector3(2.4,0.68,0.10))
            for row in range(5):
                b.box(trim,Vector3(x0+x,14.0+float(row)*0.12,z+(-0.07 if z<470 else 0.07)),Vector3(2.3,0.025,0.025))
    # Ridge cap and standing seams follow the existing pitch exactly.
    b.box(trim,Vector3(x0,17.53,470),Vector3(0.26,0.10,122.6))
    for side in [-1.0,1.0]:
        for strip in range(1,26):
            var dx := float(strip)*0.76
            var y := 17.5-dx*(0.75/20.3)+0.018
            b.box(trim,Vector3(x0+side*dx,y,470),Vector3(0.025,0.035,122.0))
    # Visible guides, panel ribs and door seals; leave gate apertures unchanged.
    for i in range(5):
        var x := x0+float(i-2)*5.4
        for side in [-1.0,1.0]:
            b.box(rubber,Vector3(x+side*2.22,8.46,409.59),Vector3(0.06,5.48,0.07))
            b.box(trim,Vector3(x+side*2.31,8.55,409.56),Vector3(0.08,5.7,0.15))
        if i in [0,4]:
            for row in range(18):
                b.box(trim,Vector3(x,5.84+float(row)*0.30,409.83),Vector3(4.34,0.022,0.025))
    # Small equipment details on the existing wall-side workbench bays only.
    for side in [-1.0,1.0]:
        var x: float=x0+side*17.5
        for z in [445.0,480.0,508.0]:
            b.box(blue,Vector3(x,7.39,z),Vector3(0.76,0.20,0.55))
            b.box(trim,Vector3(x,7.51,z),Vector3(0.82,0.04,0.60))
            b.box(rubber,Vector3(x,7.56,z),Vector3(0.20,0.06,0.06))
            for tool in range(3):
                b.box(trim,Vector3(x+0.10,7.65,z-0.65+float(tool)*0.20),Vector3(0.05,0.22,0.04))
        b.cylinder(red,Vector3(x0+side*19.56,6.23,420),0.13,0.65)
        b.box(rubber,Vector3(x0+side*19.56,6.61,420),Vector3(0.13,0.10,0.10))

func _triangle(b: Builder,material: Material,a: Vector3,c: Vector3,d: Vector3) -> void:
    if not b.surfaces.has(material):
        var st := SurfaceTool.new()
        st.begin(Mesh.PRIMITIVE_TRIANGLES)
        b.surfaces[material]=st
    var st: SurfaceTool=b.surfaces[material]
    var normal := (c-a).cross(d-a).normalized()
    for p in [a,c,d]:
        st.set_normal(normal)
        st.add_vertex(p)
