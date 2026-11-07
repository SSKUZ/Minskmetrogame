extends RefCounted
const SURFACE = preload("res://assets/depot/industrial_surface.gdshader")
var root: Node3D
var materials: Dictionary = {}
var batches: Dictionary = {}
var surfaces: Dictionary = {}
var cube: BoxMesh
var cylinder_mesh: CylinderMesh
var cone_mesh: CylinderMesh
var crown_mesh: SphereMesh

func _init(parent: Node3D) -> void:
    root = parent
    cube = BoxMesh.new()
    cube.size = Vector3.ONE
    cylinder_mesh = CylinderMesh.new()
    cylinder_mesh.top_radius = 1.0
    cylinder_mesh.bottom_radius = 1.0
    cylinder_mesh.height = 1.0
    cylinder_mesh.radial_segments = 12
    cone_mesh = CylinderMesh.new()
    cone_mesh.top_radius = 0.0
    cone_mesh.bottom_radius = 1.0
    cone_mesh.height = 1.0
    cone_mesh.radial_segments = 10
    crown_mesh = SphereMesh.new()
    crown_mesh.radius = 1.0
    crown_mesh.height = 2.0
    crown_mesh.radial_segments = 10
    crown_mesh.rings = 5

func mat(name: String,color: Color,rough: float = 0.88,metal: float = 0.0,pattern: float = 0.0,emission: float = 0.0) -> ShaderMaterial:
    if materials.has(name): return materials[name]
    var material := ShaderMaterial.new()
    material.resource_name = name
    material.shader = SURFACE
    material.set_shader_parameter("tint",color)
    material.set_shader_parameter("roughness_value",rough)
    material.set_shader_parameter("metal_value",metal)
    material.set_shader_parameter("pattern",pattern)
    material.set_shader_parameter("emission_value",emission)
    materials[name] = material
    return material

func instance(mesh: Mesh,material: Material,pose: Transform3D) -> void:
    var key := str(mesh.get_instance_id())+":"+str(material.get_instance_id())
    if not batches.has(key): batches[key] = {"mesh":mesh,"material":material,"transforms":[]}
    batches[key]["transforms"].append(pose)

## Scale the mesh's LOCAL axes before rotating it into world space.
func box(material: Material,position: Vector3,size: Vector3,basis: Basis = Basis.IDENTITY) -> void:
    instance(cube,material,Transform3D(basis*Basis.from_scale(size),position))

func beam(material: Material,a: Vector3,b: Vector3,width: float = 0.1,depth: float = 0.0) -> void:
    var delta := b-a
    if delta.length() < 0.001: return
    var basis := Basis(Quaternion(Vector3.UP,delta.normalized()))
    box(material,(a+b)*0.5,Vector3(width,delta.length(),width if depth <= 0.0 else depth),basis)

func cylinder(material: Material,position: Vector3,radius: float,length: float,basis: Basis = Basis.IDENTITY) -> void:
    instance(cylinder_mesh,material,Transform3D(basis*Basis.from_scale(Vector3(radius,length,radius)),position))

func cone(material: Material,position: Vector3,radius: float,height: float) -> void:
    instance(cone_mesh,material,Transform3D(Basis.IDENTITY.scaled(Vector3(radius,height,radius)),position))

func crown(material: Material,position: Vector3,size: Vector3) -> void:
    instance(crown_mesh,material,Transform3D(Basis.IDENTITY.scaled(size),position))

func quad(material: Material,a: Vector3,b: Vector3,c: Vector3,d: Vector3) -> void:
    if not surfaces.has(material):
        var tool := SurfaceTool.new()
        tool.begin(Mesh.PRIMITIVE_TRIANGLES)
        surfaces[material] = tool
    var st := surfaces[material] as SurfaceTool
    var normal := (b-a).cross(c-a).normalized()
    for vertex in [a,b,c,a,c,d]:
        st.set_normal(normal)
        st.add_vertex(vertex)

func label(text: String,position: Vector3,size: float = 0.016,rotation_y: float = 0.0,color: Color = Color(0.85,0.87,0.82)) -> void:
    var sign := Label3D.new()
    sign.text = text
    sign.position = position
    sign.rotation.y = rotation_y
    sign.font_size = 48
    sign.pixel_size = size
    sign.modulate = color
    sign.outline_size = 4
    sign.outline_modulate = Color(0.08,0.10,0.11)
    sign.render_priority = 1
    sign.layers = 64
    root.add_child(sign)

func flush() -> void:
    for entry in batches.values():
        var transforms: Array = entry["transforms"]
        var mm := MultiMesh.new()
        mm.transform_format = MultiMesh.TRANSFORM_3D
        mm.mesh = entry["mesh"]
        mm.instance_count = transforms.size()
        for i in range(transforms.size()): mm.set_instance_transform(i,transforms[i])
        var node := MultiMeshInstance3D.new()
        node.name = "Shared_"+str((entry["material"] as Material).resource_name)
        node.multimesh = mm
        node.material_override = entry["material"]
        node.layers = 65
        root.add_child(node)
    for material in surfaces:
        var node := MeshInstance3D.new()
        node.name = "Surface_"+str((material as Material).resource_name)
        node.mesh = (surfaces[material] as SurfaceTool).commit()
        node.material_override = material
        node.layers = 65
        root.add_child(node)
    batches.clear()
    surfaces.clear()
