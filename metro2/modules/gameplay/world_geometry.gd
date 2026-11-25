extends RefCounted
## Native collision data from existing surfaces; no replacement render geometry.
const WORLD := 1<<16
const TRAIN := 1<<17
const ELECTRIC := 1<<18
const PLAYER := 1<<19
const Budget = preload("res://modules/line/build_budget.gd")
var _shapes: Dictionary={}

func prepare(root: Node3D, moving: bool=false, station: bool=false) -> void:
    if root.has_meta("metro_walk_collision"): return
    var budget=Budget.new(root,1500)
    var nodes: Array[Node]=[root]
    while not nodes.is_empty() and is_instance_valid(root):
        var node: Node=nodes.pop_back()
        if node is CollisionObject3D or node is Skeleton3D: continue
        nodes.append_array(node.get_children())
        var mesh: Mesh
        var transforms: Array[Transform3D]=[Transform3D.IDENTITY]
        if node is MeshInstance3D:
            if node.mesh==null or node.skin!=null or not _visible(node,root): continue
            mesh=node.mesh
        elif node is MultiMeshInstance3D:
            if node.multimesh==null or not _visible(node,root): continue
            mesh=node.multimesh.mesh
            transforms.clear()
            var count: int=node.multimesh.instance_count
            if node.multimesh.visible_instance_count>=0: count=mini(count,node.multimesh.visible_instance_count)
            for i in range(count): transforms.append(node.multimesh.get_instance_transform(i))
        else: continue
        if mesh==null: continue
        # Flat lettering, advertisements and live mirror screens are not walls.
        var box: AABB=mesh.get_aabb()
        if box.size.length()<0.045: continue
        var shapes: Array=await shapes_for(mesh,budget)
        var body: StaticBody3D
        if moving:
            var animated:=AnimatableBody3D.new()
            animated.sync_to_physics=false
            body=animated
        else: body=StaticBody3D.new()
        body.name="WalkCollision"
        body.collision_layer=TRAIN if moving else WORLD
        body.collision_mask=0
        node.add_child(body)
        for pose in transforms:
            for shape in shapes:
                var collision:=CollisionShape3D.new()
                collision.shape=shape
                collision.transform=pose
                body.add_child(collision)
                if not await budget.checkpoint(): return
            if station:
                var to_station: Transform3D=root.global_transform.affine_inverse()*node.global_transform*pose
                var live: PackedVector3Array=contact_faces(mesh,to_station)
                if not live.is_empty():
                    var hazard:=StaticBody3D.new()
                    hazard.name="OriginalContactRail"
                    hazard.collision_layer=ELECTRIC
                    hazard.collision_mask=0
                    hazard.set_meta("metro_electric",true)
                    body.add_child(hazard)
                    hazard.transform=pose
                    var collision:=CollisionShape3D.new()
                    collision.shape=triangle_shape(live)
                    hazard.add_child(collision)
            if not await budget.checkpoint(): return
    root.set_meta("metro_walk_collision",1)
    _shapes.clear()

func shapes_for(mesh: Mesh, budget: RefCounted) -> Array:
    if _shapes.has(mesh): return _shapes[mesh]
    var faces: PackedVector3Array=mesh.get_faces()
    var result: Array=[]
    # Bounded BVHs also bound resource instantiation when a station streams in.
    for offset in range(0,faces.size(),1152):
        result.append(triangle_shape(faces.slice(offset,mini(offset+1152,faces.size()))))
        if not await budget.checkpoint(): return []
    _shapes[mesh]=result
    return result

static func triangle_shape(faces: PackedVector3Array) -> ConcavePolygonShape3D:
    var shape:=ConcavePolygonShape3D.new()
    shape.backface_collision=true
    shape.set_faces(faces)
    return shape

static func contact_faces(mesh: Mesh, pose: Transform3D) -> PackedVector3Array:
    var result:=PackedVector3Array()
    # Station Base's bare conductor, not the running rails or protective timber.
    var bounds: AABB=pose*mesh.get_aabb()
    if bounds.position.y>0.30 or bounds.end.y<0.12: return result
    var faces: PackedVector3Array=mesh.get_faces()
    for i in range(0,faces.size(),3):
        var live:=true
        for k in range(3):
            var p: Vector3=pose*faces[i+k]
            if p.y<0.12 or p.y>0.30: live=false;break
            if absf(p.x-(0.992+1.48))>0.075 and absf(p.x-(-11.732-1.48))>0.075: live=false;break
        if not live: continue
        result.append(faces[i]);result.append(faces[i+1]);result.append(faces[i+2])
    return result

func _visible(node: Node3D, root: Node3D) -> bool:
    var current: Node=node
    while current!=root:
        if current is Node3D and not current.visible: return false
        current=current.get_parent()
    return true
