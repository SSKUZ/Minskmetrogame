extends "res://modules/stations/petrovshchina/station_builder.gd"
## Пятроўшчына. All 56 owner photographs, 22 November 2026.
## Independent native meshes/MultiMeshes; V106 Station Base rail/platform datum.
const ART := "res://modules/stations/petrovshchina/art/"
var layout: Dictionary
var floor_stone: StandardMaterial3D
var dark_stone: StandardMaterial3D
var wall_stone: StandardMaterial3D
var stair_stone: StandardMaterial3D
var seat_wood: StandardMaterial3D
var cream: StandardMaterial3D
var blue: StandardMaterial3D
var roof_blue: StandardMaterial3D
var yellow: StandardMaterial3D
var seam: StandardMaterial3D
var truss_paint: StandardMaterial3D
var star_white: StandardMaterial3D
var star_blue: StandardMaterial3D
var name_mesh: ArrayMesh

func _ready() -> void:
    super._ready()
    begin_station()
    layout=JSON.parse_string(FileAccess.get_file_as_string(ART+"station_layout.json"))
    for child in get_children():
        if child is OmniLight3D:child.queue_free()
    floor_stone=_photo("floor_granite.jpg",Vector2(0.60,0.60),0.37)
    dark_stone=_photo("black_granite.jpg",Vector2(0.60,0.40),0.31)
    wall_stone=_photo("wall_stone.jpg",Vector2(0.9,0.6),0.29)
    stair_stone=_photo("stair_granite.jpg",Vector2(1.4,0.30),0.59)
    seat_wood=_photo("seat_wood.jpg",Vector2(0.54,0.88),0.33)
    cream=_material(Color("#e0ded1"),0.12,0.32)
    blue=_material(Color("#657e91"),0.35,0.32)
    roof_blue=_material(Color("#10192c"),0.32,0.44)
    yellow=_material(Color("#e5bd36"),0.0,0.62)
    seam=_material(Color("#9eaaa9"),0.65,0.36)
    truss_paint=_material(Color("#c3c2ae"),0.37,0.40)
    star_white=_emissive(Color("#c5e2ff"),3.0)
    star_blue=_emissive(Color("#183bff"),4.5)
    _platform();_walls();_vault();_trusses()
    for z in layout.bench_z_m:_bench(float(z))
    for stair in layout.stairs:_stairs(stair)
    _railway();_equipment();_anchors()
    flush()

func _photo(file: String,scale_m: Vector2,roughness: float) -> StandardMaterial3D:
    var m=StandardMaterial3D.new();m.albedo_texture=load(ART+file);m.roughness=roughness
    m.uv1_triplanar=true;m.uv1_world_triplanar=true;m.uv1_triplanar_sharpness=8.0
    m.uv1_scale=Vector3(1.0/scale_m.x,1.0/scale_m.y,1.0/scale_m.x)
    m.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
    return m

func _emissive(colour: Color,energy: float) -> StandardMaterial3D:
    var m=_material(colour,0.0,0.45);m.emission_enabled=true
    m.emission=colour;m.emission_energy_multiplier=energy
    return m

func _solid(size: Vector3,p: Vector3,mat: Material) -> void:
    box(size,p,mat)
    var body=StaticBody3D.new();body.name="ArchitectureCollision";body.position=p
    var shape=BoxShape3D.new();shape.size=size
    var collision=CollisionShape3D.new();collision.shape=shape;body.add_child(collision);add_child(body)

func _platform() -> void:
    _solid(Vector3(10,0.20,105),Vector3(CX,FY-0.10,MID),floor_stone)
    # A separate slab grid preserves joints without a repeating painted pattern.
    for row in range(175):
        for col in range(16):
            box(Vector3(0.597,0.008,0.597),Vector3(CX-4.8+(float(col)+0.5)*0.6,FY+0.008,ZA+(float(row)+0.5)*0.6),floor_stone)
    for side in [-1.0,1.0]:
        box(Vector3(0.27,0.014,105),Vector3(CX+side*4.865,FY+0.016,MID),floor_stone)
        box(Vector3(0.13,0.012,105),Vector3(CX+side*4.66,FY+0.025,MID),yellow)
        box(Vector3(0.25,0.012,105),Vector3(CX+side*4.44,FY+0.025,MID),dark_stone)
        for dx in [-0.09,-0.055,-0.02,0.02,0.055,0.09]:
            box(Vector3(0.006,0.004,105),Vector3(CX+side*4.44+float(dx),FY+0.034,MID),black)
    # The axial strip opens around each broad bench into a rectangular dark border.
    var previous=ZA
    for value in layout.bench_z_m:
        var z=float(value)
        box(Vector3(0.18,0.012,z-0.93-previous),Vector3(CX,FY+0.024,(previous+z-0.93)*0.5),dark_stone)
        for side in [-1.0,1.0]:
            box(Vector3(4.90,0.012,0.18),Vector3(CX,FY+0.024,z+side*0.93),dark_stone)
            box(Vector3(0.18,0.012,1.86),Vector3(CX+side*2.36,FY+0.024,z),dark_stone)
        previous=z+0.93
    box(Vector3(0.18,0.012,ZB-previous),Vector3(CX,FY+0.024,(previous+ZB)*0.5),dark_stone)

func _walls() -> void:
    for side in [-1.0,1.0]:
        var x=CX+side*8.56
        _solid(Vector3(0.25,5.75,105),Vector3(x,2.875,MID),roof_blue)
        for i in range(126):
            var z=ZA+(float(i)+0.5)*105.0/126.0
            box(Vector3(0.10,1.80,0.829),Vector3(x-side*0.16,0.95,z),dark_stone)
            box(Vector3(0.12,1.60,0.825),Vector3(x-side*0.17,2.65,z),cream)
            box(Vector3(0.12,0.58,0.825),Vector3(x-side*0.17,3.74,z),blue)
            box(Vector3(0.025,2.18,0.014),Vector3(x-side*0.24,2.94,z-0.4167),seam)
        for h in [0.55,1.15]:box(Vector3(0.012,0.004,105),Vector3(x-side*0.215,float(h),MID),black)
        box(Vector3(0.022,0.026,105),Vector3(x-side*0.25,4.05,MID),seam)
        # Thin service conduits above the cladding, as seen in 165939.
        for h in [4.21,4.28]:rod(Vector3(x-side*0.24,float(h),ZA),Vector3(x-side*0.24,float(h),ZB),0.014,black)
        for z in layout.name_z_m:_nameplate(Vector3(x-side*0.27,2.64,float(z)),-side*PI/2.0)
        for z in layout.route_z_m:picture("wall_route.png",Vector2(4.45,1.27),Vector3(x-side*0.28,2.63,float(z)),-side*PI/2.0)

func _vault_y(x: float) -> float:
    return float(layout.vault_apex_y_m)-(float(layout.vault_apex_y_m)-float(layout.vault_edge_y_m))*pow(x/float(layout.vault_half_width_m),2.0)

func _vault() -> void:
    # Shallow continuous dark-blue barrel; triangulation remains accessible for glTF.
    for i in range(48):
        var x0=-8.6+float(i)*17.2/48.0;var x1=-8.6+float(i+1)*17.2/48.0
        quad(Vector3(CX+x0,_vault_y(x0),ZA),Vector3(CX+x1,_vault_y(x1),ZA),Vector3(CX+x1,_vault_y(x1),ZB),Vector3(CX+x0,_vault_y(x0),ZB),roof_blue,Vector3.DOWN)
    for z_index in range(76):
        var z=ZA+float(z_index)*1.4
        for j in range(24):
            var x0=-8.6+float(j)*17.2/24.0;var x1=-8.6+float(j+1)*17.2/24.0
            rod(Vector3(CX+x0,_vault_y(x0)-0.006,z),Vector3(CX+x1,_vault_y(x1)-0.006,z),0.003,black)
    for x_index in range(13):
        var x=-8.4+float(x_index)*1.4
        rod(Vector3(CX+x,_vault_y(x)-0.008,ZA),Vector3(CX+x,_vault_y(x)-0.008,ZB),0.003,black)
    var random=RandomNumberGenerator.new();random.seed=int(layout.star_seed)
    for i in range(int(layout.star_count)):
        var x=random.randf_range(-7.9,7.9);var z=random.randf_range(ZA+0.35,ZB-0.35)
        var p=Vector3(CX+x,_vault_y(x)-0.035,z)
        var cobalt=random.randf()<0.36;var r=random.randf_range(0.009,0.019)
        sphere(Vector3(r*2,0.013,r*2),p,star_blue if cobalt else star_white)
        cylinder(r*1.8,0.006,p+Vector3(0,0.01,0),metal)
    # Ribbed blue fan-shaped end returns; ivory soffit below them.
    for end in [ZA+2.6,ZB-2.6]:
        for i in range(48):
            var x0=-8.6+float(i)*17.2/48.0;var x1=-8.6+float(i+1)*17.2/48.0
            quad(Vector3(CX+x0,5.48,float(end)),Vector3(CX+x1,5.48,float(end)),Vector3(CX+x1,_vault_y(x1),float(end)),Vector3(CX+x0,_vault_y(x0),float(end)),blue)
        for i in range(23):
            var y=5.51+float(i)*0.075
            var half=8.6*sqrt(maxf(0.0,(7.25-y)/1.45))
            box(Vector3(half*2,0.022,0.045),Vector3(CX,y,float(end)-0.025),roof_blue)
        var z=float(end)+(-1.9 if float(end)<MID else 1.9)
        box(Vector3(17.2,0.15,3.8),Vector3(CX,5.43,z),cream)
        for j in range(64):box(Vector3(17.15,0.007,0.007),Vector3(CX,5.348,z-1.88+float(j)*0.06),seam)
        for offset in [-1.1,0.0,1.1]:_strip(Vector3(CX-7.6,5.30,z+float(offset)),Vector3(CX+7.6,5.30,z+float(offset)),0.07)

func _strip(a: Vector3,b: Vector3,width: float) -> void:
    var length=a.distance_to(b);var direction=(b-a).normalized()
    var basis=Basis(Vector3.UP,atan2(direction.x,direction.z))
    var count=maxi(1,int(ceilf(length/1.50)));var pitch=length/float(count)
    for i in range(count):
        var p=a+direction*(float(i)+0.5)*pitch
        box(Vector3(width+0.055,0.082,pitch-0.018),p+Vector3(0,0.025,0),truss_paint,basis)
        box(Vector3(width,0.035,maxf(0.02,pitch-0.13)),p,glow,basis)
        for dz in [-0.5,0.5]:box(Vector3(width+0.07,0.10,0.035),p+direction*(float(dz)*(pitch-0.15)),truss_paint,basis)

func _lamp(p: Vector3,energy: float,radius: float) -> void:
    var light=OmniLight3D.new();light.name="TrussFluorescentFill";light.position=p
    light.light_color=Color(1.0,0.975,0.90);light.light_energy=energy;light.omni_range=radius
    light.omni_attenuation=1.15;light.shadow_enabled=false;add_child(light)

func _trusses() -> void:
    var z0=ZA+3.0;var z1=ZB-3.0;var pitch=float(layout.truss_bay_length_m)
    var count=int(ceilf((z1-z0)/pitch));pitch=(z1-z0)/float(count)
    for offset in layout.truss_centres_relative_x_m:
        var x=CX+float(offset);var y0=float(layout.truss_bottom_y_m);var y1=float(layout.truss_top_y_m)
        for dx in [-0.60,0.60]:
            for h in [y0,y1]:rod(Vector3(x+float(dx),float(h),z0),Vector3(x+float(dx),float(h),z1),0.023,truss_paint)
            _strip(Vector3(x+float(dx)*0.73,y0-0.12,z0),Vector3(x+float(dx)*0.73,y0-0.12,z1),0.16)
        for i in range(count+1):
            var z=z0+float(i)*pitch
            for h in [y0,y1]:rod(Vector3(x-0.60,float(h),z),Vector3(x+0.60,float(h),z),0.019,truss_paint)
            for dx in [-0.60,0.60]:
                rod(Vector3(x+float(dx),y0,z),Vector3(x+float(dx),y1,z),0.018,truss_paint)
                sphere(Vector3(0.092,0.092,0.092),Vector3(x+float(dx),y0,z),truss_paint)
                if i<count:
                    rod(Vector3(x+float(dx),y0,z),Vector3(x+float(dx),y1,z+pitch),0.016,truss_paint)
                    rod(Vector3(x+float(dx),y1,z),Vector3(x+float(dx),y0,z+pitch),0.016,truss_paint)
            if i<count:
                rod(Vector3(x-0.60,y1,z),Vector3(x+0.60,y1,z+pitch),0.014,truss_paint)
                rod(Vector3(x+0.60,y0,z),Vector3(x-0.60,y0,z+pitch),0.014,truss_paint)
            if i%4==0:
                for dx in [-0.60,0.60]:rod(Vector3(x+float(dx),y1,z),Vector3(x+float(dx),_vault_y(float(offset)+float(dx)),z),0.013,metal)
        # Ribbed blue fascia below the outer chord carries real bilingual exit boards.
        var outer=x+signf(float(offset))*0.67
        box(Vector3(0.15,0.43,z1-z0),Vector3(outer,5.19,(z0+z1)*0.5),blue)
        for h in [5.01,5.10,5.19,5.28,5.37]:box(Vector3(0.17,0.009,z1-z0),Vector3(outer,float(h),(z0+z1)*0.5),roof_blue)
        _strip(Vector3(outer,4.94,z0),Vector3(outer,4.94,z1),0.085)
        for z in [5.0,26.0,47.0,68.0,84.0]:
            picture("side_exit.jpg",Vector2(4.6,0.635),Vector3(outer-signf(float(offset))*0.09,5.20,float(z)),-signf(float(offset))*PI/2.0)
        for i in range(10):_lamp(Vector3(x-signf(float(offset))*0.4,4.95,z0+4.0+float(i)*10.0),1.35,10.0)

func _bench(z: float) -> void:
    var width=float(layout.bench_seats)*0.54
    var profile_points=PackedVector2Array([Vector2(CX-width/2.0,FY+0.05),Vector2(CX+width/2.0,FY+0.05),Vector2(CX+width/2.0,FY+0.13),Vector2(CX+width/2.0-0.07,FY+0.21),Vector2(CX+width/2.0-0.07,FY+0.43),Vector2(CX-width/2.0+0.07,FY+0.43),Vector2(CX-width/2.0+0.07,FY+0.21),Vector2(CX-width/2.0,FY+0.13)])
    extrusion(profile_points,z-0.35,z+0.35,metal)
    _solid(Vector3(width-0.14,0.40,0.70),Vector3(CX,FY+0.23,z),metal)
    for i in range(int(layout.bench_seats)):
        var x=CX-width*0.5+(float(i)+0.5)*0.54
        for j in range(18):
            var a=-PI/2.0+float(j)*PI/18.0;var b=-PI/2.0+float(j+1)*PI/18.0
            var z0=z+0.46*sin(a);var z1=z+0.46*sin(b)
            var y0=FY+0.45+0.065*cos(a);var y1=FY+0.45+0.065*cos(b)
            quad(Vector3(x-0.263,y0,z0),Vector3(x+0.263,y0,z0),Vector3(x+0.263,y1,z1),Vector3(x-0.263,y1,z1),seat_wood,Vector3.UP)
            for side in [-1.0,1.0]:
                var xx=x+side*0.263
                quad(Vector3(xx,y0,z0),Vector3(xx,y1,z1),Vector3(xx,y1-0.055,z1),Vector3(xx,y0-0.055,z0),seat_wood,Vector3(side,0,0))
        box(Vector3(0.526,0.04,0.90),Vector3(x,FY+0.425,z),seat_wood)
        box(Vector3(0.018,0.035,0.90),Vector3(x+0.27,FY+0.47,z),metal)
        for side in [-1.0,1.0]:_point("Seat_%s_%s_%s" % [str(z),str(i),str(side)],Vector3(x,FY+0.51,z+side*0.19),"seat",0.0 if side>0 else PI)
    for side in [-1.0,1.0]:
        cylinder(0.16,0.018,Vector3(CX,FY+0.025,z+side*0.69),metal)
        rod(Vector3(CX-0.05,FY+0.04,z+side*0.69),Vector3(CX+0.05,FY+0.04,z+side*0.69),0.008,black)

func _stairs(data: Dictionary) -> void:
    var direction=float(data.direction);var start=float(data.start_z_m);var width=float(layout.stair_width_m)
    var run=float(layout.stair_run_m);var rise=float(layout.stair_rise_m);var landing=float(layout.stair_landing_m)
    var upper=FY+float(layout.stairs_per_end)*rise
    for i in range(int(layout.stairs_per_end)):
        var h=float(i+1)*rise;var z=start+direction*(float(i)*run+(landing if i>=15 else 0.0))
        _solid(Vector3(width,h,run+0.006),Vector3(CX,FY+h*0.5,z),stair_stone)
        box(Vector3(width,0.014,0.045),Vector3(CX,FY+h+0.012,z-direction*0.13),yellow if i in [0,14,15,29] else metal)
        for dz in [-0.10,-0.065,-0.03]:box(Vector3(width-0.25,0.003,0.006),Vector3(CX,FY+h+0.004,z+direction*float(dz)),dark_stone)
    var mid=start+direction*(14.5*run+landing*0.5)
    _solid(Vector3(width,0.20,landing),Vector3(CX,FY+15.0*rise-0.1,mid),stair_stone)
    var finish=start+direction*(29.5*run+landing)
    _solid(Vector3(width,0.20,4.0),Vector3(CX,upper-0.1,finish+direction*2.0),floor_stone)
    for side in [-1.0,1.0]:
        var x=CX+side*(width*0.5+0.16)
        _solid(Vector3(0.32,7.3,14.5),Vector3(x,FY+3.65,start+direction*6.3),wall_stone)
        for j in range(24):box(Vector3(0.014,7.1,0.007),Vector3(x-side*0.17,FY+3.55,start-direction*0.8+direction*float(j)*0.6),seam)
        for j in range(11):box(Vector3(0.014,0.005,14.4),Vector3(x-side*0.17,FY+float(j)*0.6,start+direction*6.3),seam)
        # Dark triangular stair skirting follows the actual flights and level landing.
        var points=[Vector2(start-direction*0.25,FY),Vector2(start-direction*0.25,FY+0.22),Vector2(start+direction*14.5*run,FY+15.0*rise+0.22),Vector2(start+direction*(14.5*run+landing),FY+15.0*rise+0.22),Vector2(finish,upper+0.22),Vector2(finish+direction*4.0,upper+0.22),Vector2(finish+direction*4.0,FY)]
        for i in range(1,points.size()-1):triangle(Vector3(x-side*0.18,points[0].y,points[0].x),Vector3(x-side*0.18,points[i].y,points[i].x),Vector3(x-side*0.18,points[i+1].y,points[i+1].x),dark_stone,Vector3(-side,0,0))
        for h in [0.70,1.0]:
            var xx=x-side*0.27
            var a=Vector3(xx,FY+float(h),start-direction*0.25)
            var b=Vector3(xx,FY+15.0*rise+float(h),start+direction*14.5*run)
            var c=Vector3(xx,b.y,start+direction*(14.5*run+landing))
            var d=Vector3(xx,upper+float(h),finish)
            rod(a,b,0.025,metal);rod(b,c,0.025,metal);rod(c,d,0.025,metal)
            rod(d,d+Vector3(0,0,direction*3.4),0.025,metal)
            for p in [a,b,c,d]:rod(p,p+Vector3(side*0.10,-0.08,0),0.012,metal)
        # Stainless end-of-platform safety gate beside each portal.
        var gate_x=CX+side*4.15;var gate_z=start+direction*2.25
        for dx in [-0.62,0.62]:rod(Vector3(gate_x+float(dx),FY,gate_z),Vector3(gate_x+float(dx),FY+1.0,gate_z),0.028,metal)
        for h in [0.08,0.94]:rod(Vector3(gate_x-0.62,FY+float(h),gate_z),Vector3(gate_x+0.62,FY+float(h),gate_z),0.025,metal)
        for j in range(7):rod(Vector3(gate_x-0.5+float(j)/6.0,FY+0.1,gate_z),Vector3(gate_x-0.5+float(j)/6.0,FY+0.92,gate_z),0.011,metal)
        var sign_z=start-direction*0.2
        picture("no_smoking.svg",Vector2(0.22,0.22),Vector3(x-side*0.18,FY+2.45,sign_z),-side*PI/2.0)
        picture("free_wifi.svg",Vector2(0.29,0.16),Vector3(x-side*0.18,FY+1.7,sign_z),-side*PI/2.0)
    # Vestibule ceiling rises above the stairs; no slab crosses the upper flight.
    box(Vector3(width,0.18,12),Vector3(CX,upper+2.65,start+direction*7.0),cream)
    for i in range(4):
        var z=start+direction*(3.0+float(i)*2.5)
        _strip(Vector3(CX-3.05,upper+2.51,z),Vector3(CX+3.05,upper+2.51,z),0.08)
        _lamp(Vector3(CX,upper+2.25,z),1.1,7.0)
    var sign_z=start-direction*0.8
    board(str(data.exit_art),Vector3(CX,4.63,sign_z),Vector2(5.2,0.64))
    board("exit.svg",Vector3(CX,5.10,sign_z),Vector2(0.90,0.23))
    # Visible side lift doorway in the approach recess, not a central platform shaft.
    var lift_x=CX+3.91;var lift_z=start+direction*1.6
    box(Vector3(1.08,2.55,0.18),Vector3(lift_x,FY+1.275,lift_z),seam)
    for side in [-1.0,1.0]:box(Vector3(0.49,2.16,0.035),Vector3(lift_x+side*0.25,FY+1.11,lift_z-direction*0.12),metal)
    board("lift.svg",Vector3(lift_x,FY+2.72,lift_z-direction*0.16),Vector2(0.98,0.36))
    _point("StairApproach"+str(int(direction)),Vector3(CX,FY,start-direction*0.8),"waypoint")
    _point("UpperLanding"+str(int(direction)),Vector3(CX,upper,finish+direction),"waypoint")
    _point("LiftApproach"+str(int(direction)),Vector3(lift_x,FY,lift_z-direction*0.8),"waypoint")

func _nameplate(p: Vector3,yaw: float) -> void:
    if name_mesh==null:
        var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ART+"name_relief.json"))
        var nx=int(data.width);var ny=int(data.height);var values: Array=data["values"]
        var size=Vector2(3.65,0.523);var depth=float(data.depth_m)
        var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
        for y in range(ny-1):
            for x in range(nx-1):
                for d in [Vector2i(0,0),Vector2i(1,0),Vector2i(1,1),Vector2i(0,0),Vector2i(1,1),Vector2i(0,1)]:
                    var ix=x+d.x;var iy=y+d.y;var u=float(ix)/float(nx-1);var v=float(iy)/float(ny-1)
                    var dx=(float(values[iy*nx+mini(ix+1,nx-1)])-float(values[iy*nx+maxi(ix-1,0)]))*depth*float(nx)/size.x
                    var dy=(float(values[mini(iy+1,ny-1)*nx+ix])-float(values[maxi(iy-1,0)*nx+ix]))*depth*float(ny)/size.y
                    st.set_normal(Vector3(-dx,dy,1).normalized());st.set_uv(Vector2(u,v))
                    st.add_vertex(Vector3((u-0.5)*size.x,(0.5-v)*size.y,float(values[iy*nx+ix])*depth))
        st.generate_tangents();st.index();name_mesh=st.commit()
        var mat=StandardMaterial3D.new();mat.albedo_texture=load(ART+"nameplate.png")
        mat.metallic=0.55;mat.roughness=0.38;mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
        mat.cull_mode=BaseMaterial3D.CULL_DISABLED;name_mesh.surface_set_material(0,mat)
    var node=MeshInstance3D.new();node.name="RaisedПЯТРОЎШЧЫНА";node.mesh=name_mesh
    node.position=p;node.rotation.y=yaw;add_child(node)

func _railway() -> void:
    var detail=preload("res://modules/stations/petrovshchina/track_detail.gd").new()
    detail.name="StationBaseDetailedTracks";detail.start_z=track_min_z;detail.finish_z=track_max_z;add_child(detail)
    for direction in [-1.0,1.0]:
        var end=ZA if direction<0.0 else ZB
        for tx in [0.992,-11.732]:
            var centre=float(tx)
            for j in range(24):
                var a=float(j)*PI/24.0;var b=float(j+1)*PI/24.0
                var x0=centre+1.94*cos(a);var x1=centre+1.94*cos(b)
                var y0=2.65+2.10*sin(a);var y1=2.65+2.10*sin(b)
                quad(Vector3(x0,y0,end),Vector3(x1,y1,end),Vector3(x1,y1,end+direction*10),Vector3(x0,y0,end+direction*10),wall_stone)
            for side in [-1.0,1.0]:
                box(Vector3(0.21,3.0,10.0),Vector3(centre+side*1.95,1.22,end+direction*5.0),wall_stone)
                for h in [0.8,1.1,1.45,1.85]:rod(Vector3(centre+side*1.80,float(h),end),Vector3(centre+side*1.80,float(h),end+direction*10.0),0.022,black)
                for j in range(13):box(Vector3(0.02,1.2,0.05),Vector3(centre+side*1.82,1.4,end+direction*(float(j)+0.5)*0.75),metal)
            for j in range(14):
                var z=end+direction*(float(j)+0.5)*0.7
                rod(Vector3(centre-1.91,2.64,z),Vector3(centre-1.91,0.25,z),0.025,black)
                rod(Vector3(centre+1.91,2.64,z),Vector3(centre+1.91,0.25,z),0.025,black)
            box(Vector3(3.7,4.5,0.15),Vector3(centre,2.20,end+direction*9.9),black)

func _equipment() -> void:
    for direction in [-1.0,1.0]:
        var z=(ZA+1.0) if direction<0.0 else (ZB-1.0)
        for side in [-1.0,1.0]:
            var p=Vector3(CX+side*3.05,5.15,z)
            box(Vector3(0.20,0.15,0.33),p,cream)
            sphere(Vector3(0.09,0.07,0.03),p+Vector3(0,-0.015,-direction*0.18),black)
            box(Vector3(0.27,0.33,0.20),p+Vector3(side*0.18,-0.32,0),metal)
        var cabinet=Vector3(CX-3.79,FY+0.65,z)
        box(Vector3(0.68,1.3,0.22),cabinet,_material(Color("#a61f24"),0.25,0.36))
        rod(cabinet+Vector3(0.22,-0.08,-direction*0.13),cabinet+Vector3(0.22,0.10,-direction*0.13),0.012,metal)
    var infrastructure=get_node("StationInfrastructure")
    for child in infrastructure.get_children():
        if child is Node3D and "Portal" in str(child.name):child.position.y=4.74

func _point(label: String,p: Vector3,role: String,yaw: float=0.0) -> void:
    var node=Marker3D.new();node.name=label;node.position=p;node.rotation.y=yaw
    node.set_meta("portable_role",role);get_node("PassengerAnchors").add_child(node)

func _anchors() -> void:
    for side in [-1.0,1.0]:
        var tx=0.992 if side>0 else -11.732
        _point("V106StopTrack"+str(1 if side>0 else 2),Vector3(tx,0,STOP_Z),"stop")
        for z in [0.0,12.0,24.0,36.0,48.0,60.0,72.0,84.0]:
            _point("Waiting_%s_%s" % [str(side),str(z)],Vector3(CX+side*3.9,FY,float(z)),"waiting")
