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
        if node is Skeleton3D: continue
        # Original render meshes may live beneath existing physics bodies.
        # Traverse them, but never recursively rebuild our own generated shapes.
        if node is CollisionObject3D and node.has_meta("metro_native_walk"): continue
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
        # A collapsed visual transform can still contain a real planar surface.
        # Anchor its body to an invertible ancestor and bake only the singular
        # shape poses, retaining the original render geometry unchanged.
        var anchor: Node3D=node as Node3D
        while absf(anchor.global_basis.determinant())<0.0000000001:
            if anchor==root:
                push_error("Cannot prepare walking collision below a singular module root")
                return
            var parent: Node=anchor.get_parent()
            while parent!=null and not parent is Node3D: parent=parent.get_parent()
            if parent==null: return
            anchor=parent as Node3D
        var into_anchor: Transform3D=anchor.global_transform.affine_inverse()*(node as Node3D).global_transform
        var body: StaticBody3D
        if moving:
            var animated:=AnimatableBody3D.new()
            animated.sync_to_physics=false
            body=animated
        else: body=StaticBody3D.new()
        body.name="WalkCollision"
        body.set_meta("metro_native_walk",true)
        body.collision_layer=TRAIN if moving else WORLD
        body.collision_mask=0
        anchor.add_child(body)
        for pose in transforms:
            var shape_pose: Transform3D=into_anchor*pose
            var active_shapes: Array=shapes
            if absf(shape_pose.basis.determinant())<0.0000000001:
                active_shapes=await _baked_shapes(mesh,shape_pose,budget)
                shape_pose=Transform3D.IDENTITY
            for shape in active_shapes:
                var collision:=CollisionShape3D.new()
                collision.shape=shape
                collision.transform=shape_pose
                body.add_child(collision)
                if not await budget.checkpoint(): return
            if station:
                var to_station: Transform3D=root.global_transform.affine_inverse()*node.global_transform*pose
                var live: PackedVector3Array=contact_faces(mesh,to_station)
                live=_baked_faces(live,into_anchor*pose)
                if not live.is_empty():
                    var hazard:=StaticBody3D.new()
                    hazard.name="OriginalContactRail"
                    hazard.collision_layer=ELECTRIC
                    hazard.collision_mask=0
                    hazard.set_meta("metro_electric",true)
                    body.add_child(hazard)
                    hazard.transform=Transform3D.IDENTITY
                    var collision:=CollisionShape3D.new()
                    collision.shape=triangle_shape(live)
                    hazard.add_child(collision)
            if not await budget.checkpoint(): return
    root.set_meta("metro_walk_collision",1)
    _shapes.clear()

static func clear_generated(root: Node3D) -> void:
    for body in root.find_children("*","CollisionObject3D",true,false):
        if is_instance_valid(body) and body.has_meta("metro_native_walk"): body.free()
    root.remove_meta("metro_walk_collision")

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

func _baked_shapes(mesh: Mesh, pose: Transform3D, budget: RefCounted) -> Array:
    var faces: PackedVector3Array=mesh.get_faces()
    var result: Array=[]
    for offset in range(0,faces.size(),1152):
        var baked: PackedVector3Array=_baked_faces(faces.slice(offset,mini(offset+1152,faces.size())),pose)
        if not baked.is_empty(): result.append(triangle_shape(baked))
        if not await budget.checkpoint(): return []
    return result

static func _baked_faces(faces: PackedVector3Array, pose: Transform3D) -> PackedVector3Array:
    var result:=PackedVector3Array()
    for i in range(0,faces.size(),3):
        var a: Vector3=pose*faces[i]
        var b: Vector3=pose*faces[i+1]
        var c: Vector3=pose*faces[i+2]
        # Collapsed lines/points have no physical surface. Planar triangles stay.
        if (b-a).cross(c-a).length_squared()<0.000000000001: continue
        result.append(a)
        result.append(b)
        result.append(c)
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

# Runtime-only local preparation. CI's complete station compiler above remains
# unchanged; these bodies are leased only around the physical character.
var _near_roots: Dictionary={}
var _near_shapes: Dictionary={}
var error_message:=""

func covers(root: Node3D, world_point: Vector3, margin: float=3.0) -> bool:
    if not is_instance_valid(root): return false
    if root.has_meta("metro_walk_collision"): return true
    var state: Dictionary=_near_roots.get(root.get_instance_id(),{})
    return not state.is_empty() and state.ready and (state.area as AABB).grow(-margin).has_point(root.to_local(world_point))

func prepare_near(root: Node3D, world_point: Vector3, radius: float=16.0) -> bool:
    error_message=""
    if not is_instance_valid(root):
        error_message="Отсутствует объект физического мира"
        return false
    if root.has_meta("metro_walk_collision"): return true
    if absf(root.global_basis.determinant())<0.0000000001:
        error_message="Некорректный масштаб физического объекта"
        return false
    var point: Vector3=root.to_local(world_point)
    var area:=AABB(point-Vector3.ONE*radius,Vector3.ONE*radius*2.0)
    var id: int=root.get_instance_id()
    if not _near_roots.has(id): _near_roots[id]={"area":area,"ready":false,"parts":{}}
    var state: Dictionary=_near_roots[id]
    var budget=Budget.new(root,1500)
    var deadline: int=Time.get_ticks_msec()+120000
    var inverse: Transform3D=root.global_transform.affine_inverse()
    var nodes: Array[Node]=[root]
    while not nodes.is_empty():
        if not is_instance_valid(root) or Time.get_ticks_msec()>deadline:
            error_message="Не завершена подготовка локальных коллизий"
            return false
        var node: Node=nodes.pop_back()
        if node is Skeleton3D: continue
        if node is CollisionObject3D and node.has_meta("metro_native_walk"): continue
        nodes.append_array(node.get_children())
        if not await budget.checkpoint(): return false
        var mesh: Mesh
        var poses: Array[Transform3D]=[Transform3D.IDENTITY]
        if node is MeshInstance3D:
            if node.mesh==null or node.skin!=null or not _visible(node,root): continue
            mesh=node.mesh
        elif node is MultiMeshInstance3D:
            if node.multimesh==null or node.multimesh.mesh==null or not _visible(node,root): continue
            mesh=node.multimesh.mesh
            poses.clear()
            var count: int=node.multimesh.instance_count
            if node.multimesh.visible_instance_count>=0: count=mini(count,node.multimesh.visible_instance_count)
            for i in range(count):
                poses.append(node.multimesh.get_instance_transform(i))
                if i%64==0 and not await budget.checkpoint(): return false
        else: continue
        if mesh.get_aabb().size.length()<0.045: continue
        var node_pose: Transform3D=inverse*(node as Node3D).global_transform
        var faces:=PackedVector3Array()
        for instance_index in range(poses.size()):
            if not await budget.checkpoint(): return false
            var pose: Transform3D=poses[instance_index]
            var local: Transform3D=node_pose*pose
            if not area.intersects(local*mesh.get_aabb()): continue
            if faces.is_empty(): faces=mesh.get_faces()
            var anchor:=node as Node3D
            while absf(anchor.global_basis.determinant())<0.0000000001:
                var parent: Node=anchor.get_parent()
                while parent!=null and not parent is Node3D: parent=parent.get_parent()
                if parent==null: return false
                anchor=parent as Node3D
            var shape_pose: Transform3D=anchor.global_transform.affine_inverse()*(node as Node3D).global_transform*pose
            for offset in range(0,faces.size(),1152):
                if not await budget.checkpoint(): return false
                if Time.get_ticks_msec()>deadline:
                    error_message="Не завершена подготовка локальных коллизий"
                    return false
                var key: String="%d:%d:%d:%d" % [node.get_instance_id(),mesh.get_instance_id(),instance_index,offset]
                if state.parts.has(key): continue
                var part: PackedVector3Array=faces.slice(offset,mini(offset+1152,faces.size()))
                if part.is_empty(): continue
                var box:=AABB(part[0],Vector3.ZERO)
                for vertex in part: box=box.expand(vertex)
                var bounds: AABB=local*box
                if not area.intersects(bounds): continue
                var collision_pose: Transform3D=shape_pose
                var shape: Shape3D
                if absf(shape_pose.basis.determinant())<0.0000000001:
                    part=_baked_faces(part,shape_pose)
                    collision_pose=Transform3D.IDENTITY
                    if part.is_empty(): continue
                    shape=triangle_shape(part)
                else:
                    var shape_key: String="%d:%d" % [mesh.get_instance_id(),offset]
                    if _near_shapes.has(shape_key): shape=_near_shapes[shape_key].get_ref() as Shape3D
                    if shape==null:
                        shape=triangle_shape(part)
                        _near_shapes[shape_key]=weakref(shape)
                var body: StaticBody3D
                if root.is_in_group("metro_walking_train"):
                    var animated:=AnimatableBody3D.new()
                    animated.sync_to_physics=false
                    body=animated
                else: body=StaticBody3D.new()
                body.name="WalkCollision"
                body.set_meta("metro_native_walk",true)
                body.collision_layer=TRAIN if root.is_in_group("metro_walking_train") else WORLD
                body.collision_mask=0
                anchor.add_child(body)
                var collider:=CollisionShape3D.new()
                collider.shape=shape
                collider.transform=collision_pose
                body.add_child(collider)
                state.parts[key]={"body":body,"bounds":bounds}
                if not await budget.checkpoint(): return false
    # Retire only this controller's distant collision slices, never render nodes.
    var keep: AABB=area.grow(radius)
    for key in state.parts.keys():
        var record: Dictionary=state.parts[key]
        if not is_instance_valid(record.body):
            state.parts.erase(key)
        elif not keep.intersects(record.bounds):
            record.body.queue_free()
            state.parts.erase(key)
    for key in _near_shapes.keys():
        if _near_shapes[key].get_ref()==null: _near_shapes.erase(key)
    state.area=area
    state.ready=true
    return true
