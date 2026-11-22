extends RefCounted
## Read-only geometry access contract for a future exporter; no file writes.
## Specialised adapters can extend this class and override accepts/inspect.
const Metadata = preload("res://tools/portability/portable_module.gd")

func adapter_id() -> String:
    return "godot_scene_handles_v1"

func accepts(descriptor: Dictionary) -> bool:
    # Acceptance means inspection support, NOT verified Roblox exportability.
    return descriptor.get("format_version",0)==Metadata.FORMAT_VERSION and descriptor.get("module",{}).has("scene")

func inspect(root: Node3D) -> Dictionary:
    # The caller explicitly supplies ONE already-initialised module. No creation,
    # _ready invocation, waits, tree edits, resource baking or export takes place.
    var result := {"geometry":[],"points":[],"animation_handles":[],"skeleton_handles":[],"limitations":[]}
    if not is_instance_valid(root) or not root.is_inside_tree() or not root.is_node_ready():
        _issue(result,"root_not_ready",".","Supply an already initialised module; procedural generators have not been run by this adapter.")
        return result
    if absf(root.global_basis.determinant())<0.0000001:
        _issue(result,"singular_root_transform",".","Cannot express geometry relative to a zero-scale root.")
        return result
    var inverse := root.global_transform.affine_inverse()
    var pending: Array[Node]=[root]
    while not pending.is_empty():
        var node: Node=pending.pop_back()
        var path: String=str(root.get_path_to(node))
        if node is Viewport:
            _issue(result,"viewport_scene",path,"Offscreen viewport content is not physical module geometry; a rendering adapter must decide how to represent it.")
            continue
        for child in node.get_children():pending.append(child)
        if node is MeshInstance3D:
            var instance := node as MeshInstance3D
            if instance.mesh==null:continue
            var blend_shapes: int=0
            if instance.mesh is ArrayMesh:blend_shapes=(instance.mesh as ArrayMesh).get_blend_shape_count()
            result.geometry.append({"kind":"mesh","node_path":path,"mesh":instance.mesh,
                "transform":inverse*instance.global_transform,
                "visible":instance.is_visible_in_tree(),
                "surface_materials":_mesh_materials(instance,result,path),
                "skin":instance.skin,"skeleton_path":str(instance.skeleton),
                "blend_shape_count":blend_shapes})
            if instance.skin!=null or blend_shapes>0:
                _issue(result,"skinning_or_blend_shapes",path,"Resources are retained; skin, skeleton, blend shapes and animation conversion need a dedicated adapter.")
        elif node is MultiMeshInstance3D:
            var instance := node as MultiMeshInstance3D
            var multi: MultiMesh=instance.multimesh
            if multi==null or multi.mesh==null:continue
            var materials: Array=[]
            for surface in range(multi.mesh.get_surface_count()):
                var material: Material=instance.material_override if instance.material_override!=null else multi.mesh.surface_get_material(surface)
                materials.append(material)
                _material_limitations(material,result,path)
            result.geometry.append({"kind":"multimesh","node_path":path,"mesh":multi.mesh,
                "multimesh":multi,"transform":inverse*instance.global_transform,
                "visible":instance.is_visible_in_tree(),"surface_materials":materials,
                "instance_count":multi.instance_count,"visible_instance_count":multi.visible_instance_count,
                "use_colors":multi.use_colors,"use_custom_data":multi.use_custom_data})
            # Keep the original resource: transforms, colours and custom data are
            # accessible without expanding thousands of instances into new nodes.
            if multi.transform_format!=MultiMesh.TRANSFORM_3D:
                _issue(result,"multimesh_2d",path,"A 2D instance basis needs a specialised conversion.")
        elif node is GeometryInstance3D:
            _issue(result,"non_mesh_geometry",path,"No generic mesh handle for "+node.get_class()+"; dedicated geometry conversion is required.")
        if node is GeometryInstance3D:
            var geometry := node as GeometryInstance3D
            if geometry.material_overlay!=null:
                _issue(result,"material_overlay",path,"Overlay is retained on the source node; layering needs a target-specific treatment.")
        if node is Marker3D:
            result.points.append(Metadata.point(path,"custom",inverse*(node as Node3D).global_transform,path))
        if node is Skeleton3D:
            result.skeleton_handles.append({"node_path":path,"skeleton":node,"transform":inverse*(node as Node3D).global_transform})
        if node is AnimationPlayer:
            result.animation_handles.append({"node_path":path,"player":node,"animation_names":(node as AnimationPlayer).get_animation_list()})
    return result

func _mesh_materials(instance: MeshInstance3D,result: Dictionary,path: String) -> Array:
    var materials: Array=[]
    for surface in range(instance.mesh.get_surface_count()):
        var material: Material=instance.get_active_material(surface)
        materials.append(material)
        _material_limitations(material,result,path)
    return materials

func _material_limitations(material: Material,result: Dictionary,path: String) -> void:
    if material is ShaderMaterial:
        _issue(result,"godot_shader",path,"Shader source and parameters are available on the material; shader translation/baking is not implemented.")
    elif material is BaseMaterial3D:
        var native := material as BaseMaterial3D
        for property in native.get_property_list():
            if str(property.name).ends_with("_texture") and native.get(str(property.name)) is ViewportTexture:
                _issue(result,"viewport_texture",path,"Live mirror/CCTV imagery requires a Roblox rendering equivalent; it is not a static texture.")

func _issue(result: Dictionary,code: String,path: String,detail: String) -> void:
    var issue := {"code":code,"node_path":path,"detail":detail}
    if not result.limitations.has(issue):result.limitations.append(issue)
