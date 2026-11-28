extends Node3D
## Continuous carved radial surface, smooth recesses and solid bronze birds.
const ART := "res://modules/stations/malinovka/art/"
const Bird = preload("res://modules/stations/malinovka/bird_sculpture.gd")
static var relief_mesh: ArrayMesh
static var profile_data: Dictionary={}

func _ready() -> void:
    if profile_data.is_empty():profile_data=JSON.parse_string(FileAccess.get_file_as_string(ART+"column_carving.json"))
    if relief_mesh==null:relief_mesh=_build_surface()
    var sculpture=MeshInstance3D.new();sculpture.name="ContinuousCarvedTreeSurface";sculpture.mesh=relief_mesh;add_child(sculpture)
    for i in range(profile_data.bird_angles_deg.size()):
        var angle=deg_to_rad(float(profile_data.bird_angles_deg[i]))
        var bird=Bird.new();bird.name="BronzeBird%02d" % (i+1);bird.variant=i
        bird.position=Vector3(sin(angle)*0.64,float(profile_data.body_top_y_m)-1.1805-float(profile_data.body_bottom_above_platform_m)-float(profile_data.bird_height_below_cap_m[i]),cos(angle)*0.64)
        bird.rotation=Vector3(0,angle+0.30,0.12 if i%2 else -0.10);add_child(bird)

func _build_surface() -> ArrayMesh:
    var texture=load(ART+str(profile_data.height_field)) as Texture2D
    var image=texture.get_image()
    if image.is_compressed():image.decompress()
    var nx=image.get_width();var ny=image.get_height()
    var height=float(profile_data.body_top_y_m)-1.1805-float(profile_data.body_bottom_above_platform_m)
    var core=float(profile_data.core_radius_m);var depth=float(profile_data.max_radial_relief_m)
    var vertices=PackedVector3Array();var normals=PackedVector3Array()
    for y in range(ny):
        for x in range(nx):
            var angle=TAU*float(x)/float(nx);var radius=core+image.get_pixel(x,y).r*depth
            vertices.append(Vector3(sin(angle)*radius,height*float(y)/float(ny-1),cos(angle)*radius))
    for y in range(ny):
        for x in range(nx):
            var tangent=vertices[y*nx+(x+1)%nx]-vertices[y*nx+(x+nx-1)%nx]
            var vertical=vertices[mini(y+1,ny-1)*nx+x]-vertices[maxi(y-1,0)*nx+x]
            normals.append(tangent.cross(vertical).normalized())
    var rough_st=SurfaceTool.new();rough_st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var smooth_st=SurfaceTool.new();smooth_st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var rough=StandardMaterial3D.new();rough.albedo_texture=load(ART+"bark_stone.jpg")
    rough.roughness=0.79;rough.uv1_scale=Vector3(6,9,1)
    var smooth=StandardMaterial3D.new();smooth.albedo_color=Color("#dcd6c0");smooth.roughness=0.38
    for y in range(ny-1):
        for x in range(nx):
            var level=(image.get_pixel(x,y).r+image.get_pixel((x+1)%nx,y).r+image.get_pixel(x,y+1).r+image.get_pixel((x+1)%nx,y+1).r)*0.25
            var st: SurfaceTool=rough_st if level>0.10 else smooth_st
            for d in [Vector2i(0,0),Vector2i(0,1),Vector2i(1,1),Vector2i(0,0),Vector2i(1,1),Vector2i(1,0)]:
                var ix=(x+d.x)%nx;var iy=y+d.y;var at=iy*nx+ix
                st.set_normal(normals[at]);st.set_uv(Vector2(float(x+d.x)/float(nx),float(iy)/float(ny-1)))
                st.add_vertex(vertices[at])
    rough_st.index();var mesh=rough_st.commit();mesh.surface_set_material(0,rough)
    smooth_st.index();smooth_st.commit(mesh);mesh.surface_set_material(1,smooth)
    return mesh
