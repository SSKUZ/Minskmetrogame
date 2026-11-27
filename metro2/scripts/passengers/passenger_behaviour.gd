extends Node
## Calm, deterministic activities layered on the original passenger skeleton.
var agent: Node3D
var skeleton: Skeleton3D
var bones: Dictionary = {}
var age := 0.0
var phase := 0.0
var activity := 0
var blend := 0.0
var phone: Node3D
var leaflet: Node3D
var _active := false
var _next_activity := 0.0

func setup(owner_agent: Node3D) -> void:
    agent=owner_agent
    skeleton=agent.skeleton
    phase=float(agent.id)*1.731
    activity=(agent.id+int(agent.id/4))%4
    _next_activity=8.0+float(agent.id%11)*1.3
    process_priority=35
    if skeleton==null: return
    for i in range(skeleton.get_bone_count()):
        var key := str(skeleton.get_bone_name(i)).get_slice(":",str(skeleton.get_bone_name(i)).get_slice_count(":")-1).to_lower()
        bones[key]=i
    phone=_prop("phone")
    leaflet=_prop("leaflet")

func _mat(color: Color) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color=color
    m.roughness=0.75
    return m

func _box(parent: Node3D,size: Vector3,p: Vector3,material: Material) -> void:
    var mesh := BoxMesh.new()
    mesh.size=size
    mesh.material=material
    var node := MeshInstance3D.new()
    node.mesh=mesh
    node.position=p
    parent.add_child(node)

func _prop(kind: String) -> Node3D:
    if not bones.has("righthand"): return null
    var attachment := BoneAttachment3D.new()
    attachment.bone_name=skeleton.get_bone_name(int(bones.get("righthand",0)))
    attachment.name="Passenger"+kind.capitalize()
    skeleton.add_child(attachment)
    if kind=="phone":
        _box(attachment,Vector3(0.068,0.13,0.011),Vector3(0,0.065,-0.015),_mat(Color("#161c22")))
        _box(attachment,Vector3(0.058,0.107,0.002),Vector3(0,0.067,-0.022),_mat(Color("#91b4c0")))
    else:
        _box(attachment,Vector3(0.15,0.22,0.003),Vector3(0,0.10,-0.012),_mat(Color("#e4ded0")))
        for row in range(5): _box(attachment,Vector3(0.11,0.005,0.001),Vector3(0,0.04+float(row)*0.025,-0.014),_mat(Color("#687789")))
    attachment.hide()
    return attachment

func _pose(name: String) -> Transform3D:
    return skeleton.get_bone_global_pose(int(bones[name]))

func _apply_bone(name: String,pose: Transform3D,weight: float=1.0) -> void:
    if bones.has(name): skeleton.set_bone_global_pose_override(int(bones[name]),pose,weight,true)

func _aim(pose: Transform3D,from: Vector3,to: Vector3) -> Transform3D:
    if from.length_squared()>0.00001 and to.length_squared()>0.00001:
        pose.basis=Basis(Quaternion(from.normalized(),to.normalized()))*pose.basis
    return pose

func _arm(side: String,target: Vector3,weight: float) -> void:
    var upper := side+"arm"
    var fore := side+"forearm"
    var hand := side+"hand"
    if not bones.has(upper) or not bones.has(fore) or not bones.has(hand): return
    var a := _pose(upper)
    var b := _pose(fore)
    var c := _pose(hand)
    var l1 := a.origin.distance_to(b.origin)
    var l2 := b.origin.distance_to(c.origin)
    var offset := target-a.origin
    var distance := clampf(offset.length(),absf(l1-l2)+0.015,l1+l2-0.012)
    var direction := offset.normalized()
    var bend := Vector3(0,-0.7,0.6)
    bend=(bend-direction*bend.dot(direction)).normalized()
    var along := (l1*l1-l2*l2+distance*distance)/(2.0*distance)
    var elbow := a.origin+direction*along+bend*sqrt(maxf(0,l1*l1-along*along))
    var wrist := a.origin+direction*distance
    a=_aim(a,b.origin-a.origin,elbow-a.origin)
    b=_aim(b,c.origin-b.origin,wrist-elbow)
    b.origin=elbow
    c.origin=wrist
    _apply_bone(upper,a,weight)
    _apply_bone(fore,b,weight)
    _apply_bone(hand,c,weight)

func _process(delta: float) -> void:
    if not is_instance_valid(agent) or skeleton==null: return
    age+=minf(delta,0.1)
    var calm: bool=agent.path.is_empty() and agent.state in ["seated","riding","waiting","queued","waitingNextTrain"]
    blend=move_toward(blend,1.0 if calm else 0.0,delta*1.8)
    skeleton.clear_bones_global_pose_override()
    # Props appear only once the holding pose has blended in.
    var can_hold := bones.has("rightarm") and bones.has("rightforearm") and bones.has("righthand")
    if phone!=null: phone.visible=calm and activity==1 and can_hold and blend>0.85
    if leaflet!=null: leaflet.visible=calm and activity==2 and can_hold and blend>0.85
    if blend<=0.001:
        agent.visual.rotation.y=move_toward(agent.visual.rotation.y,0.0,delta*0.8)
        _active=false
        return
    skeleton.force_update_all_bone_transforms()
    var seated: bool=agent.state=="seated"
    if calm and age>=_next_activity:
        activity=(activity+1+int(agent.id/7)%3)%4
        _next_activity=age+12.0+float(agent.id%9)*1.7
    var social_turn := 0.0
    var peer_reference: WeakRef=agent.get_meta("social_peer",null) as WeakRef
    var peer: Node3D=peer_reference.get_ref() as Node3D if peer_reference!=null else null
    if is_instance_valid(peer) and peer.space==agent.space and peer.path.is_empty() and peer.global_position.distance_squared_to(agent.global_position)<9.0:
        var direction: Vector3=agent.global_basis.inverse()*(peer.global_position-agent.global_position)
        social_turn=clampf(atan2(direction.x,direction.z),-0.55,0.55)
    # Keep seated hips aligned with their seat; standing peers turn subtly.
    agent.visual.rotation.y=0.0 if seated else social_turn*0.12*blend
    var torso := _pose("spine2") if bones.has("spine2") else Transform3D.IDENTITY
    var reading := activity in [1,2]
    if bones.has("spine2"):
        var turn: float=social_turn*0.10 if not reading and not seated else 0.0
        torso.basis=Basis(Vector3.UP,turn)*torso.basis
        _apply_bone("spine2",torso,blend)
    if bones.has("head"):
        var head := _pose("head")
        var glance := social_turn*0.65 if not reading else 0.0
        head.basis=head.basis*Basis.from_euler(Vector3(0.13 if reading else 0.0,glance,0.0))
        _apply_bone("head",head,blend)
    if reading and can_hold:
        # One hand holds the prop; the other retains the authored idle pose.
        # Target is relative to the actual right shoulder, not a shared
        # absolute position that pushes different skeletons into cuffs pose.
        var shoulder := _pose("rightarm").origin
        var target := shoulder+Vector3(-0.035,-0.22,0.17)
        _arm("right",target,blend*0.75)
    if not seated and agent.space=="train" and is_instance_valid(agent.car) and agent.slot.has("grip"):
        # The reserved slot supplies a real car-local grip on the handrail.
        var world: Vector3=agent.car.to_global(agent.slot.get("grip",agent.position+Vector3(0,1.15,0)))
        var grip := skeleton.to_local(world)
        _arm("left",grip,blend)
    _active=true
