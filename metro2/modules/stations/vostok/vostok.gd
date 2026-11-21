extends "res://modules/stations/vostok/station_builder.gd"
## Owner-photo reconstruction. Station Base rail/connection datum retained.
## Finish refinement: owner 7957/7959/7963/8001/8004/8006/8012;
## general-view reference: https://mirmetro.net/metro/minsk/stations/stancyya-uskhod
const ART := "res://modules/stations/vostok/art/"
const SPRING := 4.25
const CROWN_RISE := 4.05
const STAIR_NORTH := -0.30
const STAIR_SOUTH := 79.524
var pale_stone: Material
var stair_stone: ShaderMaterial
var housing: StandardMaterial3D
var cream: StandardMaterial3D
var red_guard: StandardMaterial3D

func _ready() -> void:
    super._ready()
    begin_station()
    white.albedo_color=Color("#e4e5df")
    pale_stone=sampled_stone("stair_marble.jpg",Color("#deded5"),0.43,0.8)
    white.roughness=0.87
    white.normal_enabled=true
    white.normal_texture=mineral_normal()
    white.normal_scale=0.07
    white.uv1_triplanar=true
    white.uv1_world_triplanar=true
    white.uv1_scale=Vector3.ONE*0.55
    stair_stone=_stair_material()
    housing=_material(Color("#827b69"),0.58,0.38)
    cream=_material(Color("#ebe9db"),0.0,0.70)
    red_guard=_material(Color("#a9353e"),0.32,0.39)
    _floor()
    _photo_platform_edges()
    _walls()
    _vault()
    _lighting()
    _ends()
    for z in [14.0,39.612,65.2]:
        _photo_pylon(float(z))
        _five_seat_bench(Vector3(CX,FY,float(z)+1.95))
    _suspended_monitor()
    _track_finishes()
    _floor_fittings()
    _photo_clocks()
    flush()

func _floor() -> void:
    # Owner photos 7957/8001/8004: individual grey slabs, red stepped diamonds,
    # cream centres and narrow transverse inlays, with a red perimeter.
    # Build the pattern as actual mineral inlays rather than one painted plane.
    var joint := _material(Color("#696d69"),0.0,0.73)
    (get_node("IslandPlatform") as MeshInstance3D).material_override=joint
    var greys: Array[StandardMaterial3D]=[]
    for i in range(7):
        var shade := 0.87+float(i)*0.035
        greys.append(sampled_stone("grey_granite.jpg",Color(shade,shade,shade),0.32+float(i%3)*0.035,1.6))
    var red := sampled_stone("red_granite.jpg",Color(0.96,0.95,0.94),0.31,1.55)
    var dark_grey := sampled_stone("grey_granite.jpg",Color("#a3a69e"),0.39,1.6)
    var ivory := _material(Color("#dad5bc"),0.0,0.39)
    for row in range(175):
        var z: float=ZA+(float(row)+0.5)*0.60
        var dz: float=absf((float(row%12)+0.5)*0.60-3.6)
        var half_width := 1.8 if dz<0.31 else 1.2 if dz<0.91 else 0.6 if dz<1.51 else 0.0
        for col in range(16):
            var dx: float=(float(col)-7.5)*0.60
            var mat: Material=red if absf(dx)<half_width else greys[(row*17+col*11)%7]
            if half_width>0.0 and absf(dx)>half_width and absf(dx)<half_width+0.61:
                mat=dark_grey
            box(Vector3(0.598,0.010,0.598),Vector3(CX+dx,FY+0.005,z),mat)
        # Narrow cut slabs complete the 10 m width underneath the edge finish.
        for side in [-1.0,1.0]:
            box(Vector3(0.198,0.010,0.598),Vector3(CX+side*4.9,FY+0.005,z),greys[row%7])
    for i in range(15):
        var z: float=ZA+3.6+float(i)*7.2
        if z>ZB:break
        box(Vector3(1.08,0.006,0.48),Vector3(CX,FY+0.013,z),ivory)
        box(Vector3(0.002,0.001,0.48),Vector3(CX,FY+0.0165,z),joint)
        for side in [-1.0,1.0]:
            box(Vector3(2.55,0.006,0.20),Vector3(CX+side*3.075,FY+0.013,z),red)
            box(Vector3(2.55,0.003,0.055),Vector3(CX+side*3.075,FY+0.0175,z),ivory)
        if z+3.6<ZB:
            box(Vector3(1.08,0.006,0.48),Vector3(CX,FY+0.013,z+3.6),red)
    for side in [-1.0,1.0]:
        box(Vector3(0.34,0.006,105),Vector3(CX+side*4.18,FY+0.013,MID),red)

func _photo_platform_edges() -> void:
    var edge := sampled_stone("grey_granite.jpg",Color("#92968e"),0.53,1.5)
    var yellow := _material(Color("#d5ae43"),0.0,0.77)
    for side in [-1.0,1.0]:
        box(Vector3(0.40,0.018,105),Vector3(CX+side*4.80,FY+0.010,MID),edge)
        box(Vector3(0.21,0.012,105),Vector3(CX+side*4.47,FY+0.014,MID),yellow)
        # Shallow tactile studs, instanced in a single material batch.
        for i in range(1312):
            var z: float=ZA+0.04+float(i)*0.08
            for dx in [-0.065,0.0,0.065]:
                cylinder(0.013,0.006,Vector3(CX+side*4.47+float(dx),FY+0.023,z),yellow)
        for i in range(175):
            box(Vector3(0.212,0.001,0.002),Vector3(CX+side*4.47,FY+0.021,ZA+float(i)*0.60),edge)

func _walls() -> void:
    var seam := _material(Color("#bdc0b9"),0.0,0.9)
    var plinth := sampled_stone("red_granite.jpg",Color("#625a55"),0.48,1.3)
    var wall_granite: Array[StandardMaterial3D]=[]
    for j in range(4):
        var shade := 0.60+float(j)*0.045
        wall_granite.append(sampled_stone("red_granite.jpg",Color(shade,shade,shade),0.38,1.35))
    for side in [-1.0,1.0]:
        var x: float=CX+side*8.90
        box(Vector3(0.30,0.46,105),Vector3(x,0.23,MID),plinth)
        for row in range(4):
            for i in range(88):
                var za: float=ZA+float(i)*1.20
                var zb: float=minf(za+1.20,ZB)
                if zb<=za:continue
                box(Vector3(0.31,0.397,zb-za-0.003),Vector3(x,0.64+float(row)*0.40,(za+zb)*0.5),wall_granite[(i+row*3)%4])
        var lower: Array[Vector2]=[]
        for j in range(25):
            var t: float=float(j)/24.0
            lower.append(Vector2(x-side*0.22*sin(t*PI),2.02+t*1.65))
        profile(lower,ZA,ZB,white)
        for i in range(51):
            var zz: float=ZA+float(i)*2.10
            # Hairline panel joints follow the curved wall face.
            profile(lower,zz,zz+0.007,seam)
        for i in range(88):
            var za: float=ZA+float(i)*1.20
            var zb: float=minf(za+1.20,ZB)
            if zb<=za:continue
            box(Vector3(0.44,0.50,zb-za-0.003),Vector3(x-side*0.10,3.99,(za+zb)*0.5),pale_stone)
        box(Vector3(0.47,0.025,105),Vector3(x-side*0.12,3.84,MID),housing)
        rod(Vector3(x-side*0.17,3.56,ZA),Vector3(x-side*0.17,3.56,ZB),0.012,cream)
        for i in range(71):
            var zz: float=ZA+float(i)*1.5
            rod(Vector3(x-side*0.14,3.56,zz),Vector3(x-side*0.14,3.68,zz),0.008,metal)
        for z in [12.0,39.612,67.2]:
            box(Vector3(0.52,0.78,4.00),Vector3(x-side*0.15,3.98,float(z)),pale_stone)
            _wall_letters("УСХОД" if side>0.0 else "ВОСТОК",Vector3(x-side*0.43,3.98,float(z)),-side*PI/2.0)
        for z in [12.0,39.612,67.2]:
            picture("line_to_uruchye.svg" if side>0.0 else "line_to_malinovka.svg",Vector2(4.30,0.68),Vector3(x-side*0.26,2.51,float(z)),-side*PI/2.0,true)

func _wall_letters(value: String,p: Vector3,yaw: float) -> void:
    # 8006/8012: gold faces with a broad dark bronze rim, raised off marble.
    # Build the outline per glyph so its thickness does not distort spacing.
    var font: Font=preload("res://modules/stations/vostok/art/station_letters.ttf")
    var root := Node3D.new()
    root.name="RaisedStationName_"+value
    root.position=p
    root.rotation.y=yaw
    add_child(root)
    var face := _material(Color("#c8a463"),0.48,0.32)
    var outline := _material(Color("#514940"),0.52,0.42)
    var pixel := 0.0071
    var tracking := 0.045
    var total := font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,100).x*pixel+tracking*float(value.length()-1)
    var cursor := -total*0.5
    for character in value:
        var advance := font.get_string_size(character,HORIZONTAL_ALIGNMENT_LEFT,-1,100).x*pixel
        for layer in range(2):
            var mesh := TextMesh.new()
            mesh.font=font
            mesh.text=character
            mesh.font_size=100
            mesh.pixel_size=pixel
            mesh.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
            mesh.depth=0.065 if layer==0 else 0.016
            mesh.material=outline if layer==0 else face
            var node := MeshInstance3D.new()
            node.mesh=mesh
            node.position=Vector3(cursor+advance*0.5,-0.007 if layer==0 else 0.0,0.0 if layer==0 else 0.049)
            node.scale=Vector3(1.12,1.12,1.0) if layer==0 else Vector3.ONE
            root.add_child(node)
        cursor+=advance+tracking

func _vault() -> void:
    var coffer := _material(Color("#d6d8d2"),0.0,0.86)
    var joint := _material(Color("#bdc0b9"),0.0,0.88)
    var rim := _material(Color("#b5b6ad"),0.28,0.43)
    glow.albedo_color=Color("#fffdf0")
    glow.emission=Color(1.0,0.985,0.91)
    glow.emission_energy_multiplier=1.45
    for side in [-1.0,1.0]:
        curved_band(float(side),0.0,PI/2.0,ZA,ZB,SPRING,CROWN_RISE,0.0,white)
    # Photo 7959: side petals with rounded flared ends; a smooth open crown.
    for i in range(50):
        var z: float=ZA+float(i)*2.10
        for side in [-1.0,1.0]:
            _vault_rib(float(side),z,coffer)
            curved_band(float(side),0.012,0.355,z+0.21,z+1.99,SPRING,CROWN_RISE,0.012,coffer)
            for j in range(3):
                var zz: float=z+0.29+float(j)*0.56
                _rounded_diffuser(float(side),zz,zz+0.48,rim)
        if i%3==0:
            for side in [-1.0,1.0]:
                curved_band(float(side),0.75,PI/2.0,z,z+0.003,SPRING,CROWN_RISE,0.002,joint)

func _rib_width(angle: float) -> float:
    # The widened petal head rolls back into the shell instead of ending in a
    # flat disconnected strip. All ribs stop short of the centre of the vault.
    var round_head := sqrt(maxf(0.0,1.0-pow((angle-0.685)/0.072,2.0)))
    return 0.08+round_head*0.15

func _vault_rib(side: float,z: float,edge: Material) -> void:
    for i in range(48):
        var a0: float=float(i)*0.76/48.0
        var a1: float=float(i+1)*0.76/48.0
        var depth0 := 0.15*(1.0-smoothstep(0.70,0.76,a0))
        var depth1 := 0.15*(1.0-smoothstep(0.70,0.76,a1))
        var a: Vector2=arc_point(side,a0,SPRING,CROWN_RISE,depth0)
        var b: Vector2=arc_point(side,a1,SPRING,CROWN_RISE,depth1)
        var back_a: Vector2=arc_point(side,a0,SPRING,CROWN_RISE,0.0)
        var back_b: Vector2=arc_point(side,a1,SPRING,CROWN_RISE,0.0)
        var wa := _rib_width(a0)
        var wb := _rib_width(a1)
        quad(Vector3(a.x,a.y,z-wa),Vector3(b.x,b.y,z-wb),Vector3(b.x,b.y,z+wb),Vector3(a.x,a.y,z+wa),white,Vector3(CX-a.x,-1,0))
        for face in [-1.0,1.0]:
            quad(Vector3(back_a.x,back_a.y,z+face*wa),Vector3(back_b.x,back_b.y,z+face*wb),Vector3(b.x,b.y,z+face*wb),Vector3(a.x,a.y,z+face*wa),edge,Vector3(0,0,face))

func _rounded_diffuser(side: float,z0: float,z1: float,rim: Material) -> void:
    # Rounded luminous panes sit inside a thin grey/cream bezel, three per bay.
    # Arc strips are tessellated directly, retaining the bowed wall profile.
    for layer in range(2):
        var mat: Material=rim if layer==0 else glow
        var margin := 0.025 if layer==0 else 0.0
        for j in range(24):
            var t0: float=float(j)/24.0
            var t1: float=float(j+1)/24.0
            var a0 := 0.025+t0*0.30
            var a1 := 0.025+t1*0.30
            var round0 := 0.085*(1.0-sqrt(maxf(0.0,1.0-pow(maxf(0.0,absf(t0-0.5)-0.34)/0.16,2.0))))
            var round1 := 0.085*(1.0-sqrt(maxf(0.0,1.0-pow(maxf(0.0,absf(t1-0.5)-0.34)/0.16,2.0))))
            var a: Vector2=arc_point(side,a0,SPRING,CROWN_RISE,0.032+float(layer)*0.010)
            var b: Vector2=arc_point(side,a1,SPRING,CROWN_RISE,0.032+float(layer)*0.010)
            quad(Vector3(a.x,a.y,z0+round0-margin),Vector3(b.x,b.y,z0+round1-margin),Vector3(b.x,b.y,z1-round1+margin),Vector3(a.x,a.y,z1-round0+margin),mat,Vector3(CX-a.x,-1,0))

func _lighting() -> void:
    # The diffuser's emissive face is paired with actual light on nearby stone.
    # Local object batches let these lamps reach every part of the 105 m hall.
    for i in range(10):
        var z: float=ZA+5.25+float(i)*10.5
        for side in [-1.0,1.0]:
            var lamp := OmniLight3D.new()
            lamp.name="VaultLight_%02d_%s" % [i,"L" if side<0.0 else "R"]
            lamp.position=Vector3(CX+side*6.4,5.25,z)
            lamp.light_color=Color(1.0,0.975,0.92)
            lamp.light_energy=0.75
            lamp.light_specular=0.45
            lamp.omni_range=13.0
            lamp.omni_attenuation=0.85
            lamp.shadow_enabled=false
            add_child(lamp)

func _ends() -> void:
    for direction in [-1.0,1.0]:
        var start: float=STAIR_NORTH if direction<0.0 else STAIR_SOUTH
        var end: float=ZA if direction<0.0 else ZB
        _photo_stairs(direction,start)
        _upper_landing(direction,end)
        for side in [-1.0,1.0]:
            var tx: float=CX+side*6.362
            _tunnel_mouth(tx,end,direction)
            var p := Vector3(CX+side*4.60,FY+1.39,end-direction*2.0)
            _driver_mirror(p,direction,side)

func _photo_stairs(direction: float,start: float) -> void:
    var width := 8.10
    var rise := 0.115
    var run := 0.255
    var landing := 0.95
    var yellow := _material(Color("#d5b12c"),0.0,0.7)
    for i in range(40):
        var height: float=float(i+1)*rise
        var z: float=start+direction*(float(i)*run+(landing if i>=22 else 0.0))
        box(Vector3(width,height,run+0.002),Vector3(CX,FY+height*0.5,z),stair_stone)
        if i in [0,21,22,39]:box(Vector3(width,0.012,0.045),Vector3(CX,FY+height+0.007,z-direction*0.106),yellow)
    var offsets: Array[Vector2]=[Vector2(-0.13,0),Vector2(5.48,2.53),Vector2(6.43,2.53),Vector2(11.10,4.60)]
    box(Vector3(width,0.17,landing),Vector3(CX,FY+2.53-0.085,start+direction*5.95),stair_stone)
    for side in [-1.0,1.0]:
        var x: float=CX+side*(width*0.5+0.12)
        for i in range(offsets.size()-1):
            var a: Vector2=offsets[i];var b: Vector2=offsets[i+1]
            for face in [-1.0,1.0]:
                var xx: float=x+face*0.12
                quad(Vector3(xx,FY+a.y,start+direction*a.x),Vector3(xx,FY+b.y,start+direction*b.x),Vector3(xx,FY+b.y+0.89,start+direction*b.x),Vector3(xx,FY+a.y+0.89,start+direction*a.x),pale_stone,Vector3(face,0,0))
            quad(Vector3(x-0.15,FY+a.y+0.90,start+direction*a.x),Vector3(x+0.15,FY+a.y+0.90,start+direction*a.x),Vector3(x+0.15,FY+b.y+0.90,start+direction*b.x),Vector3(x-0.15,FY+b.y+0.90,start+direction*b.x),redstone,Vector3.UP)
            rod(Vector3(x,FY+a.y+0.94,start+direction*a.x),Vector3(x,FY+b.y+0.94,start+direction*b.x),0.033,housing)
        picture("stair_caution.svg",Vector2(0.16,0.23),Vector3(x-direction*0.01,FY+0.61,start-direction*0.135),0.0 if direction<0.0 else PI)
    foot_grille(start-direction*0.40,8.0)
    board("exit_north.svg" if direction<0.0 else "exit_south.svg",Vector3(CX,6.89,start+direction*6.4),Vector2(5.65,0.82))

func _upper_landing(direction: float,end: float) -> void:
    var y: float=FY+4.60
    box(Vector3(17.9,0.32,5.4),Vector3(CX,y-0.16,end+direction*1.10),pale_stone)
    # Gallery balustrades stand above both tunnel mouths, beside the staircase.
    for side in [-1.0,1.0]:
        var x: float=CX+side*6.60
        box(Vector3(4.5,0.63,0.24),Vector3(x,y+0.27,end-direction*0.44),pale_stone)
        for height in [0.65,0.89,1.10]:
            rod(Vector3(x-2.20,y+float(height),end-direction*0.44),Vector3(x+2.20,y+float(height),end-direction*0.44),0.022,metal)
        for dx in [-2.18,0.0,2.18]:rod(Vector3(x+float(dx),y+0.55,end-direction*0.44),Vector3(x+float(dx),y+1.10,end-direction*0.44),0.022,metal)
    box(Vector3(17.9,2.6,0.22),Vector3(CX,y+1.30,end+direction*3.4),pale_stone)
    # A real vestibule threshold, with turnstile cabinets and glazed attendant cabin.
    for i in range(7):
        var x: float=CX-2.8+float(i)*0.93
        box(Vector3(0.22,0.95,1.0),Vector3(x,y+0.475,end+direction*2.25),metal)
        box(Vector3(0.25,0.07,0.42),Vector3(x,y+0.96,end+direction*2.02),black)
        rod(Vector3(x,y+0.71,end+direction*2.0),Vector3(x+0.44,y+0.71,end+direction*2.0),0.018,metal)
    var blue := _material(Color("#274f75"),0.35,0.30)
    var glass := _material(Color(0.19,0.27,0.30,0.28),0.3,0.15)
    glass.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
    var cabin_x: float=CX+3.40*direction
    box(Vector3(1.18,0.75,1.20),Vector3(cabin_x,y+0.375,end+direction*1.50),blue)
    box(Vector3(1.18,1.25,0.035),Vector3(cabin_x,y+1.375,end+direction*0.90),glass)
    for dx in [-0.59,0.59]:rod(Vector3(cabin_x+float(dx),y+0.75,end+direction*0.90),Vector3(cabin_x+float(dx),y+2.0,end+direction*0.90),0.025,blue)
    for j in range(10):
        var zz: float=end-direction*10.5+direction*float(j)*1.45
        # Curved transverse strip lights belong only to the lower end canopy.
        for k in range(24):
            var x0: float=-4.1+float(k)*8.2/24.0
            var x1: float=-4.1+float(k+1)*8.2/24.0
            var h0: float=8.10-0.50*pow(x0/4.1,2.0)
            var h1: float=8.10-0.50*pow(x1/4.1,2.0)
            rod(Vector3(CX+x0,h0,zz),Vector3(CX+x1,h1,zz),0.026,glow)
    box(Vector3(6.8,0.19,0.10),Vector3(CX,7.76,end+direction*3.24),black)
    for i in range(70):box(Vector3(0.025,0.24,0.07),Vector3(CX-3.35+float(i)*0.096,7.60,end+direction*3.16),black)

func _tunnel_mouth(x: float,z: float,direction: float) -> void:
    for j in range(48):
        var a: float=float(j)*TAU/48.0
        var b: float=float(j+1)*TAU/48.0
        var p0 := Vector3(x+2.04*cos(a),2.13+2.35*sin(a),z)
        var p1 := Vector3(x+2.04*cos(b),2.13+2.35*sin(b),z)
        quad(p0,p1,p1+Vector3(0,0,direction*8.0),p0+Vector3(0,0,direction*8.0),black,Vector3(-cos(a),-sin(a),0))
        for depth in [0.08,1.50,3.0,4.5,6.0]:
            var offset := Vector3(0,0,direction*float(depth))
            rod(p0+offset,p1+offset,0.035,housing)
    box(Vector3(4.12,4.8,0.08),Vector3(x,2.13,z+direction*8.0),black)
    for side in [-1.0,1.0]:
        for y in [1.2,1.6,2.0,2.4]:
            rod(Vector3(x+side*1.99,float(y),z),Vector3(x+side*1.99,float(y),z+direction*7.8),0.018,black)

func _rounded_box(size: Vector3,p: Vector3,mat: Material,r: float=0.05) -> void:
    var pts := PackedVector2Array()
    for corner in range(4):
        var center := Vector2(p.x+(size.x*0.5-r)*(1.0 if corner in [0,3] else -1.0),p.y+(size.y*0.5-r)*(1.0 if corner in [0,1] else -1.0))
        for j in range(7):
            var a: float=float(corner)*PI/2.0+float(j)*PI/12.0
            pts.append(center+Vector2(cos(a),sin(a))*r)
    extrusion(pts,p.z-size.z*0.5,p.z+size.z*0.5,mat)

func _photo_pylon(z: float) -> void:
    _rounded_box(Vector3(0.54,1.0,0.54),Vector3(CX,FY+0.50,z),housing,0.05)
    _rounded_box(Vector3(0.91,2.16,0.85),Vector3(CX,FY+2.08,z),housing,0.065)
    for face in [-1.0,1.0]:
        var yaw: float=0.0 if face>0.0 else PI
        picture("pylon_track1.svg" if face>0.0 else "pylon_track2.svg",Vector2(0.70,1.99),Vector3(CX,FY+2.08,z+face*0.434),yaw)
        picture("pylon_exit_a.svg" if face>0.0 else "pylon_exit_b.svg",Vector2(0.74,1.99),Vector3(CX+face*0.463,FY+2.08,z),face*PI/2.0)
        # Panel screws and red protective tubular cradle around the ribbed top unit.
        for dx in [-0.405,0.405]:
            for y in [FY+1.08,FY+3.08]:sphere(Vector3(0.018,0.018,0.014),Vector3(CX+float(dx),float(y),z+face*0.435),metal)
        _rounded_tube(Vector3(CX,FY+3.51,z+face*0.35),Vector2(0.98,0.69),0.12,0.031,red_guard)
    _rounded_box(Vector3(0.86,0.62,0.70),Vector3(CX,FY+3.51,z),housing,0.09)
    for face in [-1.0,1.0]:
        for i in range(13):
            box(Vector3(0.018,0.48,0.015),Vector3(CX-0.34+float(i)*0.056,FY+3.51,z+face*0.358),black)
        sphere(Vector3(0.115,0.115,0.008),Vector3(CX,FY+3.37,z+face*0.37),black)
    box(Vector3(0.18,0.22,0.18),Vector3(CX,FY+3.93,z),metal)
    _rounded_box(Vector3(1.45,0.84,0.075),Vector3(CX,FY+4.40,z),black,0.014)
    for face in [-1.0,1.0]:picture("screen_year_2026.jpg",Vector2(1.39,0.782),Vector3(CX,FY+4.40,z+face*0.044),0.0 if face>0.0 else PI)
    # Stainless waist rail wraps the pedestal and bends away at the two ends.
    for side in [-1.0,1.0]:
        var x: float=CX+side*0.27
        rod(Vector3(x,FY+0.10,z),Vector3(x,FY+0.89,z),0.026,metal)
        rod(Vector3(x,FY+0.89,z),Vector3(x+side*0.32,FY+1.02,z),0.026,metal)
        rod(Vector3(x+side*0.32,FY+1.02,z-0.48),Vector3(x+side*0.32,FY+1.02,z+0.48),0.026,metal)
        rod(Vector3(x+side*0.32,FY+1.02,z-0.48),Vector3(CX,FY+1.02,z-0.58),0.026,metal)
        rod(Vector3(x+side*0.32,FY+1.02,z+0.48),Vector3(CX,FY+1.02,z+0.58),0.026,metal)
    _cctv(Vector3(CX+0.62,FY+3.70,z))

func _rounded_tube(p: Vector3,size: Vector2,r: float,tube: float,mat: Material) -> void:
    var pts: Array[Vector3]=[]
    for i in range(4):
        var c := Vector2((size.x*0.5-r)*(1.0 if i in [0,3] else -1.0),(size.y*0.5-r)*(1.0 if i in [0,1] else -1.0))
        for j in range(9):
            var a: float=float(i)*PI/2.0+float(j)*PI/16.0
            pts.append(p+Vector3(c.x+r*cos(a),c.y+r*sin(a),0))
    for i in range(pts.size()):rod(pts[i],pts[(i+1)%pts.size()],tube,mat)

func _cctv(p: Vector3) -> void:
    rod(p-Vector3(0.2,0.2,0),p,0.016,metal)
    box(Vector3(0.12,0.10,0.26),p+Vector3(0,0.06,0),cream)
    box(Vector3(0.15,0.018,0.30),p+Vector3(0,0.12,-0.018),cream)
    sphere(Vector3(0.056,0.056,0.012),p+Vector3(0,0.06,0.135),black)

func _five_seat_bench(p: Vector3) -> void:
    # Five separate wide wooden seat modules, longitudinal on the platform centreline.
    var oak := wood_material()
    for i in range(5):
        var z: float=p.z-0.96+float(i)*0.48
        box(Vector3(0.68,0.10,0.45),Vector3(p.x,p.y+0.47,z),oak)
        for d in [-0.13,0.13]:box(Vector3(0.69,0.006,0.009),Vector3(p.x,p.y+0.523,z+float(d)),housing)
        box(Vector3(0.65,0.07,0.035),Vector3(p.x,p.y+0.40,z-0.235),housing)
    for z in [-0.86,0.86]:box(Vector3(0.49,0.40,0.16),p+Vector3(0,0.20,float(z)),housing)

func _driver_mirror(p: Vector3,direction: float,side: float) -> void:
    var root := Node3D.new()
    root.name="DriverMirror";root.position=p;root.rotation.y=(0.0 if direction<0.0 else PI)-side*0.16
    add_child(root)
    var frame := _material(Color("#e3e9df"),0.12,0.38)
    var blue := _material(Color("#265785"),0.3,0.42)
    # Build in local coordinates so both portal ends face back into the hall.
    var script := preload("res://modules/stations/vostok/driver_mirrors.gd")
    var mirror := MeshInstance3D.new();mirror.set_script(script)
    mirror.name="ReflectingSurface";mirror.position=Vector3(0,0,0.014)
    var q := QuadMesh.new();q.size=Vector2(0.55,1.53)
    mirror.mesh=q;mirror.set_meta("mirror_size",q.size);root.add_child(mirror)
    # White rounded rectangular frame, blue pedestal, stainless track-edge guard.
    var frame_path: Array[Vector3]=[]
    for i in range(4):
        var c := Vector2(0.235*(1.0 if i in [0,3] else -1.0),0.70*(1.0 if i in [0,1] else -1.0))
        for j in range(9):
            var a: float=float(i)*PI/2.0+float(j)*PI/16.0
            frame_path.append(Vector3(c.x+0.09*cos(a),c.y+0.09*sin(a),0))
    for i in range(frame_path.size()):_local_rod(root,frame_path[i],frame_path[(i+1)%frame_path.size()],0.028,frame)
    _local_rod(root,Vector3(0,-1.30,0),Vector3(0,-0.78,0),0.075,blue)
    for dx in [-0.41,0.41]:
        _local_rod(root,Vector3(float(dx),-1.39,-0.02),Vector3(float(dx),-0.51,-0.02),0.025,metal)
        _local_rod(root,Vector3(float(dx),-0.51,-0.02),Vector3(float(dx),-0.51,0.30),0.025,metal)
    _local_rod(root,Vector3(-0.41,-0.51,0.30),Vector3(0.41,-0.51,0.30),0.025,metal)

func _local_rod(parent: Node3D,a: Vector3,b: Vector3,r: float,mat: Material) -> void:
    var mesh := CylinderMesh.new();mesh.top_radius=r;mesh.bottom_radius=r;mesh.height=a.distance_to(b);mesh.radial_segments=12;mesh.material=mat
    var n := MeshInstance3D.new();n.mesh=mesh;n.position=(a+b)*0.5
    var axis := Vector3.UP.cross((b-a).normalized())
    if axis.length_squared()>0.00001:n.basis=Basis(axis.normalized(),Vector3.UP.angle_to((b-a).normalized()))
    parent.add_child(n)

func _suspended_monitor() -> void:
    var z := 51.0
    box(Vector3(1.30,0.76,0.09),Vector3(CX,6.65,z),black)
    for dx in [-0.43,0.43]:rod(Vector3(CX+float(dx),7.90,z),Vector3(CX+float(dx),7.04,z),0.012,black)
    for i in range(15):
        var a: float=float(i)*PI/30.0
        var b: float=float(i+1)*PI/30.0
        rod(Vector3(CX-8.9*cos(a),SPRING+CROWN_RISE*sin(a)-0.08,z),Vector3(CX-8.9*cos(b),SPRING+CROWN_RISE*sin(b)-0.08,z),0.014,housing)

func _track_finishes() -> void:
    # Same detailed rails, fastening plates, ties, grain and contact rail as
    # Uruchye V68, kept inside this package so later station edits stay isolated.
    var trackwork := preload("res://modules/stations/vostok/trackwork.gd").new()
    trackwork.name="DetailedVostokTrackwork"
    add_child(trackwork)

func _floor_fittings() -> void:
    for z in [7.0,29.0,53.0,75.0]:
        cylinder(0.17,0.011,Vector3(CX+1.42,FY+0.011,float(z)),housing)
        for i in range(7):box(Vector3(0.010,0.014,0.24),Vector3(CX+1.33+float(i)*0.03,FY+0.019,float(z)),black)
        box(Vector3(0.30,0.015,0.30),Vector3(CX+0.85,FY+0.014,float(z)+2.0),housing)
        for i in range(8):box(Vector3(0.012,0.019,0.24),Vector3(CX+0.74+float(i)*0.03,FY+0.022,float(z)+2.0),black)

func _photo_clocks() -> void:
    # Retain the existing Minsk-time and per-track departure logic; match red displays.
    var infrastructure := get_node("StationInfrastructure")
    infrastructure.set("_amber",Color(1.0,0.12,0.045))
    var displays: Array=infrastructure.get("_displays")
    for display in displays:
        for i in range(70,76):display.set_instance_color(i,Color(1.0,0.12,0.045))
    for node in infrastructure.get_children():
        if node is Node3D and "Portal" in str(node.name):
            node.position.y=4.76
            var s: float=1.0 if node.position.x>CX else -1.0
            node.position.x=CX+s*6.40

func _stair_material() -> ShaderMaterial:
    var shader := Shader.new()
    shader.code="""shader_type spatial;
uniform sampler2D stone_tex : source_color,filter_linear_mipmap,repeat_enable;
varying vec3 p;void vertex(){p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){vec3 c=texture(stone_tex,vec2(p.x*0.65,p.z*1.8+p.y*2.4)).rgb;ALBEDO=c*0.88;ROUGHNESS=0.36;SPECULAR=0.55;}
"""
    var m := ShaderMaterial.new();m.shader=shader;m.set_shader_parameter("stone_tex",load(ART+"stair_marble.jpg"));return m
