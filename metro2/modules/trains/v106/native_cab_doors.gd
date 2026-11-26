extends RefCounted
## Bind precomputed wall meshes and two prepared leaves. Never read triangles.
static func install(car: Node3D, number: int, vehicle: Node) -> bool:
    if car.has_meta("native_side_cab_door"): return true
    var path: String="res://modules/trains/v106/prebuilt/side_cab_%02d.res" % number
    var bundle:=ResourceLoader.load(path) as Resource
    if bundle==null:
        push_error("Missing prepared V106 side door: "+path)
        return false
    var patches: Array=bundle.get_meta("patches",[])
    var scene: PackedScene=bundle.get_meta("door_scene",null) as PackedScene
    if patches.is_empty() or scene==null:
        push_error("Incomplete prepared V106 side door: "+path)
        return false
    # Resolve every target before changing any reference.
    var targets: Array[MeshInstance3D]=[]
    for patch in patches:
        var target:=car.get_node_or_null(NodePath(str(patch.path))) as MeshInstance3D
        if target==null or not patch.mesh is Mesh:
            push_error("V106 side-door source path changed: "+str(patch.path))
            return false
        targets.append(target)
    var door:=scene.instantiate() as Node3D
    if door==null: return false
    for i in range(patches.size()):
        var target: MeshInstance3D=targets[i]
        for surface in range(target.get_surface_override_material_count()):
            target.set_surface_override_material(surface,null)
        target.mesh=patches[i].mesh
        target.material_override=null
    door.name="NativeCabSideDoor"
    door.set("vehicle",weakref(vehicle))
    car.add_child(door)
    car.set_meta("native_side_cab_door",true)
    return true

static func collect(consist: Node3D) -> Array[Dictionary]:
    var records: Array[Dictionary]=[]
    for number in [1,4]:
        var car:=consist.get_node_or_null("OriginalV106Car%02d" % number) as Node3D
        if car==null: continue
        var door:=car.get_node_or_null("NativeCabSideDoor") as Node3D
        if door!=null and door.has_method("interaction_record"): records.append(door.interaction_record())
    return records
