extends "res://modules/stations/oktyabrskaya/station_builder.gd"
## Oktyabrskaya V66: owner archive, both entire videos, central transfer kept open underneath.
const ART := "res://modules/stations/oktyabrskaya/art/"
const SOUTH := 84.20
const NORTH := ZA+ZB-SOUTH
const PITCH := 4.80
const COL_X := 2.55
const DECK := FY+3.15
var wall_stone: StandardMaterial3D
var column_stones: Array[StandardMaterial3D]=[]
var stair_stone: StandardMaterial3D
var trim: StandardMaterial3D
var yellow: StandardMaterial3D
var floor_stone: StandardMaterial3D
var floor_red: StandardMaterial3D
var oak: StandardMaterial3D
var lantern_glass: ShaderMaterial
var ceiling_wash: ShaderMaterial
var layout: Dictionary = {}
var charcoal: StandardMaterial3D
var lettering_meshes: Dictionary = {}
var lettering_profile: Dictionary = {}
var bronze_name_material: ShaderMaterial

func _ready() -> void:
    super._ready();begin_station()
    layout=JSON.parse_string(FileAccess.get_file_as_string("res://modules/stations/oktyabrskaya/architecture_profile.json"))
    lantern_glass=ShaderMaterial.new()
    lantern_glass.shader=preload("res://modules/stations/oktyabrskaya/lantern_glass.gdshader")
    lantern_glass.set_shader_parameter("glass_photo",load(ART+"amber_glass.jpg"))
    lantern_glass.set_shader_parameter("emission_strength",float(layout["lantern_emission"]))
    lantern_glass.set_shader_parameter("grid_count",Vector2(float(layout["glass_columns"]),float(layout["glass_rows"])))
    ceiling_wash=ShaderMaterial.new()
    ceiling_wash.shader=preload("res://modules/stations/oktyabrskaya/ceiling_wash.gdshader")
    ceiling_wash.set_shader_parameter("paint",load(ART+"ceiling_paint.jpg"))
    ceiling_wash.set_shader_parameter("station_center_x",CX)
    ceiling_wash.set_shader_parameter("column_x",COL_X)
    ceiling_wash.set_shader_parameter("column_pitch",PITCH)
    ceiling_wash.set_shader_parameter("transfer_mid_z",MID)
    # Disable inherited long-range fills; local fixtures define this station's light.
    for child in get_children():
        if child is OmniLight3D:child.hide()
    white=_photo("ceiling_paint.jpg",Vector2(1.20,1.20),0.86)
    wall_stone=_photo("wall_marble.jpg",Vector2(0.80,0.80),0.42)
    granite=_photo("plinth_granite.jpg",Vector2(0.65,0.65),0.48)
    stair_stone=_photo("stair_granite.jpg",Vector2(0.55,0.55),0.61)
    floor_stone=_photo("floor_grey.jpg",Vector2(0.55,0.55),0.56)
    floor_red=_photo("floor_red.jpg",Vector2(0.55,0.55),0.46)
    floor_red.normal_enabled=true;floor_red.normal_texture=load(ART+"floor_red_normal.png");floor_red.normal_scale=0.12
    trim=_material(Color("#ada181"),0.12,0.65)
    yellow=_material(Color("#d7b13e"),0,0.65)
    charcoal=_material(Color("#302a20"),0.55,0.36)
    oak=_photo("bench_oak.jpg",Vector2(0.65,0.30),0.48)
    for i in range(4):
        var mat := _photo("column_marble.jpg" if i%2==0 else "column_marble_alt.jpg",Vector2(0.8,0.8),0.39)
        mat.uv1_offset=Vector3(float(i)*0.17,float(i)*0.27,0);column_stones.append(mat)
    _floor();_walls();_columns();_ceiling();_transfer()
    _escalators(SOUTH);_end_art(SOUTH,"south")
    construction_transform=Transform3D(Basis(Vector3.UP,PI),Vector3(2.0*CX,0,ZA+ZB))
    _escalators(SOUTH);_end_art(SOUTH,"north")
    construction_transform=Transform3D.IDENTITY
    _signs();_track_details();_portal_equipment();_floor_fittings()
    for side in [-1.0,1.0]:
        for bay in [2,5,12,15]:
            # Seat modules occupy complete clear bays, not the column centres.
            _bench(Vector3(CX+side*COL_X,FY,-1.2+(float(bay)+0.5)*PITCH))
    for z in [18.0,29.3,49.9,65.0]:_monitor(float(z))
    var glass_key := str(lantern_glass.get_instance_id())
    if surfaces.has(glass_key):
        var glass_surface: SurfaceTool=surfaces[glass_key].surface
        glass_surface.generate_tangents()
    flush()

func _photo(file: String,slab: Vector2,roughness: float) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_texture=load(ART+file)
    mat.transparency=BaseMaterial3D.TRANSPARENCY_DISABLED
    mat.cull_mode=BaseMaterial3D.CULL_DISABLED
    mat.roughness=roughness
    mat.uv1_triplanar=true;mat.uv1_world_triplanar=true;mat.uv1_triplanar_sharpness=8.0
    mat.uv1_scale=Vector3(1.0/slab.x,1.0/slab.y,1.0/slab.x)
    mat.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
    return mat

func _floor() -> void:
    (get_node("IslandPlatform") as MeshInstance3D).material_override=floor_red
    for row in range(175):
        for col in range(15):box(Vector3(8.62/15.0-0.002,0.012,0.598),Vector3(CX-4.31+(float(col)+0.5)*8.62/15.0,FY+0.014,ZA+0.30+float(row)*0.60),floor_red)
    for side in [-1.0,1.0]:
        box(Vector3(0.50,0.012,105),Vector3(CX+side*4.75,FY+0.014,MID),floor_stone)
        box(Vector3(0.19,0.012,105),Vector3(CX+side*4.405,FY+0.014,MID),yellow)
        for i in range(1312):
            for dx in [-0.055,0.0,0.055]:cylinder(0.010,0.004,Vector3(CX+side*4.405+float(dx),FY+0.025,ZA+0.04+float(i)*0.08),yellow)

func _walls() -> void:
    var joint := _material(Color("#8b8574"),0,0.77)
    var alternate := _photo("wall_marble_alt.jpg",Vector2(0.8,0.8),0.42)
    var y0: float=FY+0.65
    var ys: Array[float]=[y0,DECK,DECK+2.10,6.90]
    var zs: Array[float]=[ZA,ZB,MID-2.10,MID+2.10]
    for i in range(9):
        var y: float=y0+float(i)*0.60
        if y<6.90:ys.append(y)
    for i in range(88):zs.append(ZA+float(i)*1.20)
    ys.sort();zs.sort()
    for side in [-1.0,1.0]:
        var x: float=CX+side*8.90
        box(Vector3(0.28,y0,105),Vector3(x,y0*0.5,MID),granite)
        for iy in range(ys.size()-1):
            for iz in range(zs.size()-1):
                var h: float=ys[iy+1]-ys[iy];var w: float=zs[iz+1]-zs[iz]
                if h<0.004 or w<0.004:continue
                var y: float=(ys[iy+1]+ys[iy])*0.5;var z: float=(zs[iz+1]+zs[iz])*0.5
                if side>0 and y>DECK and y<DECK+2.1 and abs(z-MID)<2.1:continue
                box(Vector3(0.28,h,w),Vector3(x,y,z),joint)
                box(Vector3(0.012,h-0.003,w-0.003),Vector3(x-side*0.145,y,z),alternate if (iy+iz)%6==0 else wall_stone)
        for h in [3.55,4.02]:rod(Vector3(x-side*0.18,float(h),ZA),Vector3(x-side*0.18,float(h),ZB),0.009,metal)
        for j in range(5):
            var z: float=2.5+float(j)*18.5
            # Only draw complete route boards inside the platform wall; no cropped fragment at the portal.
            if z+7.4+2.35<SOUTH-0.30:
                picture("route_track1.svg" if side>0 else "route_track2.svg",Vector2(4.7,0.744),Vector3(x-side*0.18,2.68,z+7.4),-side*PI/2.0,true)
            _name_letters("КАСТРЫЧНІЦКАЯ" if side>0 else "ОКТЯБРЬСКАЯ",Vector3(x-side*0.18,3.24,z),-side*PI/2.0)

func _name_letters(text: String,p: Vector3,yaw: float) -> void:
    # Dedicated heavy outlines reconstructed from owner photographs, with their small counters.
    # The two complete words share meshes across every occurrence on the platform walls.
    if lettering_profile.is_empty():
        lettering_profile=JSON.parse_string(FileAccess.get_file_as_string("res://modules/stations/oktyabrskaya/art/bronze_letter_shapes.json"))
    if bronze_name_material==null:
        bronze_name_material=ShaderMaterial.new()
        bronze_name_material.shader=preload("res://modules/stations/oktyabrskaya/bronze_letters.gdshader")
    if not lettering_meshes.has("__cap_probe"):
        var cap_mesh := TextMesh.new()
        cap_mesh.font=preload("res://modules/stations/oktyabrskaya/art/bronze_station_letters.ttf")
        cap_mesh.text="Н"
        cap_mesh.font_size=int(lettering_profile["textmesh_font_size"])
        cap_mesh.pixel_size=float(lettering_profile["textmesh_pixel_size"])
        lettering_meshes["__cap_probe"]=cap_mesh
    if not lettering_meshes.has(text):
        var generated_mesh := TextMesh.new()
        generated_mesh.font=preload("res://modules/stations/oktyabrskaya/art/bronze_station_letters.ttf")
        generated_mesh.text=text
        generated_mesh.font_size=int(lettering_profile["textmesh_font_size"])
        generated_mesh.pixel_size=float(lettering_profile["textmesh_pixel_size"])
        generated_mesh.depth=float(lettering_profile["extrusion_depth_m"])
        generated_mesh.material=bronze_name_material
        lettering_meshes[text]=generated_mesh
    var mesh: TextMesh=lettering_meshes[text]
    var bounds: AABB=mesh.get_aabb()
    var cap_probe: TextMesh=lettering_meshes["__cap_probe"]
    var native_cap_height: float=maxf(cap_probe.get_aabb().size.y,0.00001)
    # Godot 4.3 clamps TextMesh.font_size to 127. Normalize the actual cap mesh,
    # including font metrics/pixel size, instead of assuming one local metre.
    # The Н probe has no descender, so Ц keeps its proper tail below the common baseline.
    var cap_height: float=float(lettering_profile["cap_height_m"])
    var scale_xy: float=cap_height/native_cap_height
    var basis := Basis(Vector3.UP,yaw)*Basis.from_scale(Vector3(scale_xy,scale_xy,1.0))
    var cap_top: float=bounds.position.y+bounds.size.y
    var centre := Vector3(bounds.position.x+bounds.size.x*0.5,cap_top-native_cap_height*0.5,bounds.position.z)
    # Existing mounting datum is 29mm in front of the stone skin; put the back at a 12mm clearance.
    var normal := Basis(Vector3.UP,yaw).z
    var back_plane: Vector3=p+normal*(float(lettering_profile["wall_clearance_m"])-0.029)
    var node := MeshInstance3D.new();node.name="HeavyBronzeStationName"
    node.mesh=mesh;node.basis=basis;node.position=back_plane-basis*centre
    node.set_meta("station_text",text)
    node.set_meta("extrusion_depth_m",float(lettering_profile["extrusion_depth_m"]))
    add_child(node)

func _column_profile() -> PackedVector2Array:
    var p := PackedVector2Array()
    # Four narrow radial ribs with broad concave marble flutes between them.
    for face in range(4):
        var angle: float=float(face)*PI/2.0
        for j in range(8):
            var t: float=float(j)/8.0
            var a: float=angle+t*PI/2.0
            var radius: float=0.46-0.16*pow(sin(t*PI),0.70)
            p.append(Vector2(cos(a),sin(a))*radius)
    return p

func _vertical_profile(points: PackedVector2Array,p: Vector3,y0: float,y1: float,mat: Material) -> void:
    for i in range(points.size()):
        var a: Vector2=points[i];var b: Vector2=points[(i+1)%points.size()]
        if a.distance_to(b)<0.0001:continue
        quad(p+Vector3(a.x,y0,a.y),p+Vector3(b.x,y0,b.y),p+Vector3(b.x,y1,b.y),p+Vector3(a.x,y1,a.y),mat,Vector3(a.x+b.x,0,a.y+b.y))
    var caps := Geometry2D.triangulate_polygon(points)
    for j in range(0,caps.size(),3):
        var a: Vector2=points[caps[j]];var b: Vector2=points[caps[j+1]];var c: Vector2=points[caps[j+2]]
        for y in [y0,y1]:triangle(p+Vector3(a.x,float(y),a.y),p+Vector3(b.x,float(y),b.y),p+Vector3(c.x,float(y),c.y),mat,Vector3.DOWN if y==y0 else Vector3.UP)

func _column_is_clear(side: float,z: float) -> bool:
    # Keep the entrance bays open: remove the nearest pair at each escalator end.
    if z<-1.1 or z>80.3:return false
    # Retain the earlier clearance around the transfer deck.
    return not (side>0.0 and absf(z-MID)<2.10+0.46)

func _columns() -> void:
    var profile: PackedVector2Array=_column_profile()
    for side in [-1.0,1.0]:
        for i in range(18):
            var z: float=-1.2+float(i)*PITCH
            if not _column_is_clear(float(side),z):continue
            var o := Vector3(CX+side*COL_X,0,z)
            var column_mat: StandardMaterial3D=column_stones[i%4]
            _vertical_profile(profile,o,FY,FY+0.075,charcoal)
            _vertical_profile(profile,o,FY+0.075,5.22,column_mat)
            for y in [FY+1.0,FY+2.0,FY+3.0]:
                for face in range(4):
                    var angle: float=float(face)*PI/2.0
                    var d := Vector3(cos(angle),0,sin(angle))
                    box(Vector3(0.07,0.002,0.008),o+d*0.459+Vector3.UP*float(y),trim,Basis(Vector3.UP,-angle+PI/2.0))
            for face in range(4):
                var angle: float=float(face)*PI/2.0
                _capital_prong(o,angle,column_mat)
                _lantern(o,angle)
            # The dark rolled central dish physically joins the basket bases and stone neck.
            cylinder(0.44,0.065,o+Vector3.UP*5.265,charcoal)
            cylinder(0.39,0.050,o+Vector3.UP*5.215,charcoal)
            var local_light := OmniLight3D.new()
            local_light.name="ColumnLantern_%s_%02d" % ["L" if side<0.0 else "R",i]
            local_light.position=o+Vector3.UP*6.22
            local_light.light_color=Color(1.0,0.93,0.73);local_light.light_energy=0.72
            local_light.omni_range=4.9;local_light.omni_attenuation=1.55;local_light.shadow_enabled=false
            local_light.distance_fade_enabled=true;local_light.distance_fade_begin=24.0;local_light.distance_fade_length=12.0
            add_child(local_light)
            var uplight := SpotLight3D.new()
            uplight.name="LanternUplight_%s_%02d" % ["L" if side<0.0 else "R",i]
            uplight.position=o+Vector3.UP*6.20;uplight.rotation_degrees.x=90.0
            uplight.light_color=Color(1.0,0.97,0.87);uplight.light_energy=1.05
            uplight.spot_range=2.1;uplight.spot_angle=78.0;uplight.spot_attenuation=1.3;uplight.shadow_enabled=false
            uplight.distance_fade_enabled=true;uplight.distance_fade_begin=20.0;uplight.distance_fade_length=12.0
            add_child(uplight)
            var anchor := Marker3D.new();anchor.name="Lantern_%s_%02d" % ["L" if side<0.0 else "R",i]
            anchor.position=o+Vector3.UP*5.76
            anchor.set_meta("glass","amber_square_sections");add_child(anchor)

func _capital_prong(o: Vector3,angle: float,mat: Material) -> void:
    # Closed tapered loft: stone ribs continue from the fluted shaft to the ceiling,
    # instead of four rotated boxes with projecting end corners.
    var radial := Vector3(sin(angle),0,cos(angle))
    var tangent := Vector3(cos(angle),0,-sin(angle))
    var hints: Array[Vector3]=[-radial,tangent,radial,-tangent]
    var heights: Array[float]=[4.94,5.22,5.64,6.12,6.56,6.84]
    var radii: Array[float]=[0.30,0.40,0.52,0.65,0.78,0.86]
    for row in range(heights.size()-1):
        var rings: Array[PackedVector3Array]=[]
        for level in [row,row+1]:
            var t: float=float(level)/float(heights.size()-1)
            var half_width: float=lerpf(0.105,0.080,t)
            var half_depth: float=lerpf(0.140,0.100,t)
            var c: Vector3=o+radial*radii[level]+Vector3.UP*heights[level]
            rings.append(PackedVector3Array([c-tangent*half_width-radial*half_depth,c+tangent*half_width-radial*half_depth,c+tangent*half_width+radial*half_depth,c-tangent*half_width+radial*half_depth]))
        for edge in range(4):
            var next: int=(edge+1)%4
            quad(rings[0][edge],rings[0][next],rings[1][next],rings[1][edge],mat,hints[edge])
        if row==0:quad(rings[0][3],rings[0][2],rings[0][1],rings[0][0],mat,Vector3.DOWN)
        if row==heights.size()-2:quad(rings[1][0],rings[1][1],rings[1][2],rings[1][3],mat,Vector3.UP)

func _lantern_point(o: Vector3,angle: float,u: float,v: float,inset: float=0.0) -> Vector3:
    var a: float=angle+0.20+u*(PI/2.0-0.40)
    var radius: float=lerpf(float(layout["glass_radius_m"][0]),float(layout["glass_radius_m"][1]),v)+inset
    return o+Vector3(sin(a)*radius,lerpf(float(layout["glass_y_m"][0]),float(layout["glass_y_m"][1]),v),cos(a)*radius)

func _glass_triangle(a: Vector3,b: Vector3,c: Vector3,ua: Vector2,ub: Vector2,uc: Vector2,hint: Vector3) -> void:
    var key := str(lantern_glass.get_instance_id())
    if not surfaces.has(key):
        var surface := SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
        surfaces[key]={"surface":surface,"mat":lantern_glass}
    var st: SurfaceTool=surfaces[key].surface
    var normal := (b-a).cross(c-a).normalized()
    var reverse: bool=normal.dot(hint)<0.0
    if reverse:normal=-normal
    var points: Array[Vector3]=[a,b if reverse else c,c if reverse else b]
    var coords: Array[Vector2]=[ua,ub if reverse else uc,uc if reverse else ub]
    for i in range(3):
        st.set_normal(normal);st.set_uv(coords[i]);st.add_vertex(points[i])

func _lantern(o: Vector3,angle: float) -> void:
    # Eight square glass sections across each curved quadrant; fine 3.6mm metal dividers.
    # One UV domain covers the whole basket quadrant, with no opaque gaps between cells.
    var columns: int=int(layout["glass_columns"])
    var rows: int=int(layout["glass_rows"])
    var divider_radius: float=float(layout["divider_radius_m"])
    for col in range(columns):
        var u0: float=float(col)/float(columns);var u1: float=float(col+1)/float(columns)
        for row in range(rows):
            var v0: float=float(row)/float(rows);var v1: float=float(row+1)/float(rows)
            var a: Vector3=_lantern_point(o,angle,u0,v0)
            var b: Vector3=_lantern_point(o,angle,u1,v0)
            var c: Vector3=_lantern_point(o,angle,u1,v1)
            var d: Vector3=_lantern_point(o,angle,u0,v1)
            var hint: Vector3=(a+b+c+d)*0.25-o-Vector3.UP*5.77
            _glass_triangle(a,b,c,Vector2(u0,v0),Vector2(u1,v0),Vector2(u1,v1),hint)
            _glass_triangle(a,c,d,Vector2(u0,v0),Vector2(u1,v1),Vector2(u0,v1),hint)
        for band in [0.0,0.125,0.25,0.375,0.5,0.625,0.75,0.875,1.0]:
            rod(_lantern_point(o,angle,u0,float(band),0.004),_lantern_point(o,angle,u1,float(band),0.004),divider_radius,charcoal)
        # Rolled dark underside bands are separated from the glass, as in the close-up.
        for band in [Vector3(5.31,0.555,0.020),Vector3(5.24,0.515,0.016),Vector3(5.17,0.470,0.012)]:
            var a0: float=angle+0.20+u0*(PI/2.0-0.40)
            var a1: float=angle+0.20+u1*(PI/2.0-0.40)
            var p: Vector3=o+Vector3(sin(a0)*band.y,band.x,cos(a0)*band.y)
            var q: Vector3=o+Vector3(sin(a1)*band.y,band.x,cos(a1)*band.y)
            rod(p,q,band.z,charcoal)
            if col%2==0:sphere(Vector3(0.015,0.015,0.015),(p+q)*0.5+Vector3(0,0.008,0),metal)
    for col in range(columns+1):
        var u: float=float(col)/float(columns)
        rod(_lantern_point(o,angle,u,0,0.004),_lantern_point(o,angle,u,1,0.004),divider_radius,charcoal)

    for edge in [0.0,1.0]:
        var prong_angle: float=angle+(PI/2.0 if edge>0.5 else 0.0)
        var radial := Vector3(sin(prong_angle),0,cos(prong_angle))
        var tangent := Vector3(cos(prong_angle),0,-sin(prong_angle))
        for v in [0.0,0.5,1.0]:
            var p: Vector3=_lantern_point(o,angle,float(edge),float(v),0.003)
            var q: Vector3=o+radial*(p-o).dot(radial)+tangent*(0.092 if edge<0.5 else -0.092)+Vector3.UP*p.y
            rod(p,q,0.006,charcoal)

func _ceiling() -> void:
    box(Vector3(7.7,0.16,SOUTH-NORTH),Vector3(CX,7.00,(SOUTH+NORTH)*0.5),ceiling_wash)
    for side in [-1.0,1.0]:box(Vector3(5.15,0.16,105),Vector3(CX+side*6.425,7.00,MID),ceiling_wash)
    for side in [-1.0,1.0]:box(Vector3(0.12,0.25,105),Vector3(CX+side*8.75,6.82,MID),trim)
    for i in range(18):
        var z: float=-1.2+float(i)*PITCH
        var diamond: Array[Vector3]=[Vector3(CX-2.55,6.89,z),Vector3(CX,6.89,z+2.34),Vector3(CX+2.55,6.89,z),Vector3(CX,6.89,z-2.34)]
        for inset in [0.0,0.22]:
            for j in range(4):
                var a: Vector3=diamond[j];var b: Vector3=diamond[(j+1)%4]
                a=a.lerp(Vector3(CX,6.89,z),float(inset));b=b.lerp(Vector3(CX,6.89,z),float(inset))
                var d: Vector3=b-a
                box(Vector3(0.060,0.050,d.length()),(a+b)*0.5,trim,Basis(Vector3.UP,atan2(d.x,d.z)))

func _solid_box(size: Vector3,p: Vector3,mat: Material,basis: Basis=Basis.IDENTITY) -> void:
    box(size,p,mat,basis)
    var body := StaticBody3D.new();body.name="TransferStructure";body.position=p;body.basis=basis
    var shape := BoxShape3D.new();shape.size=size
    var collider := CollisionShape3D.new();collider.shape=shape;body.add_child(collider);add_child(body)

func _transfer() -> void:
    var half := 1.55
    var rise := 3.15
    var run := 6.51
    # Two opposed flights. Only thin structural slabs and tread/riser shells exist below them.
    for direction in [-1.0,1.0]:
        var start: float=MID-direction*(2.10+run)
        for i in range(21):
            var z: float=start+direction*(float(i)+0.5)*0.31
            var y: float=FY+float(i+1)*0.15
            _solid_box(Vector3(3.10,0.055,0.307),Vector3(CX,y-0.0275,z),stair_stone)
            box(Vector3(3.10,0.097,0.018),Vector3(CX,y-0.1035,z-direction*0.145),wall_stone)
            box(Vector3(3.08,0.005,0.035),Vector3(CX,y+0.003,z-direction*0.124),yellow if i in [0,20] else charcoal)
        var slope: float=atan2(rise,run)
        var b: Basis=Basis(Vector3.UP,0.0 if direction>0 else PI)*Basis(Vector3.RIGHT,-slope)
        _solid_box(Vector3(3.1,0.14,sqrt(run*run+rise*rise)),Vector3(CX,FY+rise*0.5-0.045,start+direction*run*0.5),wall_stone,b)
        for side in [-1.0,1.0]:
            var x: float=CX+side*(half+0.09)
            # Sloping parapet panel, NOT a floor-to-landing wedge.
            var outline := PackedVector2Array([Vector2(0,-0.18),Vector2(run,rise-0.18),Vector2(run,rise+0.96),Vector2(0,0.96)])
            if direction>0:_side_panel(outline,x-0.09,x+0.09,start,wall_stone)
            else:
                var flipped := PackedVector2Array()
                for point in outline:flipped.append(Vector2(-point.x,point.y))
                _side_panel(flipped,x-0.09,x+0.09,start,wall_stone)
            var a := Vector3(x-side*0.11,FY+0.87,start-0.12*direction)
            var c := Vector3(x-side*0.11,DECK+0.87,start+direction*run)
            rod(a,c,0.025,metal)
            for j in range(7):
                var p: Vector3=a.lerp(c,(float(j)+0.5)/7.0)
                rod(p,p+Vector3(side*0.12,-0.12,0),0.010,metal)
            rod(a,a+Vector3(0,-0.20,-0.18*direction),0.025,metal)
            rod(c,c+Vector3(0,0,direction*0.8),0.025,metal)
        board("transfer.svg",Vector3(CX,5.62,start-direction*0.65),Vector2(2.72,0.48))
    # Open cross-passage: 2.72m clear height under the landing beam; no body spans the pedestrian opening.
    _solid_box(Vector3(11.15,0.22,4.20),Vector3(CX+3.825,DECK-0.11,MID),wall_stone)
    box(Vector3(11.15,0.018,4.20),Vector3(CX+3.825,DECK+0.009,MID),floor_red)
    for side in [-1.0,1.0]:
        for dz in [-1.9,1.9]:_solid_box(Vector3(0.28,DECK-FY-0.22,0.30),Vector3(CX+side*1.87,(FY+DECK-0.22)*0.5,MID+float(dz)),wall_stone)
        box(Vector3(11.15,0.20,0.22),Vector3(CX+3.825,DECK-0.32,MID+side*1.96),white)
    for x in [CX+3.6,CX+5.0,CX+6.4,CX+7.8]:box(Vector3(0.18,0.24,4.10),Vector3(float(x),DECK-0.34,MID),white)
    var glass := _material(Color(0.28,0.25,0.21,0.48),0.16,0.25);glass.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;glass.cull_mode=BaseMaterial3D.CULL_DISABLED
    box(Vector3(0.16,0.62,4.20),Vector3(CX-1.75,DECK+0.31,MID),wall_stone)
    box(Vector3(0.022,0.80,4.05),Vector3(CX-1.75,DECK+1.02,MID),glass)
    rod(Vector3(CX-1.75,DECK+1.44,MID-2.1),Vector3(CX-1.75,DECK+1.44,MID+2.1),0.024,metal)
    for side in [-1.0,1.0]:
        var z: float=MID+side*2.10
        # Leave the stair mouths open at both edges of the central landing.
        box(Vector3(7.85,0.62,0.16),Vector3(CX+5.475,DECK+0.31,z),wall_stone)
        for i in range(7):
            var x: float=CX+1.65+float(i)*1.10
            box(Vector3(1.065,0.80,0.022),Vector3(x+0.53,DECK+1.02,z),glass)
            rod(Vector3(x,DECK+0.62,z),Vector3(x,DECK+1.44,z),0.017,metal)
        rod(Vector3(CX+9.35,DECK+0.62,z),Vector3(CX+9.35,DECK+1.44,z),0.017,metal)
        rod(Vector3(CX+1.55,DECK+1.44,z),Vector3(CX+9.4,DECK+1.44,z),0.024,metal)
    # The photographed bridge crosses one track into a short upper transfer approach.
    _solid_box(Vector3(5.7,0.22,4.2),Vector3(CX+12.25,DECK-0.11,MID),wall_stone)
    for side in [-1.0,1.0]:box(Vector3(5.7,2.2,0.20),Vector3(CX+12.25,DECK+1.1,MID+side*2.1),wall_stone)
    box(Vector3(5.7,0.14,4.4),Vector3(CX+12.25,DECK+2.27,MID),white)
    for x in [CX+10.2,CX+12.8]:box(Vector3(0.90,0.025,0.18),Vector3(float(x),DECK+2.18,MID),glow)
    picture("transfer.svg",Vector2(2.4,0.424),Vector3(CX+14.9,DECK+1.55,MID),-PI/2.0)
    box(Vector3(0.06,2.15,4.0),Vector3(CX+15.15,DECK+1.075,MID),charcoal)
    for name in ["UnderBridgeLeft","UnderBridgeRight","TransferLanding","TransferToKupalovskaya"]:
        var marker := Marker3D.new();marker.name=name
        marker.position=Vector3(CX-3.8,FY,MID) if name=="UnderBridgeLeft" else Vector3(CX+3.8,FY,MID) if name=="UnderBridgeRight" else Vector3(CX,DECK,MID) if name=="TransferLanding" else Vector3(CX+15.0,DECK,MID)
        get_node("PassengerAnchors").add_child(marker)

func _escalator_height(s: float) -> float:
    if s<1.0:return 0.0
    if s<2.60:return 0.58*pow(s-1.0,2.0)/3.20
    if s<10.40:return 0.464+(s-2.60)*0.58
    if s<12.0:
        var t: float=s-10.40
        return 4.988+0.58*t-0.58*t*t/3.20
    return 5.452

func _escalators(start: float) -> void:
    var width := 7.12
    var rubber := _material(Color("#1d201d"),0.0,0.52)
    var stepmat := _material(Color("#555a54"),0.55,0.46)
    var casing := _material(Color("#9b9f99"),0.78,0.29)
    _exit_hall(1.0,start,width,FY+5.452,16.5)
    _escalator_infill(start,width)
    _landing(start+0.18,7.12,1.60)
    for lane in range(3):
        var x: float=CX+(float(lane)-1.0)*2.0
        for i in range(54):
            var s: float=-0.20+float(i)*0.25
            var y: float=_escalator_height(s)
            box(Vector3(1.39,0.055,0.246),Vector3(x,FY+y+0.028,start+s),stepmat)
            var h: float=maxf(0.005,y-_escalator_height(s-0.25))
            box(Vector3(1.39,h,0.018),Vector3(x,FY+y-h*0.5,start+s-0.123),stepmat)
            for groove in range(18):box(Vector3(0.005,0.005,0.242),Vector3(x-0.65+float(groove)*0.076,FY+y+0.058,start+s),black)
        for j in range(70):box(Vector3(0.007,0.017,0.075),Vector3(x-0.67+float(j)*0.0193,FY+0.065,start-0.35),metal)
    # Four SHARED balustrades, each with continuous curved transitions and a rounded return nose.
    for boundary in range(4):
        var x: float=CX-3.0+float(boundary)*2.0
        var outline := PackedVector2Array()
        var rail: Array[Vector3]=[]
        for i in range(76):
            var s: float=float(i)*0.18
            var h: float=_escalator_height(s)
            outline.append(Vector2(s,h+0.84));rail.append(Vector3(x,FY+h+0.86,start+s))
        for i in range(75,-1,-1):
            var s: float=float(i)*0.18
            outline.append(Vector2(s,_escalator_height(s)+0.10))
        # The top/bottom endpoints already belong to the straight outline; do not repeat polygon vertices.
        for j in range(1,16):
            var a: float=-PI/2.0-float(j)*PI/16.0
            outline.append(Vector2(0.37*cos(a),0.47+0.37*sin(a)))
        _side_panel(outline,x-0.26,x+0.26,start,casing)
        for i in range(rail.size()-1):
            rod(rail[i],rail[i+1],0.045,rubber)
            for off in [-0.263,0.263]:rod(rail[i]+Vector3(float(off),-0.055,0),rail[i+1]+Vector3(float(off),-0.055,0),0.018,metal)
        for j in range(24):
            var a0: float=PI/2.0+float(j)*PI/24.0;var a1: float=PI/2.0+float(j+1)*PI/24.0
            var a := Vector3(x,FY+0.47+0.39*sin(a0),start+0.39*cos(a0))
            var b := Vector3(x,FY+0.47+0.39*sin(a1),start+0.39*cos(a1))
            rod(a,b,0.045,rubber)
            for off in [-0.263,0.263]:rod(a+Vector3(float(off),-0.035,0),b+Vector3(float(off),-0.035,0),0.019,metal)
        box(Vector3(0.28,0.69,0.27),Vector3(x,FY+0.345,start-0.63),metal)
        box(Vector3(0.29,0.055,0.28),Vector3(x,FY+0.03,start-0.63),black)
        picture("escalator_warning.svg",Vector2(0.20,0.23),Vector3(x,FY+0.30,start-0.771),PI)
        if boundary in [1,2]:
            box(Vector3(0.075,1.63,0.075),Vector3(x,FY+0.815,start-0.63),black)
            var status := _material(Color("#c02151") if boundary==1 else Color("#30a56c"),0,0.50)
            status.emission_enabled=true;status.emission=status.albedo_color;status.emission_energy_multiplier=0.45
            box(Vector3(0.071,0.12,0.008),Vector3(x,FY+1.52,start-0.673),status)
    box(Vector3(width,0.16,3.1),Vector3(CX,FY+5.452-0.08,start+14.5),floor_stone)
    board("exit_escalators.svg",Vector3(CX,4.66,start-0.88),Vector2(5.90,0.959))

func _escalator_infill(start: float,width: float) -> void:
    # Stone cheeks close the narrow slots between the outer balustrades and hall walls.
    var outline := PackedVector2Array([Vector2(-0.42,-0.08)])
    for i in range(77):
        var distance: float=-0.42+float(i)*14.0/76.0
        outline.append(Vector2(distance,_escalator_height(maxf(distance,0.0))+0.14))
    outline.append(Vector2(13.58,-0.08))
    for side in [-1.0,1.0]:
        var a: float=CX+float(side)*3.25
        var b: float=CX+float(side)*(width*0.5+0.04)
        _side_panel(outline,minf(a,b),maxf(a,b),start,wall_stone)
    var bed := PackedVector2Array([Vector2(-0.42,-0.12)])
    for i in range(77):
        var distance: float=-0.42+float(i)*14.0/76.0
        bed.append(Vector2(distance,_escalator_height(maxf(distance,0.0))-0.025))
    bed.append(Vector2(13.58,-0.12))
    _side_panel(bed,CX-3.26,CX+3.26,start,granite)

func _side_panel(points: PackedVector2Array,x0: float,x1: float,z0: float,mat: Material) -> void:
    var caps := Geometry2D.triangulate_polygon(points)
    for side in [0,1]:
        var x: float=x0 if side==0 else x1
        for j in range(0,caps.size(),3):
            var a: Vector2=points[caps[j]];var b: Vector2=points[caps[j+1]];var c: Vector2=points[caps[j+2]]
            triangle(Vector3(x,FY+a.y,z0+a.x),Vector3(x,FY+b.y,z0+b.x),Vector3(x,FY+c.y,z0+c.x),mat,Vector3(-1 if side==0 else 1,0,0))
    for j in range(points.size()):
        var a: Vector2=points[j];var b: Vector2=points[(j+1)%points.size()]
        quad(Vector3(x0,FY+a.y,z0+a.x),Vector3(x1,FY+a.y,z0+a.x),Vector3(x1,FY+b.y,z0+b.x),Vector3(x0,FY+b.y,z0+b.x),mat)

func _landing(z: float,width: float,length: float) -> void:
    var plate := _photo("checker_plate.svg",Vector2(0.32,0.32),0.47)
    box(Vector3(width,0.018,length),Vector3(CX,FY+0.025,z),plate)
    for i in range(12):box(Vector3(width*0.82,0.004,0.012),Vector3(CX,FY+0.036,z-length*0.42+float(i)*length*0.075),black)

func _exit_hall(direction: float,start: float,width: float,top: float,length: float) -> void:
    var roof_y: float=maxf(8.0,top+2.80)
    for side in [-1.0,1.0]:
        var x: float=CX+side*(width*0.5+0.16)
        box(Vector3(0.30,roof_y-FY,length),Vector3(x,(roof_y+FY)*0.5,start+direction*(length*0.5-0.30)),wall_stone)
        box(Vector3(0.31,0.09,length),Vector3(x,FY+0.045,start+direction*(length*0.5-0.30)),black)
        for y in [FY+0.6,FY+1.2,FY+1.8,FY+2.4,FY+3.0,FY+3.6,FY+4.2]:
            box(Vector3(0.003,0.003,length),Vector3(x-side*0.152,float(y),start+direction*(length*0.5-0.30)),trim)
        picture("no_smoking.svg",Vector2(0.22,0.22),Vector3(x,FY+1.9,start-direction*0.47),0.0 if direction<0 else PI)
        picture("sos_info.svg",Vector2(0.25,0.39),Vector3(x,FY+0.94,start-direction*0.472),0.0 if direction<0 else PI)
        _camera_box(Vector3(x-side*0.16,4.92,start-direction*0.5),0.0 if direction<0 else PI)
    box(Vector3(width+0.62,0.20,length),Vector3(CX,roof_y+0.10,start+direction*(length*0.5-0.3)),white)
    var front: float=start-direction*0.36
    box(Vector3(width+0.62,0.20,0.42),Vector3(CX,4.84,front),wall_stone)
    box(Vector3(width+0.62,roof_y-6.82,0.28),Vector3(CX,(roof_y+6.82)*0.5,front+0.16),white)
    for i in range(7):
        var z: float=start+direction*float(i)*2.3
        box(Vector3(width+0.2,0.14,0.28),Vector3(CX,roof_y-0.05,z),white)
        box(Vector3(5.6,0.045,0.045),Vector3(CX,roof_y-0.16,z),glow)
    for side in [-1.0,1.0]:
        rod(Vector3(CX+side*3.35,5.22,start),Vector3(CX+side*3.35,5.22,start+direction*5.0),0.025,glow)
    box(Vector3(width+0.60,2.2,0.20),Vector3(CX,top+1.10,start+direction*(length-0.45)),wall_stone)

func _end_art(start: float,key: String) -> void:
    # Continuous end returns behind the preserved reliefs, with clear tunnel mouths below.
    for side in [-1.0,1.0]:
        box(Vector3(5.05,2.12,0.28),Vector3(CX+side*6.40,5.86,start-0.20),wall_stone)
        box(Vector3(0.60,4.80,0.28),Vector3(CX+side*4.17,2.40,start-0.20),wall_stone)
        box(Vector3(0.68,4.80,0.28),Vector3(CX+side*8.60,2.40,start-0.20),wall_stone)
    # Actual sculptural panels reconstructed on shallow relief meshes, above the escalators and tunnel mouths.
    for part in ["left","center","right"]:
        var x: float=CX-6.5 if part=="left" else CX+6.5 if part=="right" else CX
        var w: float=4.0 if part!="center" else 9.0
        _relief("frieze_"+key+"_"+part,Vector3(x,5.82,start-0.38),Vector2(w,2.0),PI)
    _camera_box(Vector3(CX,4.78,start-0.60),PI)
    for side in [-1.0,1.0]:
        var x: float=CX+side*3.30
        for row in range(4):
            var z: float=start-1.4+float(row)*0.43
            rod(Vector3(x,FY,z),Vector3(x,FY+0.85,z),0.024,metal)
            if row<3:rod(Vector3(x,FY+0.85,z),Vector3(x,FY+0.85,z+0.43),0.024,metal)

func _relief(file: String,p: Vector3,size: Vector2,yaw: float) -> void:
    var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ART+file+".json"))
    var nx: int=int(data["width"]);var ny: int=int(data["height"]);var heights: Array=data["values"]
    var mat := StandardMaterial3D.new();mat.albedo_texture=load(ART+file+".jpg");mat.roughness=0.72;mat.cull_mode=BaseMaterial3D.CULL_DISABLED
    var st := SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
    for y in range(ny-1):
        for x in range(nx-1):
            for offset in [Vector2i(0,0),Vector2i(1,0),Vector2i(1,1),Vector2i(0,0),Vector2i(1,1),Vector2i(0,1)]:
                var ix: int=x+offset.x;var iy: int=y+offset.y
                var u: float=float(ix)/float(nx-1);var v: float=float(iy)/float(ny-1)
                var h: float=float(heights[iy*nx+ix])/255.0
                var dx: float=(float(heights[iy*nx+mini(ix+1,nx-1)])-float(heights[iy*nx+maxi(ix-1,0)]))/255.0*0.045*float(nx)/size.x
                var dy: float=(float(heights[mini(iy+1,ny-1)*nx+ix])-float(heights[maxi(iy-1,0)*nx+ix]))/255.0*0.045*float(ny)/size.y
                st.set_normal(Vector3(-dx,dy,1).normalized());st.set_uv(Vector2(u,v));st.add_vertex(Vector3((u-0.5)*size.x,(0.5-v)*size.y,0.085+h*0.045))
    st.generate_tangents()
    var mesh := st.commit();mesh.surface_set_material(0,mat)
    var node := MeshInstance3D.new();node.name="PhotographicBasRelief";node.mesh=mesh;node.position=p;node.rotation.y=yaw;node.transform=construction_transform*node.transform;add_child(node)
    box(Vector3(size.x, size.y,0.12),p,wall_stone,Basis(Vector3.UP,yaw))

func _maintenance_barrier(start: float) -> void:
    var red := _material(Color("#a72838"),0,0.66)
    box(Vector3(1.45,0.92,0.04),Vector3(CX-2.0,FY+0.46,start-0.90),yellow)
    for side in [-1.0,1.0]:box(Vector3(0.04,0.92,0.85),Vector3(CX-2.0+side*0.72,FY+0.46,start-0.48),yellow)
    for i in range(10):rod(Vector3(CX-2.70+float(i)*0.155,FY+0.92,start-0.90),Vector3(CX-2.70+float(i)*0.155,FY+1.16,start-0.90),0.010,yellow)
    # The red metro M on the photographed temporary enclosure.
    box(Vector3(0.11,0.27,0.009),Vector3(CX-2.23,FY+0.48,start-0.926),red)
    box(Vector3(0.11,0.27,0.009),Vector3(CX-1.77,FY+0.48,start-0.926),red)
    box(Vector3(0.11,0.24,0.009),Vector3(CX-2.11,FY+0.48,start-0.926),red,Basis(Vector3.BACK,-0.55))
    box(Vector3(0.11,0.24,0.009),Vector3(CX-1.89,FY+0.48,start-0.926),red,Basis(Vector3.BACK,0.55))

func _signs() -> void:
    # Clear opening = 4.80 - .84 = 3.96 m; framed signs = 3.48 m.
    for bay in [2,6,10,14]:
        var z: float=-1.2+(float(bay)+0.5)*PITCH
        for side in [-1.0,1.0]:
            var p := Vector3(CX+side*COL_X,5.02,z)
            var size := Vector2(3.40,0.5383)
            box(Vector3(0.075,0.60,3.48),p,metal)
            for face in [-1.0,1.0]:picture("platform_track1.svg" if side>0 else "platform_track2.svg",size,p+Vector3(face*0.043,0,0),face*PI/2.0)
            for dz in [-0.95,0.95]:rod(p+Vector3(0,0.27,float(dz)),Vector3(p.x,6.86,z+float(dz)),0.022,metal)

func _bench(p: Vector3) -> void:
    var base := _material(Color("#5c4730"),0.05,0.67)
    box(Vector3(0.60,0.34,2.99),p+Vector3(0,0.21,0),base)
    for seat in range(5):
        var z: float=-1.20+float(seat)*0.60
        # Contoured saddle with rounded front and rear noses; five distinct photographed modules.
        for strip in range(15):
            var x: float=-0.35+(float(strip)+0.5)*0.70/15.0
            var y: float=0.475+0.028*pow(abs(x)/0.35,3.0)
            box(Vector3(0.047,0.066,0.575),p+Vector3(x,y-0.033,z),oak)
        for side in [-1.0,1.0]:
            for j in range(8):
                var a0: float=-PI/2.0+float(j)*PI/8.0;var a1: float=-PI/2.0+float(j+1)*PI/8.0
                var x0: float=side*(0.327+0.028*cos(a0));var x1: float=side*(0.327+0.028*cos(a1))
                quad(p+Vector3(x0,0.473+0.028*sin(a0),z-0.2875),p+Vector3(x0,0.473+0.028*sin(a0),z+0.2875),p+Vector3(x1,0.473+0.028*sin(a1),z+0.2875),p+Vector3(x1,0.473+0.028*sin(a1),z-0.2875),oak)
        for edge in [-1.0,1.0]:
            var joint_z: float=z+edge*0.293
            box(Vector3(0.715,0.014,0.018),p+Vector3(0,0.504,joint_z),black)
            for side in [-1.0,1.0]:box(Vector3(0.018,0.11,0.018),p+Vector3(side*0.35,0.455,joint_z),black)

func _monitor(z: float) -> void:
    var p := Vector3(CX,5.45,z)
    box(Vector3(1.55,0.94,0.13),p,charcoal)
    for side in [-1.0,1.0]:
        # Existing project advertising artwork, displayed on both sides of each monitor.
        picture("monitor_ad.jpg",Vector2(1.45,0.84),p+Vector3(0,0,side*0.074),0.0 if side>0.0 else PI)
    for dx in [-0.46,0.46]:
        rod(p+Vector3(float(dx),0.49,0),Vector3(CX+float(dx),6.88,z),0.014,metal)

func _floor_fittings() -> void:
    for z in [11.0,MID,65.0]:
        cylinder(0.20,0.014,Vector3(CX+0.3,FY+0.023,float(z)),metal)
        for i in range(6):box(Vector3(0.012,0.016,0.25),Vector3(CX+0.22+float(i)*0.032,FY+0.030,float(z)),black)
        var hatch_z: float=MID if absf(float(z)-MID)<0.1 else float(z)+3.4
        box(Vector3(0.35,0.018,0.38),Vector3(CX-0.25,FY+0.025,hatch_z),trim)
        for i in range(8):box(Vector3(0.20,0.022,0.018),Vector3(CX-0.25,FY+0.030,hatch_z-0.14+float(i)*0.036),black)

func _track_details() -> void:
    var detail := preload("res://modules/stations/oktyabrskaya/track_detail.gd").new()
    detail.name="UruchyeStyleTrackwork"
    detail.start_z=track_min_z;detail.finish_z=track_max_z;add_child(detail)
    for name in ["Track1","Track2"]:
        var x: float=0.992 if name=="Track1" else -11.732
        for direction in [-1.0,1.0]:
            var end: float=NORTH if direction<0.0 else SOUTH
            box(Vector3(3.78,0.20,8.0),Vector3(x,4.90,end+direction*3.9),wall_stone)
            for side in [-1.0,1.0]:
                box(Vector3(0.14,4.60,8.0),Vector3(x+side*1.94,2.12,end+direction*3.9),wall_stone)
                for h in [0.70,1.1,1.5,1.9,2.35,2.65]:rod(Vector3(x+side*1.84,float(h),end),Vector3(x+side*1.84,float(h),end+direction*7.8),0.015,black)
            box(Vector3(3.85,4.65,0.10),Vector3(x,2.13,end+direction*8.0),black)

func _portal_equipment() -> void:
    var infra := get_node("StationInfrastructure")
    infra.set("_amber",Color(1.0,0.13,0.055))
    var displays: Array=infra.get("_displays")
    for display in displays:
        for i in range(70,76):display.set_instance_color(i,Color(1.0,0.13,0.055))
    for node in infra.get_children():
        if node is Node3D and "Portal" in str(node.name):
            var at_north: bool="Portal1" in str(node.name)
            var direction: float=-1.0 if at_north else 1.0
            var end: float=NORTH if at_north else SOUTH
            node.position.y=4.56
            node.position.z=end-direction*0.55
            # Hide tail-end panels locally while preserving the shared clock update arrays.
            node.visible=str(node.name) in ["Track1Portal1Clock","Track2Portal2Clock"]
    for direction in [-1.0,1.0]:
        var end: float=NORTH if direction<0.0 else SOUTH
        for side in [-1.0,1.0]:
            var tx: float=CX+side*6.362
            var yaw: float=0.0 if direction<0.0 else PI
            box(Vector3(3.90,0.48,0.25),Vector3(tx,4.68,end),wall_stone)
            var p := Vector3(tx-side*1.42,4.68,end-direction*0.16)
            box(Vector3(0.72,0.46,0.08),p,black)
            picture("platform_cctv.jpg",Vector2(0.66,0.371),p+Vector3(0,0,-direction*0.048),yaw)
            _camera_box(Vector3(CX+side*3.95,4.56,end-direction*0.35),yaw)
            # Keep driver mirrors only at the departure end of each track.
            if direction!=-side:continue
            var root := Node3D.new();root.name="WhiteDriverMirror";root.position=Vector3(CX+side*4.58,FY+1.42,end-direction*2.6);root.rotation.y=yaw-side*0.12;add_child(root)
            var mirror := MeshInstance3D.new();mirror.set_script(preload("res://modules/stations/oktyabrskaya/driver_mirrors.gd"));mirror.name="ReflectingSurface";mirror.position.z=0.016
            var q := QuadMesh.new();q.size=Vector2(0.60,1.56);mirror.mesh=q;mirror.set_meta("mirror_size",q.size);root.add_child(mirror)
            var pts: Array[Vector3]=[]
            for corner in range(4):
                var c := Vector2(0.235*(1.0 if corner in [0,3] else -1.0),0.70*(1.0 if corner in [0,1] else -1.0))
                for j in range(9):
                    var a: float=float(corner)*PI/2.0+float(j)*PI/16.0;pts.append(Vector3(c.x+0.11*cos(a),c.y+0.11*sin(a),0))
            for i in range(pts.size()):_local_rod(root,pts[i],pts[(i+1)%pts.size()],0.032,white)
            _local_rod(root,Vector3(0,-1.42,0),Vector3(0,-0.80,0),0.075,_material(Color("#285476"),0.3,0.42))
            for dx in [-0.42,0.42]:_local_rod(root,Vector3(float(dx),-1.42,0),Vector3(float(dx),-0.52,0.10),0.023,metal)
            _local_rod(root,Vector3(-0.42,-0.52,0.10),Vector3(0.42,-0.52,0.10),0.023,metal)

func _local_rod(parent: Node3D,a: Vector3,b: Vector3,r: float,mat: Material) -> void:
    var mesh := CylinderMesh.new();mesh.top_radius=r;mesh.bottom_radius=r;mesh.height=a.distance_to(b);mesh.radial_segments=10;mesh.material=mat
    var n := MeshInstance3D.new();n.mesh=mesh;n.position=(a+b)*0.5
    var d := (b-a).normalized();var axis := Vector3.UP.cross(d)
    if axis.length_squared()>0.00001:n.basis=Basis(axis.normalized(),Vector3.UP.angle_to(d))
    parent.add_child(n)

func _camera_box(p: Vector3,yaw: float) -> void:
    var b := Basis(Vector3.UP,yaw)
    box(Vector3(0.17,0.13,0.30),p,white,b)
    box(Vector3(0.19,0.02,0.34),p+Vector3(0,0.09,0),white,b)
    sphere(Vector3(0.075,0.075,0.015),p+b*Vector3(0,0,0.16),black)
    rod(p+Vector3(0,0.1,0),p+Vector3(0,0.3,0),0.014,metal)

