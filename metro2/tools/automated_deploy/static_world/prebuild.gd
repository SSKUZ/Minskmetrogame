extends SceneTree
## CI resource compiler. No main/game scene, train, passengers, input or simulation.
## Existing architecture generators run once in a disabled resource-only subtree.
const Budget = preload("res://modules/line/build_budget.gd")
const Connections = preload("res://modules/line/station_connection_adapter.gd")
var control: Dictionary
var _written: Dictionary={}
var _resources: Dictionary={}
var _locations: Dictionary={}
var _archives: Dictionary={}
var _visiting: Dictionary={}
var _serial := 0
var _folder := ""
var _unsupported := ""
var _local_resources: Dictionary={}
var _host: Node3D

func _initialize() -> void:
    call_deferred("_compile")

func _compile() -> void:
    control=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("METRO_STATIC_CONTROL")))
    _folder=str(control.destination)
    _host=Node3D.new()
    _host.name="StaticResourceCompiler"
    _host.process_mode=Node.PROCESS_MODE_DISABLED
    root.add_child(_host)
    if str(control.module)=="full_line":
        await _tunnels()
    else:
        await _station()
    _host.free()
    quit(0)

func _station() -> void:
    # The standalone source and the route instance use different rail extents.
    # Compile each actual configuration; do not substitute the viewer geometry.
    var closed_station: Node3D=await _source_station(false)
    if closed_station==null: return
    await _adapt(closed_station,closed_station)
    if not _unsupported.is_empty():
        _legacy_index()
        closed_station.free()
        return
    var closed: Array=await _fragments(closed_station)
    closed_station.free()
    _resources.clear()
    var open_station: Node3D=await _source_station(true)
    if open_station==null: return
    await Connections.open_connections(open_station)
    await _adapt(open_station,open_station)
    if not _unsupported.is_empty():
        _legacy_index()
        open_station.free()
        return
    var opened: Array=await _fragments(open_station)
    var index := {"schema":1,"module_id":control.module,"metres_per_unit":1.0,
        "source_scene":control.scene,"source_commit":control.source_commit,
        "closed_chunks":closed,"open_chunks":opened,
        "portability":{"geometry":"native Mesh/ArrayMesh/MultiMesh; original hierarchy and transforms", "route":"res://modules/line/route_layout.json", "limitations":["Godot shaders and live viewport textures require adaptation for glTF/Roblox"]}}
    _json(str(control.index),index)
    open_station.free()

func _legacy_index() -> void:
    _json(str(control.index),{"schema":1,"module_id":control.module,"legacy":true,
        "source_scene":control.scene,"reason":"Runtime attachment requires an explicit safe adapter: "+_unsupported})
    print("Preserving original station implementation: ",control.module," ",_unsupported)

func _source_station(line_open: bool) -> Node3D:
    var scene := load(str(control.scene)) as PackedScene
    if scene==null: _fail("Missing source station "+str(control.scene)); return null
    var station := scene.instantiate() as Node3D
    scene=null
    if line_open:
        var layout: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://modules/line/route_layout.json"))
        var datum: Dictionary=layout.station_datums[str(control.module)]
        station.set("track_min_z",float(datum.exit_local[2]))
        station.set("track_max_z",float(datum.entry_local[2]))
    var work=Budget.new(_host,10000)
    station.set_meta("metro_line_work",work)
    _host.add_child(station)
    while not work.pending.is_empty(): await process_frame
    work.release_sources()
    return station

func _adapt(node: Node, station: Node) -> void:
    var script := node.get_script() as Script
    var path: String=script.resource_path if script!=null else ""
    if path=="res://scripts/infrastructure/station_infrastructure.gd":
        # Keep geometry and exports, replace only the construction entry point.
        var values: Dictionary={}
        for property in script.get_script_property_list():
            if int(property.usage)&PROPERTY_USAGE_STORAGE: values[property.name]=node.get(property.name)
        node.set_script(load("res://tools/automated_deploy/static_world/station_clock_runtime.gd"))
        for key in values: node.set(key,values[key])
    elif path=="res://scripts/station/uruchye_architecture.gd":
        node.set_script(load("res://tools/automated_deploy/static_world/uruchye_ad_runtime.gd"))
    elif path.ends_with("/uruchye_platform_equipment.gd"):
        # Original small view-dependent mirror attachment; its private viewport
        # references cannot be serialized. Architecture is already prepared.
        for child in node.get_children():
            node.remove_child(child)
            child.free()
        return
    elif path.ends_with("/escalator_steps.gd"):
        pass # Prepared tread mesh plus original exported motion parameters.
    elif path.ends_with("/platform_monitor.gd"):
        # The original _ready creates the viewport and binds the screen material.
        for child in node.get_children():
            node.remove_child(child)
            child.free()
    elif path.ends_with("/driver_mirrors.gd"):
        pass # Original lightweight runtime binding, without static construction.
    elif script!=null:
        if _runtime_script(script):
            _unsupported=path
            return
        node.set_script(null)
    node.scene_file_path=""
    if node.has_meta("metro_line_work"): node.remove_meta("metro_line_work")
    for child in node.get_children(): await _adapt(child,station)

func _runtime_script(script: Script) -> bool:
    var source: String=script.source_code
    if "func _process(" in source or "func _physics_process(" in source or "func _input(" in source: return true
    var base := script.get_base_script()
    return _runtime_script(base) if base!=null else false

func _fragments(station: Node3D) -> Array:
    return await _fragment_children(station,station)

func _fragment_children(parent: Node, station: Node3D) -> Array:
    var result: Array=[]
    var group: Array[Node]=[]
    var count := 0
    for child in parent.get_children():
        var size: int=_count(child)
        if size>64 and child.get_script()==null:
            if not group.is_empty():
                result.append(await _fragment_group(parent,station,group))
                group.clear()
                count=0
            # Save the original parent first, then its children in bounded
            # fragments. Keep the exact hierarchy, names and local transforms.
            var descendants: Array[Node]=child.get_children()
            for descendant in descendants:
                _clear_owners(descendant)
                child.remove_child(descendant)
            result.append(await _fragment_group(parent,station,[child]))
            for descendant in descendants:
                child.add_child(descendant)
                _owners(descendant,station)
            result.append_array(await _fragment_children(child,station))
        else:
            if count>0 and count+size>64:
                result.append(await _fragment_group(parent,station,group))
                group.clear()
                count=0
            # Existing scripted runtime mechanisms remain atomic and unchanged.
            group.append(child)
            count+=size
    if not group.is_empty(): result.append(await _fragment_group(parent,station,group))
    return result

func _fragment_group(parent: Node, station: Node3D, nodes: Array[Node]) -> Dictionary:
    var fragment := Node3D.new()
    fragment.name="PreparedArchitecture"
    var parent_path: String=str(station.get_path_to(parent))
    var positions: Array[int]=[]
    for child in nodes: positions.append(child.get_index())
    for child in nodes:
        _clear_owners(child)
        parent.remove_child(child)
        fragment.add_child(child)
    var description: Dictionary=await _fragment(fragment)
    description["attach_parent"]=parent_path
    for i in range(nodes.size()):
        var child: Node=nodes[i]
        _clear_owners(child)
        fragment.remove_child(child)
        parent.add_child(child)
        parent.move_child(child,positions[i])
        _owners(child,station)
    fragment.free()
    return description

func _count(node: Node) -> int:
    var count := 1
    for child in node.get_children(): count+=_count(child)
    return count

func _fragment(fragment: Node3D) -> Dictionary:
    await _externalize_node(fragment)
    _owners(fragment,fragment)
    var scene := PackedScene.new()
    if scene.pack(fragment)!=OK: _fail("Cannot pack prepared architecture"); return {}
    var saved: String=await _save_resource(scene,"scn")
    var dependencies: Dictionary={}
    var textures: Dictionary={}
    _dependencies(saved,dependencies,textures)
    var shared: Array=[]
    var geometry: Array=[]
    for file in dependencies.values():
        if _locations.has(file.path): continue
        if bool(file.get("shared",false)): shared.append(file)
        else: geometry.append(file)
    # Each native resource is stored once. Separate shared materials/textures
    # from geometry so a distant section need not fetch another section's meshes.
    for group in [shared,geometry]:
        if not group.is_empty(): _archive(group)
    var files: Array=[]
    var required_archives: Dictionary={}
    for path in dependencies:
        var file: Dictionary=_locations[path]
        files.append(file)
        required_archives[file.archive]=_archives[file.archive]
    return {"scene":saved,"files":files,"textures":textures.values(),"archives":required_archives.values()}

func _archive(files: Array) -> void:
    var prepared: Array=[]
    var temporary := "user://metro-static-stage/chunk.bin"
    var output := FileAccess.open(temporary,FileAccess.WRITE)
    for file in files:
        var item: Dictionary=file.duplicate()
        item.erase("shared")
        item["offset"]=output.get_position()
        output.store_buffer(FileAccess.get_file_as_bytes(str(file.path)))
        prepared.append(item)
    output.close()
    var digest := FileAccess.get_sha256(temporary)
    var filename := "world-"+digest+".bin"
    DirAccess.make_dir_recursive_absolute(_folder)
    if DirAccess.copy_absolute(temporary,_folder.path_join(filename))!=OK:
        _fail("Cannot retain compiled geometry archive")
        return
    var size: int=FileAccess.get_file_as_bytes(temporary).size()
    _archives[filename]={"file":filename,"bytes":size,"sha256":digest}
    for file in prepared:
        file["archive"]=filename
        _locations[file.path]=file

func _clear_owners(node: Node) -> void:
    # A fragment owner ceases to be an ancestor after moving this subtree.
    # Clear the entire ownership chain before detaching, then bind its new root.
    node.owner=null
    for child in node.get_children(): _clear_owners(child)

func _owners(node: Node, owner_node: Node) -> void:
    if node!=owner_node: node.owner=owner_node
    node.scene_file_path=""
    for child in node.get_children(): _owners(child,owner_node)

func _externalize_node(node: Node) -> void:
    for property in node.get_property_list():
        if (int(property.usage) & PROPERTY_USAGE_STORAGE)==0: continue
        if property.name=="script": continue
        var value: Variant=node.get(property.name)
        if value is Resource: node.set(property.name,await _externalize(value))
    for child in node.get_children(): await _externalize_node(child)

func _externalize(resource: Resource) -> Resource:
    if resource is Script: return resource
    if _written.has(resource.resource_path): return resource
    var key: int=resource.get_instance_id()
    if _resources.has(key): return _resources[key]
    if _visiting.has(key): return resource
    # Existing imported source assets remain in their existing module packs.
    if resource.resource_path.begins_with("res://") and "::" not in resource.resource_path: return resource
    _visiting[key]=true
    var prepared: Resource=resource
    # Retain QuadMesh for the original advertising code, which edits its material.
    # All other procedural primitive surfaces become ready native ArrayMeshes.
    if resource is PrimitiveMesh and not resource is QuadMesh:
        var mesh := ArrayMesh.new()
        for surface in range((resource as Mesh).get_surface_count()):
            mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,(resource as Mesh).surface_get_arrays(surface))
            mesh.surface_set_material(surface,(resource as Mesh).surface_get_material(surface))
        prepared=mesh
    if resource is NoiseTexture2D:
        var image: Image=resource.get_image()
        if image==null:
            await resource.changed
            image=resource.get_image()
        if image==null: _fail("Cannot prepare generated texture"); return resource
        prepared=ImageTexture.create_from_image(image)
    for property in prepared.get_property_list():
        if (int(property.usage) & PROPERTY_USAGE_STORAGE)==0 or property.name in ["script","resource_path"]: continue
        var value: Variant=prepared.get(property.name)
        if value is Resource or value is Array or value is Dictionary:
            prepared.set(property.name,await _externalize_value(value))
    await _save_resource(prepared,"res")
    _visiting.erase(key)
    _resources[key]=prepared
    return prepared

func _externalize_value(value: Variant) -> Variant:
    if value is Resource: return await _externalize(value)
    if value is Array:
        var array: Array=value.duplicate()
        for i in range(array.size()): array[i]=await _externalize_value(array[i])
        return array
    if value is Dictionary:
        var dictionary: Dictionary=value.duplicate()
        for key in dictionary: dictionary[key]=await _externalize_value(dictionary[key])
        return dictionary
    return value

func _save_resource(resource: Resource, extension: String) -> String:
    _serial+=1
    var temporary := "user://metro-static-stage/%d.%s" % [_serial,extension]
    DirAccess.make_dir_recursive_absolute(temporary.get_base_dir())
    if ResourceSaver.save(resource,temporary)!=OK: _fail("Cannot save prepared resource"); return ""
    var digest := FileAccess.get_sha256(temporary)
    var path := "user://metro-static/"+digest+"."+extension
    DirAccess.make_dir_recursive_absolute(path.get_base_dir())
    if not FileAccess.file_exists(path): DirAccess.rename_absolute(temporary,path)
    else: DirAccess.remove_absolute(temporary)
    resource.take_over_path(path)
    if not _written.has(path):
        _written[path]={"path":path,"sha256":digest,"bytes":FileAccess.get_file_as_bytes(path).size(),
            "shared":not (resource is Mesh or resource is MultiMesh or resource is PackedScene)}
    return path

func _dependencies(path: String, found: Dictionary, textures: Dictionary) -> void:
    if found.has(path): return
    if not _written.has(path): _fail("Missing compiled resource "+path); return
    found[path]=_written[path]
    for dependency in ResourceLoader.get_dependencies(path):
        var target: String=str(dependency).split("::")[-1]
        if target.begins_with("user://metro-static/"):
            _dependencies(target,found,textures)
        elif target.begins_with("res://") and target.get_extension().to_lower() in ["png","jpg","jpeg","webp","svg","ctex"]:
            var texture := ResourceLoader.load(target) as Texture2D
            if texture==null:
                _fail("Cannot retain prepared material texture "+target)
                return
            textures[target]={"path":target,"bytes":int(texture.get_width()*texture.get_height()*16/3)}
    found.erase(path)
    found[path]=_written[path]

func _tunnels() -> void:
    var route=load("res://modules/line/line_path.gd").new()
    var layout: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://modules/line/route_layout.json"))
    var info: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://audio/data/route_stations.json"))
    if not route.configure_route(layout,info): _fail("Cannot compile route"); return
    var builder=load("res://modules/line/line_tunnel_generator.gd").new()
    builder.path=route
    builder.set_process(false)
    _host.add_child(builder)
    var section: Node3D=builder._new_section()
    builder._remember_parts(section)
    var base_nodes: Array[Node3D]=[]
    for record in builder._source_parts[section]:
        var node: Node3D=record.node
        if record.has("mesh"):
            var mesh: Mesh=record.mesh
            if mesh==builder._shell or mesh==builder._floor or mesh==builder._rail or (mesh is ArrayMesh and mesh in builder._contact_meshes):
                base_nodes.append(node)
        elif record.has("multi"):
            if record.multi==builder._sleepers or record.multi==builder._insulators or record.multi==builder._rail_clips:
                base_nodes.append(node)
    var spans: Dictionary={}
    var base_spans: Dictionary={}
    var part_kinds: Array[String]=[]
    for node in base_nodes: part_kinds.append(node.get_class())
    for slot in range(floori(route.lower_z/16.0),ceili(96.0/16.0)):
        var low: float=maxf(float(slot)*16.0,route.lower_z)
        var high: float=minf(float(slot+1)*16.0,96.0)
        if high-low<=0.001: continue
        var cuts: Array[float]=[low,high]
        for station in route.stations:
            for edge in [float(station.low),float(station.high)]:
                if edge>low and edge<high: cuts.append(edge)
        cuts.sort()
        for i in range(cuts.size()-1):
            var span: Vector2=Vector2(cuts[i],cuts[i+1])
            var station_index: int=-1
            var middle: float=(span.x+span.y)*0.5
            for station in route.stations:
                if middle>=float(station.low) and middle<=float(station.high): station_index=int(station.index);break
            await builder._warp_section(section,span)
            section.position=Vector3.ZERO
            section.get_node("WallLight").visible=posmod(floori(span.x/16.0),2)==0
            var parts: Array=[]
            for node in base_nodes:
                var part: Dictionary={"kind":node.get_class(),"name":str(node.name),"transform":node.transform,
                    "visible":node.visible and not (station_index>=0 and node.name=="ConcreteArch")}
                if node is MeshInstance3D: part["mesh"]=(node as MeshInstance3D).mesh
                else: part["multimesh"]=(node as MultiMeshInstance3D).multimesh
                part["material"]=(node as GeometryInstance3D).material_override
                parts.append(part)
            var data := Resource.new()
            data.set_meta("parts",parts)
            var local: Resource=await _local_resource(data)
            var key: String="%.4f:%.4f" % [span.x,span.y]
            base_spans[key]={"path":local.resource_path,"low":span.x,"high":span.y,"station":station_index}
            if station_index<0:
                # All original details survive, independently from the local base.
                for node in base_nodes:
                    _clear_owners(node)
                    section.remove_child(node)
                var description: Dictionary=await _fragment(section)
                description["low"]=span.x
                description["high"]=span.y
                spans[key]=description
                for node in base_nodes: section.add_child(node)
            _resources.clear()
            _local_resources.clear()
            await process_frame
    _json(str(control.index),{"schema":2,"metres_per_unit":1.0,"source_commit":control.source_commit,
        "source_route":"res://modules/line/route_layout.json","spans":spans,
        "base":base_spans,"base_part_kinds":part_kinds})
    builder.free()

func _local_resource(source: Resource) -> Resource:
    # Base path resources live inside the existing full_line PCK. They never
    # depend on HTTP archives or the decorative cache's memory budget.
    if source is Script: return source
    if source.resource_path.begins_with("res://") and "::" not in source.resource_path: return source
    var id: int=source.get_instance_id()
    if _local_resources.has(id): return _local_resources[id]
    var resource: Resource=source.duplicate(false)
    if source is PrimitiveMesh and not source is QuadMesh:
        var mesh := ArrayMesh.new()
        for surface in range((source as Mesh).get_surface_count()):
            mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,(source as Mesh).surface_get_arrays(surface))
            mesh.surface_set_material(surface,(source as Mesh).surface_get_material(surface))
        resource=mesh
    if source is NoiseTexture2D:
        var image: Image=source.get_image()
        if image==null:
            await source.changed
            image=source.get_image()
        if image==null: _fail("Cannot prepare base path texture"); return resource
        resource=ImageTexture.create_from_image(image)
    _local_resources[id]=resource
    for property in resource.get_property_list():
        if (int(property.usage)&PROPERTY_USAGE_STORAGE)==0 or property.name in ["script","resource_path"]: continue
        var value: Variant=resource.get(property.name)
        if value is Resource or value is Array or value is Dictionary:
            resource.set(property.name,await _local_value(value))
    var directory: String="res://modules/line/prebuilt/base"
    DirAccess.make_dir_recursive_absolute(directory)
    var temporary: String=directory+"/pending.res"
    if ResourceSaver.save(resource,temporary)!=OK: _fail("Cannot save base path resource"); return resource
    var digest: String=FileAccess.get_sha256(temporary)
    var target: String=directory+"/"+digest+".res"
    if FileAccess.file_exists(target): DirAccess.remove_absolute(temporary)
    elif DirAccess.rename_absolute(temporary,target)!=OK: _fail("Cannot retain base path resource"); return resource
    resource.take_over_path(target)
    # Optional detail archives reference these exact PCK materials/textures.
    # The store need not decode a second copy under a different user:// path.
    if source is Material or source is Texture2D or source is Shader: _resources[id]=resource
    DirAccess.make_dir_recursive_absolute(_folder.path_join("base"))
    if DirAccess.copy_absolute(target,_folder.path_join("base").path_join(digest+".res"))!=OK:
        _fail("Cannot cache base path resource")
    return resource

func _local_value(value: Variant) -> Variant:
    if value is Resource: return await _local_resource(value)
    if value is Array:
        var result: Array=value.duplicate()
        for i in range(result.size()): result[i]=await _local_value(result[i])
        return result
    if value is Dictionary:
        var result: Dictionary=value.duplicate()
        for key in result: result[key]=await _local_value(result[key])
        return result
    return value

func _json(path: String, data: Variant) -> void:
    DirAccess.make_dir_recursive_absolute(path.get_base_dir())
    var file := FileAccess.open(path,FileAccess.WRITE)
    file.store_string(JSON.stringify(data))

func _fail(message: String) -> void:
    push_error(message)
    quit(1)
