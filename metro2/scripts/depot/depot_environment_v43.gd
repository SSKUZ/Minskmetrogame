extends Node3D
## Visual-only outskirts of Minsk. World metres; railway and route remain untouched.
## Shared ordinary meshes/materials, spatially batched for mobile and later export.
const Route = preload("res://scripts/depot/route_profile.gd")
const CELL := 80.0
var _rng := RandomNumberGenerator.new()
var _meshes: Dictionary = {}
var _materials: Dictionary = {}
var _batches: Dictionary = {}
var _tree_sites: Array[Vector3] = []
var _homes: Array[Rect2] = []

static func ground_material() -> ShaderMaterial:
    var shader := Shader.new()
    shader.code = """shader_type spatial;
render_mode cull_disabled;
varying vec2 land;
void vertex(){land=(MODEL_MATRIX*vec4(VERTEX,1.0)).xz;}
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void fragment(){
 float broad=noise(land*0.055)*0.7+noise(land*0.17)*0.3;
 float fine=noise(land*4.0);
 vec3 turf=mix(vec3(0.25,0.31,0.18),vec3(0.42,0.45,0.28),broad);
 float dry=smoothstep(0.59,0.78,noise(land*0.10+vec2(27,11)));
 float shoulder=1.0-smoothstep(5.6,8.5,abs(land.x-0.992));
 float ramp=step(98.0,land.y)*(1.0-step(300.0,land.y));
 ALBEDO=mix(turf,vec3(0.35,0.31,0.23),max(dry*0.65,shoulder*ramp*0.7))*(0.92+fine*0.16);
 ROUGHNESS=0.98;
}
"""
    var material := ShaderMaterial.new()
    material.shader=shader
    return material

func _ready() -> void:
    _rng.seed=71771443
    _make_resources()
    _housing()
    _woodland()
    _yard_planting()
    _portal_landscape()
    _service_details()
    _flush()

func _make_resources() -> void:
    var cube := BoxMesh.new()
    cube.size=Vector3.ONE
    _meshes["box"]=cube
    var trunk := CylinderMesh.new()
    trunk.top_radius=0.38; trunk.bottom_radius=0.50
    trunk.height=1.0; trunk.radial_segments=7
    _meshes["trunk"]=trunk
    var cone := CylinderMesh.new()
    cone.top_radius=0.0; cone.bottom_radius=1.0
    cone.height=1.0; cone.radial_segments=9
    _meshes["cone"]=cone
    _meshes["leaf"]=_leaf_mesh(9,5)
    _meshes["distant_leaf"]=_leaf_mesh(7,3)
    for key in ["foliage","bark","wall","glass","metal","concrete"]:
        var material := StandardMaterial3D.new()
        material.vertex_color_use_as_albedo=true
        material.roughness=0.94
        if key == "glass": material.roughness=0.43
        if key == "metal":
            material.metallic=0.45
            material.roughness=0.62
        _materials[key]=material

func _leaf_mesh(sides: int,rings: int) -> ArrayMesh:
    # Uneven solid crowns rather than transparent leaf cards or smooth spheres.
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    for ring in range(rings):
        for side in range(sides):
            var vertices: Array[Vector3]=[]
            for pair in [Vector2i(ring,side),Vector2i(ring+1,side),Vector2i(ring+1,side+1),Vector2i(ring,side+1)]:
                var latitude := PI*float(pair.x)/float(rings)
                var longitude := TAU*float(pair.y%sides)/float(sides)
                var uneven := 1.0+0.10*sin(longitude*3.0+float(pair.x)*1.7)+0.045*cos(longitude*5.0)
                vertices.append(Vector3(sin(latitude)*cos(longitude)*uneven,cos(latitude),sin(latitude)*sin(longitude)*uneven))
            for index in [0,1,2,0,2,3]:
                var v: Vector3=vertices[index]
                st.set_normal(v.normalized())
                st.set_uv(Vector2(atan2(v.z,v.x)/TAU+0.5,acos(clampf(v.y,-1.0,1.0))/PI))
                st.add_vertex(v)
    return st.commit()

func _emit(kind: String,material: String,pos: Vector3,size: Vector3,color: Color,yaw: float = 0.0) -> void:
    var cell := Vector2i(int(floor(pos.x/CELL)),int(floor(pos.z/CELL)))
    var key := "%s:%s:%d:%d" % [kind,material,cell.x,cell.y]
    if not _batches.has(key):
        _batches[key]={"kind":kind,"material":material,"origin":Vector3(float(cell.x)*CELL,0,float(cell.y)*CELL),"poses":[],"colors":[]}
    var batch: Dictionary=_batches[key]
    batch.poses.append(Transform3D(Basis(Vector3.UP,yaw)*Basis.from_scale(size),pos-batch.origin))
    batch.colors.append(color)

func _clear_site(x: float,z: float,radius: float) -> bool:
    var dx := absf(x-Route.CENTER_X)
    if z < 108.0 and dx < 12.5+radius: return false
    if z >= 108.0 and z < 300.0 and dx < 12.0+radius: return false
    # Keep the complete working yard intact, except its explicitly planted lawns.
    if z >= 292.0-radius and z <= 608.0+radius and dx < 106.0+radius: return false
    for footprint in _homes:
        if footprint.grow(radius+5.0).has_point(Vector2(x,z)): return false
    for point in _tree_sites:
        if Vector2(point.x-x,point.z-z).length_squared() < pow(radius+point.y,2.0): return false
    return true

func _tree(x: float,z: float,species: int,height: float,distant: bool = false) -> void:
    var radius := height*(0.16 if species == 1 or species == 2 else 0.22)
    if not _clear_site(x,z,radius): return
    _tree_sites.append(Vector3(x,radius,z))
    var y := Route.ground(x,z)
    var yaw := _rng.randf_range(0,TAU)
    var shade := _rng.randf_range(0.88,1.10)
    var bark := Color("#686454")
    var green := Color("#52684b")
    if species == 0:
        bark=Color("#d4d4bf"); green=Color("#738455")
    elif species == 1:
        bark=Color("#806650"); green=Color("#4f6551")
    elif species == 2:
        bark=Color("#635a49"); green=Color("#3f594b")
    green=Color(green.r*shade,green.g*shade,green.b*shade)
    _emit("trunk","bark",Vector3(x,y+height*0.39,z),Vector3(height*0.035,height*0.78,height*0.035),bark)
    var crown := "distant_leaf" if distant else "leaf"
    if species == 2:
        var tiers := 2 if distant else 4
        for tier in range(tiers):
            var u := float(tier)/float(tiers)
            _emit("cone","foliage",Vector3(x,y+height*(0.38+u*0.44),z),Vector3(radius*(1.0-u*0.63),height*0.47,radius*(1.0-u*0.63)),green,yaw)
    elif species == 1:
        _emit(crown,"foliage",Vector3(x,y+height*0.78,z),Vector3(radius,height*0.16,radius*0.88),green,yaw)
        if not distant:
            _emit(crown,"foliage",Vector3(x+radius*0.45,y+height*0.68,z-radius*0.18),Vector3(radius*0.70,height*0.14,radius*0.66),green,yaw+0.8)
    else:
        _emit(crown,"foliage",Vector3(x,y+height*0.68,z),Vector3(radius,height*0.32,radius*0.86),green,yaw)
        if not distant:
            _emit(crown,"foliage",Vector3(x-radius*0.45,y+height*0.60,z+radius*0.20),Vector3(radius*0.66,height*0.23,radius*0.64),green,yaw+1.5)
        if species == 0 and not distant:
            for band in range(4):
                _emit("box","bark",Vector3(x,y+1.1+float(band)*0.60,z+height*0.0176),Vector3(height*0.022,0.07,0.012),Color("#54594f"),yaw)

func _shrub(x: float,z: float,size: float,lawn: bool = false) -> void:
    if not lawn and not _clear_site(x,z,size+0.15): return
    var ground := 5.755 if lawn else Route.ground(x,z)
    var color := Color("#626e48").lerp(Color("#405947"),_rng.randf())
    _emit("leaf","foliage",Vector3(x,ground+size*0.48,z),Vector3(size,size*0.58,size*0.79),color,_rng.randf_range(0,TAU))

func _woodland() -> void:
    # Irregular groves: gaps frame the skyline in the direction of travel (-Z).
    var groves := [Vector3(-143,0,480),Vector3(155,0,500),Vector3(-165,0,270),Vector3(160,0,240),Vector3(-83,0,157),Vector3(81,0,145),Vector3(-120,0,10),Vector3(132,0,-24),Vector3(-290,0,-190),Vector3(305,0,-175)]
    for grove in groves:
        for i in range(23):
            var angle := _rng.randf_range(0,TAU)
            var reach := sqrt(_rng.randf())
            var x: float=Route.CENTER_X+grove.x+cos(angle)*reach*43.0
            var z: float=grove.z+sin(angle)*reach*65.0
            _tree(x,z,_rng.randi_range(0,3),_rng.randf_range(7.0,14.0))
    for i in range(220):
        var side := -1.0 if i%2 == 0 else 1.0
        var x: float=Route.CENTER_X+side*_rng.randf_range(310,570)
        var z := _rng.randf_range(-370,690)
        _tree(x,z,_rng.randi_range(0,3),_rng.randf_range(10,17),true)
    for i in range(90):
        var side := -1.0 if i%2 == 0 else 1.0
        _shrub(Route.CENTER_X+side*_rng.randf_range(16,75),_rng.randf_range(105,288),_rng.randf_range(0.6,1.5))
    for i in range(75):
        var side := -1.0 if i%2 == 0 else 1.0
        _shrub(Route.CENTER_X+side*_rng.randf_range(108,144),_rng.randf_range(310,610),_rng.randf_range(0.7,1.8))

func _yard_planting() -> void:
    # Existing 7 m lawns at x +/-90; inside them no road/building footprint exists.
    for side in [-1.0,1.0]:
        for i in range(13):
            var x: float=Route.CENTER_X+side*(90.0+_rng.randf_range(-1.2,1.2))
            var z := 348.0+float(i)*17.0+_rng.randf_range(-4,4)
            # Place small decorative shrubs only; crowns stay inside the lawn.
            _shrub(x,z,_rng.randf_range(0.65,1.15),true)
            _shrub(x+side*0.9,z+2.4,_rng.randf_range(0.45,0.70),true)
    for i in range(45):
        var side := -1.0 if i%2 == 0 else 1.0
        _tree(Route.CENTER_X+side*_rng.randf_range(111,132),_rng.randf_range(315,610),i%4,_rng.randf_range(6,10))

func _housing() -> void:
    # Schematic Minsk panel housing, not a claimed reconstruction of actual addresses.
    # All footprints lie outside the depot boundary and the railway approach.
    var blocks := [
        Vector4(-170,-36,9,42),Vector4(175,-45,12,38),
        Vector4(-245,-132,16,24),Vector4(244,-155,19,25),
        Vector4(-112,-205,9,48),Vector4(126,-250,12,44),
        Vector4(-320,-296,12,46),Vector4(313,-330,16,27),
        Vector4(-210,-390,19,25),Vector4(218,-410,16,28),
        Vector4(-380,135,9,46),Vector4(370,92,12,40),
        Vector4(-440,-70,16,25),Vector4(435,-110,19,25)]
    for index in range(blocks.size()):
        var block: Vector4=blocks[index]
        var floors := int(block.z)
        var depth := 15.0 if floors <= 12 else 21.0
        var x := Route.CENTER_X+block.x
        var z := block.y
        _homes.append(Rect2(Vector2(x-block.w*0.5,z-depth*0.5),Vector2(block.w,depth)))
        _residential(Vector3(x,Route.ground(x,z)-0.5,z),Vector2(block.w,depth),floors,index)

func _residential(base: Vector3,footprint: Vector2,floors: int,index: int) -> void:
    var height := float(floors)*2.95+0.65
    var palette := [Color("#c4c5b6"),Color("#cfcdc0"),Color("#b4bcb7"),Color("#c9c3b1")]
    var wall: Color=palette[index%palette.size()]
    var glass := Color("#51626c")
    var frame := Color("#d2d1c4")
    var roof := Color("#777d79")
    _emit("box","wall",base+Vector3(0,height*0.5,0),Vector3(footprint.x,height,footprint.y),wall)
    _emit("box","concrete",base+Vector3(0,0.45,0),Vector3(footprint.x+0.2,0.9,footprint.y+0.2),Color("#828881"))
    _emit("box","metal",base+Vector3(0,height+0.16,0),Vector3(footprint.x+0.42,0.32,footprint.y+0.42),roof)
    _emit("box","wall",base+Vector3(footprint.x*0.22,height+1.15,0),Vector3(4.4,2.0,4.0),wall)
    var columns := maxi(4,int(footprint.x/3.1))
    for floor_index in range(floors):
        var y := 2.0+float(floor_index)*2.95
        for side in [-1.0,1.0]:
            var face_z: float=side*(footprint.y*0.5+0.035)
            _emit("box","concrete",base+Vector3(0,y+1.24,face_z),Vector3(footprint.x,0.055,0.04),wall.darkened(0.10))
            for col in range(columns):
                var x := -footprint.x*0.5+1.6+float(col)*(footprint.x-3.2)/float(columns-1)
                var window_color := glass.lerp(Color("#7c8990"),float((col+floor_index+index)%4)*0.07)
                _emit("box","glass",base+Vector3(x,y,face_z),Vector3(1.35,1.48,0.05),window_color)
                _emit("box","wall",base+Vector3(x,y,face_z+side*0.035),Vector3(0.055,1.48,0.035),frame)
                if col%4 == 1:
                    _emit("box","concrete",base+Vector3(x,y-0.73,face_z+side*0.44),Vector3(2.0,0.12,0.9),frame)
                    _emit("box","wall",base+Vector3(x,y-0.28,face_z+side*0.89),Vector3(2.0,0.80,0.08),wall.darkened(0.08))
        for side in [-1.0,1.0]:
            for col in [-1.0,1.0]:
                _emit("box","glass",base+Vector3(side*(footprint.x*0.5+0.035),y,col*footprint.y*0.23),Vector3(0.05,1.45,1.3),glass)
    for seam in range(1,columns):
        var x := -footprint.x*0.5+float(seam)*footprint.x/float(columns)
        for side in [-1.0,1.0]:
            _emit("box","concrete",base+Vector3(x,height*0.5,side*(footprint.y*0.5+0.045)),Vector3(0.035,height,0.025),wall.darkened(0.13))

func _portal_landscape() -> void:
    # Turf sits outside the existing concrete retaining walls and guardrails.
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    for side in [-1.0,1.0]:
        for z_index in range(26):
            var za := 98.0+float(z_index)*8.0
            var zb := minf(300.0,za+8.0)
            if za >= 300.0: break
            for band in range(4):
                var da := 5.33+float(band)*3.0
                var db := da+3.0
                var vertices: Array[Vector3]=[]
                for p in [Vector2(da,za),Vector2(da,zb),Vector2(db,zb),Vector2(db,za)]:
                    var x: float=Route.CENTER_X+side*p.x
                    var lift := 0.035+sin((p.x-5.33)/12.0*PI)*0.42*sin((p.y-98.0)/202.0*PI)
                    vertices.append(Vector3(x,Route.ground(x,p.y)+lift,p.y))
                _terrain_quad(st,vertices)
    # Close the landscape over the buried tunnel, behind its unchanged portal cap.
    for z_index in range(8):
        var za := 31.0+float(z_index)*8.0
        var zb := 95.30 if z_index == 7 else za+8.0
        var ya := 8.04+0.62*smoothstep(31.0,95.30,za)
        var yb := 8.04+0.62*smoothstep(31.0,95.30,zb)
        _terrain_quad(st,[Vector3(Route.CENTER_X-8,ya,za),Vector3(Route.CENTER_X-8,yb,zb),Vector3(Route.CENTER_X+8,yb,zb),Vector3(Route.CENTER_X+8,ya,za)])
        for side in [-1.0,1.0]:
            var inner_x: float=Route.CENTER_X+side*8.0
            var outer_x: float=Route.CENTER_X+side*16.0
            _terrain_quad(st,[Vector3(inner_x,ya,za),Vector3(inner_x,yb,zb),Vector3(outer_x,Route.ground(outer_x,zb)+0.025,zb),Vector3(outer_x,Route.ground(outer_x,za)+0.025,za)])
    var terrain := MeshInstance3D.new()
    terrain.name="PortalTurfBanks"
    terrain.mesh=st.commit()
    terrain.material_override=ground_material()
    terrain.layers=65
    terrain.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(terrain)
    for i in range(33):
        var side := -1.0 if i%2 == 0 else 1.0
        _shrub(Route.CENTER_X+side*_rng.randf_range(18,29),_rng.randf_range(102,287),_rng.randf_range(0.55,1.15))
    for i in range(18):
        var side := -1.0 if i%2 == 0 else 1.0
        _tree(Route.CENTER_X+side*_rng.randf_range(22,43),_rng.randf_range(42,110),i%4,_rng.randf_range(7,12))

func _terrain_quad(st: SurfaceTool,vertices: Array[Vector3]) -> void:
    # Up-facing winding is identical on both sides of the cut.
    if (vertices[1]-vertices[0]).cross(vertices[2]-vertices[0]).y < 0.0: vertices.reverse()
    var normal := (vertices[1]-vertices[0]).cross(vertices[2]-vertices[0]).normalized()
    for index in [0,1,2,0,2,3]:
        var v: Vector3=vertices[index]
        st.set_normal(normal)
        st.set_uv(Vector2(v.x,v.z)*0.1)
        st.add_vertex(v)

func _service_details() -> void:
    # A few utility cabinets on existing roadside margins; no additional lights.
    for z in [164.0,244.0]:
        var x := Route.CENTER_X-10.6
        var y := Route.ground(x,z)
        _emit("box","concrete",Vector3(x,y+0.08,z),Vector3(2.0,0.16,1.6),Color("#999b8e"))
        _emit("box","metal",Vector3(x,y+0.83,z),Vector3(0.90,1.35,0.50),Color("#78877f"))
        _emit("box","metal",Vector3(x,y+1.54,z),Vector3(1.0,0.07,0.59),Color("#59665e"))
        _emit("box","metal",Vector3(x,y+0.87,z+0.258),Vector3(0.025,1.13,0.015),Color("#3c4843"))
        _emit("box","metal",Vector3(x+0.26,y+0.86,z+0.28),Vector3(0.035,0.15,0.03),Color("#303a38"))

func _flush() -> void:
    for key in _batches:
        var batch: Dictionary=_batches[key]
        var mm := MultiMesh.new()
        mm.transform_format=MultiMesh.TRANSFORM_3D
        mm.use_colors=true
        mm.mesh=_meshes[batch.kind]
        mm.instance_count=batch.poses.size()
        for i in range(mm.instance_count):
            mm.set_instance_transform(i,batch.poses[i])
            mm.set_instance_color(i,batch.colors[i])
        var node := MultiMeshInstance3D.new()
        node.name="Environment_"+str(key).replace(":","_")
        node.multimesh=mm
        node.material_override=_materials[batch.material]
        node.position=batch.origin
        node.layers=65
        var distant: bool=absf(node.position.x-Route.CENTER_X) > 250.0 or node.position.z < -80.0
        node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if distant else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
        node.visibility_range_end=740.0 if distant else 480.0
        node.visibility_range_end_margin=35.0
        add_child(node)
    _batches.clear()
