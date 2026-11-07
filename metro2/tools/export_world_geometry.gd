extends SceneTree
## Headless Godot 4.x export of runtime-generated Node3D geometry into GLB.
## Usage: godot --headless --path metro2 --script res://tools/export_world_geometry.gd -- --scene res://scenes/stations/uruchye_station_module.tscn --out ../exports/uruchye.glb
const MAX_INSTANCES := 120000
var _warnings: Array[String] = []
var _meshes := 0
var _instances := 0

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var opts := _options(OS.get_cmdline_user_args())
    if not opts.has("scene") or not opts.has("out"):
        push_error("Required: --scene res://...tscn --out /path/file.glb")
        quit(2)
        return
    var source := str(opts["scene"])
    var output := str(opts["out"])
    if not source.begins_with("res://") or not output.to_lower().ends_with(".glb"):
        push_error("Scene must be res:// and output must end with .glb")
        quit(2)
        return
    var packed := load(source) as PackedScene
    if packed == null:
        push_error("Cannot load scene: " + source)
        quit(2)
        return
    var live := packed.instantiate()
    if not live is Node3D:
        push_error("Scene root must be Node3D")
        quit(2)
        return
    root.add_child(live)
    await process_frame
    await process_frame
    var baked := Node3D.new()
    baked.name = "ExportRoot"
    _collect(live as Node3D, baked, Transform3D.IDENTITY)
    if _meshes == 0:
        push_error("No mesh geometry found in " + source)
        quit(3)
        return
    var directory := output.get_base_dir()
    if not DirAccess.dir_exists_absolute(directory):
        var err := DirAccess.make_dir_recursive_absolute(directory)
        if err != OK:
            push_error("Cannot create export directory: " + directory)
            quit(4)
            return
    var doc := GLTFDocument.new()
    var state := GLTFState.new()
    var err := doc.append_from_scene(baked, state)
    if err == OK:
        err = doc.write_to_filesystem(state, output)
    if err != OK:
        push_error("GLB export failed: " + str(err))
        quit(5)
        return
    var summary := {
        "source_scene": source,
        "output": output,
        "mesh_nodes": _meshes,
        "expanded_multimesh_instances": _instances,
        "units": "metres",
        "axes": "Godot Y-up; verify Roblox Studio import axes and scale",
        "warnings": _warnings,
        "status": "GLB generated; Roblox Studio validation NOT performed"
    }
    var manifest := FileAccess.open(output + ".json", FileAccess.WRITE)
    if manifest != null:
        manifest.store_string(JSON.stringify(summary, "\t"))
        manifest.close()
    print("WORLD_GEOMETRY_EXPORT_OK " + JSON.stringify(summary))
    quit(0)

func _options(args: PackedStringArray) -> Dictionary:
    var opts := {}
    var i := 0
    while i < args.size():
        if (args[i] == "--scene" or args[i] == "--out") and i + 1 < args.size():
            opts[args[i].substr(2)] = args[i + 1]
            i += 2
        else:
            i += 1
    return opts

func _collect(node: Node3D, target: Node3D, transform: Transform3D) -> void:
    if _instances > MAX_INSTANCES:
        push_error("Instance limit exceeded; split module into smaller chunks")
        quit(6)
        return
    var current := transform * node.transform
    if node is MeshInstance3D:
        var src := node as MeshInstance3D
        if src.mesh != null and src.visible:
            _append_mesh(src.mesh, src.material_override, current, target, str(src.name))
    elif node is MultiMeshInstance3D:
        var src := node as MultiMeshInstance3D
        if src.multimesh != null and src.multimesh.mesh != null and src.visible:
            var multi := src.multimesh
            var count := multi.visible_instance_count
            if count < 0:
                count = multi.instance_count
            for i in range(count):
                if _instances >= MAX_INSTANCES:
                    push_error("Too many MultiMesh instances; split source module")
                    quit(6)
                    return
                var pose := multi.get_instance_transform(i)
                _append_mesh(multi.mesh, src.material_override, current * pose, target, str(src.name) + "_%06d" % i)
                _instances += 1
    for child in node.get_children():
        if child is Node3D:
            _collect(child as Node3D, target, current)

func _append_mesh(source_mesh: Mesh, override_material: Material, pose: Transform3D, parent: Node3D, label: String) -> void:
    var copy := source_mesh.duplicate() as Mesh
    if copy == null:
        _warnings.append("Cannot duplicate mesh " + label)
        return
    var instance := MeshInstance3D.new()
    instance.name = label.validate_node_name()
    instance.mesh = copy
    instance.transform = pose
    if override_material != null:
        instance.material_override = _portable_material(override_material, label)
    for surface in range(copy.get_surface_count()):
        var material := copy.surface_get_material(surface)
        if material is ShaderMaterial:
            copy.surface_set_material(surface, _portable_material(material, label))
    parent.add_child(instance)
    instance.owner = parent
    _meshes += 1

func _portable_material(material: Material, label: String) -> Material:
    if material is StandardMaterial3D or material is ORMMaterial3D:
        return material
    var fallback := StandardMaterial3D.new()
    fallback.albedo_color = Color(0.72, 0.72, 0.72)
    fallback.roughness = 0.65
    if material is ShaderMaterial:
        var tint = (material as ShaderMaterial).get_shader_parameter("tint")
        if tint is Color:
            fallback.albedo_color = tint
        _warnings.append("ShaderMaterial replaced with flat PBR approximation: " + label)
    else:
        _warnings.append("Unsupported material replaced: " + label)
    return fallback
