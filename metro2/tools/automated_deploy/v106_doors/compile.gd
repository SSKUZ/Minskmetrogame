extends SceneTree
## CI resource compiler: original imported models only, no game/train scene.
const Split = preload("res://tools/automated_deploy/v106_doors/skin_split.gd")
const Door = preload("res://modules/trains/v106/side_cab_door.gd")
const CONFIG := "res://modules/trains/v106/side_cab_doors.json"
var host: Node3D

func _initialize() -> void:
    call_deferred("_compile")

func _compile() -> void:
    var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(CONFIG))
    host=Node3D.new()
    host.process_mode=Node.PROCESS_MODE_DISABLED
    root.add_child(host)
    for model in data.models:
        if not await _model(model,data.door):
            host.free()
            quit(1)
            return
    host.free()
    quit(0)

func _model(model: Dictionary, definition: Dictionary) -> bool:
    var source:=load(str(model.source)) as PackedScene
    if source==null: return _fail("Missing original model "+str(model.source))
    var car:=source.instantiate() as Node3D
    if car==null: return _fail("Cannot instantiate original model resource")
    host.add_child(car)
    var authored: Node3D=car if str(car.name)==str(model.authored_root) else car.find_child(str(model.authored_root),true,false) as Node3D
    if authored==null: return _fail("Missing authored V106 frame "+str(model.authored_root))
    var frame: Transform3D=car.global_transform.affine_inverse()*authored.global_transform
    if absf(frame.basis.determinant())<0.000001: return _fail("Singular V106 authored frame")
    var opening: AABB=frame*AABB(_v(definition.minimum),_v(definition.size))
    var hinge: Vector3=frame*_v(definition.hinge)
    var threshold: Vector3=frame*_v(definition.threshold)
    var outside: Vector3=frame.basis*Vector3(float(definition.side),0,0)
    var original: Dictionary={}
    for node in car.find_children("*","MeshInstance3D",true,false):
        original[node]=node.mesh
    # An empty exclusion node cannot exclude any source geometry. Only the
    # side aperture is supplied; the rear partition is never passed to Split.
    var exclusion:=Node3D.new()
    host.add_child(exclusion)
    var splitter=Split.new()
    var records: Array[Dictionary]=await splitter.prepare(car,exclusion,[{
        "name":"PreparedSideLeaf","minimum":_a(opening.position),"size":_a(opening.size),
        "hinge":_a(hinge),"threshold":_a(threshold),"side":-1 if outside.x<0.0 else 1,"angle":float(definition.angle)}])
    exclusion.free()
    if records.size()!=1: return _fail("Cannot prepare original side door for car "+str(model.car)+": "+splitter.error_message)
    var pivot: Node3D=records[0].pivot
    var patches: Array=[]
    for node in original:
        if node.mesh!=original[node]:
            patches.append({"path":str(car.get_path_to(node)),"mesh":node.mesh})
    if patches.is_empty(): return _fail("No original wall surfaces prepared")
    var door:=Node3D.new()
    door.name="NativeCabSideDoor"
    door.set_script(Door)
    door.set("car_number",int(model.car))
    door.set("threshold",threshold)
    door.set("side",-1 if outside.x<0.0 else 1)
    door.set("angle",float(definition.angle))
    door.set("duration",float(definition.duration))
    host.add_child(door)
    pivot.reparent(door,false)
    pivot.name="DoorPivot"
    var body:=AnimatableBody3D.new()
    body.name="OriginalSideDoorBody"
    body.sync_to_physics=false
    body.collision_layer=1<<17
    body.collision_mask=0
    body.set_meta("metro_native_walk",true)
    body.set_meta("native_cab_leaf",true)
    var leaves: Array[Node]=pivot.get_children()
    pivot.add_child(body)
    var bounds:=AABB()
    var found:=false
    for node in leaves:
        if not node is MeshInstance3D: continue
        var box: AABB=node.transform*node.get_aabb()
        bounds=bounds.merge(box) if found else box
        found=true
        node.reparent(body,false)
    if not found: return _fail("Prepared side door has no original surfaces")
    var collision:=CollisionShape3D.new()
    var shape:=BoxShape3D.new()
    shape.size=Vector3(maxf(0.04,bounds.size.x),maxf(0.04,bounds.size.y),maxf(0.04,bounds.size.z))
    collision.shape=shape
    collision.position=bounds.get_center()
    body.add_child(collision)
    var interaction:=Marker3D.new()
    interaction.name="InteractionPoint"
    interaction.position=threshold
    interaction.set_meta("functional_point",{"kind":"cab_side_door","units":"metres","car":int(model.car)})
    door.add_child(interaction)
    door.set_meta("functional_point",{"kind":"cab_side_door","threshold":threshold,"hinge":hinge,
        "axis":Vector3.UP,"open_angle":float(definition.angle),"duration_seconds":float(definition.duration),
        "source_model":str(model.source),"authored_frame":frame})
    _owners(door,door)
    var packed:=PackedScene.new()
    if packed.pack(door)!=OK: return _fail("Cannot retain prepared door scene")
    var resource:=Resource.new()
    resource.set_meta("patches",patches)
    resource.set_meta("door_scene",packed)
    resource.set_meta("original_model",str(model.source))
    resource.set_meta("authored_frame",frame)
    var path: String=str(model.resource)
    DirAccess.make_dir_recursive_absolute(path.get_base_dir())
    if ResourceSaver.save(resource,path)!=OK: return _fail("Cannot save prepared door resource "+path)
    print("V106_NATIVE_SIDE_DOOR car=",model.car," patches=",patches.size()," frame=",frame," hinge=",hinge)
    door.free()
    car.free()
    return true

func _owners(node: Node, owner_node: Node) -> void:
    if node!=owner_node: node.owner=owner_node
    node.scene_file_path=""
    for child in node.get_children(): _owners(child,owner_node)

func _v(values: Array) -> Vector3:
    return Vector3(float(values[0]),float(values[1]),float(values[2]))

func _a(value: Vector3) -> Array:
    return [value.x,value.y,value.z]

func _fail(message: String) -> bool:
    push_error(message)
    return false
