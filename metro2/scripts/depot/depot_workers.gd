extends Node3D
## Eight original passenger models in high-visibility maintenance clothing.
const Pose = preload("res://scripts/passengers/passenger_behaviour.gd")
const Animator = preload("res://scripts/passengers/passenger_animation.gd")
var workers: Array[Dictionary] = []
var clock := 0.0
var vest: StandardMaterial3D
var stripe: StandardMaterial3D
var navy: StandardMaterial3D
var steel: StandardMaterial3D
var timber: StandardMaterial3D

func _mat(color: Color,metal: float=0.0) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color=color
    m.metallic=metal
    m.roughness=0.75
    return m

func _box(parent: Node3D,size: Vector3,p: Vector3,m: Material) -> void:
    var mesh := BoxMesh.new()
    mesh.size=size
    mesh.material=m
    var node := MeshInstance3D.new()
    node.mesh=mesh
    node.position=p
    parent.add_child(node)

func _attach(skeleton: Skeleton3D,bone: String) -> BoneAttachment3D:
    var n := BoneAttachment3D.new()
    n.bone_name=bone
    skeleton.add_child(n)
    return n

func _ready() -> void:
    vest=_mat(Color("#f36b12"))
    stripe=_mat(Color("#d8dfcb"),0.35)
    navy=_mat(Color("#263344"))
    steel=_mat(Color("#666d72"),0.7)
    timber=_mat(Color("#8e5e30"))
    var files := ["res://assets/passengers/man-casual-low.glb","res://assets/passengers/man-shirt-low.glb"]
    var locations := [Vector3(-14,6,425),Vector3(-8.1,6,444),Vector3(-14,6,464),Vector3(8.8,6,426),Vector3(15,6,452),Vector3(-8.2,6,483),Vector3(8.8,6,480),Vector3(15,6,503)]
    for i in range(8):
        var scene := load(files[i%2]) as PackedScene
        if scene==null: continue
        var root := Node3D.new()
        root.name="TrackWorker%02d" % (i+1)
        root.position=locations[i]
        add_child(root)
        var visual := scene.instantiate() as Node3D
        root.add_child(visual)
        var animator := Animator.new()
        animator.setup(visual,100+i)
        animator.play("Idle")
        var skeleton: Skeleton3D
        for node in visual.find_children("*","Skeleton3D",true,false): skeleton=node;break
        if skeleton==null: continue
        # Keep original heads/hands; overalls and vest are fitted to existing bones.
        var torso := _attach(skeleton,"Spine2")
        _box(torso,Vector3(0.40,0.43,0.25),Vector3(0,0.04,0),navy)
        _box(torso,Vector3(0.42,0.39,0.265),Vector3(0,0.04,0.003),vest)
        for y in [-0.065,0.045]: _box(torso,Vector3(0.428,0.035,0.273),Vector3(0,y,0.003),stripe)
        for x in [-0.12,0.12]: _box(torso,Vector3(0.035,0.37,0.278),Vector3(x,0.04,0.003),stripe)
        for bone in ["LeftUpLeg","RightUpLeg","LeftLeg","RightLeg"]:
            var leg := _attach(skeleton,bone)
            _box(leg,Vector3(0.15,0.32,0.16),Vector3(0,0.16,0),navy)
        var hand := _attach(skeleton,"RightHand")
        if i%4==0:
            _box(hand,Vector3(0.032,0.40,0.032),Vector3(0,0.16,0),timber)
            _box(hand,Vector3(0.23,0.09,0.09),Vector3(0,0.35,0),steel)
        elif i%4==1:
            _box(hand,Vector3(0.04,0.30,0.02),Vector3(0,0.12,0),steel)
            _box(hand,Vector3(0.11,0.06,0.025),Vector3(0,0.28,0),steel)
        elif i%4==2:
            _box(hand,Vector3(0.18,0.25,0.015),Vector3(0,0.10,0),timber)
            _box(hand,Vector3(0.16,0.21,0.002),Vector3(0,0.10,-0.01),_mat(Color("#d9dbce")))
        else:
            _box(hand,Vector3(0.07,0.16,0.07),Vector3(0,0.07,0),steel)
        var pose := Pose.new()
        root.add_child(pose)
        pose.set_process(false)
        pose.skeleton=skeleton
        for bone_id in range(skeleton.get_bone_count()): pose.bones[str(skeleton.get_bone_name(bone_id)).to_lower()]=bone_id
        workers.append({"pose":pose,"root":root,"visual":visual,"animator":animator,"skeleton":skeleton,"home":locations[i],"id":i})

func _process(delta: float) -> void:
    clock+=minf(delta,0.1)
    for w in workers:
        var i: int=w.id
        var root: Node3D=w.root
        var a: RefCounted=w.animator
        var cycle := fmod(clock+float(i)*4.3,36.0)
        if i in [0,3,4,7] and cycle<14.0:
            (w.skeleton as Skeleton3D).clear_bones_global_pose_override()
            a.play("Walk")
            var distance := cycle*0.48
            root.position=w.home+Vector3(0,0,distance if i%2==0 else -distance)
            root.rotation.y=lerp_angle(root.rotation.y,0.0 if i%2==0 else PI,minf(1.0,delta*2.5))
        elif i in [0,3,4,7] and cycle>20.0 and cycle<34.0:
            (w.skeleton as Skeleton3D).clear_bones_global_pose_override()
            a.play("Walk")
            var distance := (34.0-cycle)*0.48
            root.position=w.home+Vector3(0,0,distance if i%2==0 else -distance)
            root.rotation.y=lerp_angle(root.rotation.y,PI if i%2==0 else 0.0,minf(1.0,delta*2.5))
        else:
            a.play("Idle")
            var skeleton: Skeleton3D=w.skeleton
            skeleton.clear_bones_global_pose_override()
            for bone in ["Spine","Spine1"]:
                var idx := skeleton.find_bone(bone)
                if idx<0: continue
                var pose := skeleton.get_bone_global_pose(idx)
                var work := 0.18 if i in [1,5] else 0.04
                pose.basis=pose.basis*Basis(Vector3.RIGHT,work+sin(clock*0.35+float(i))*0.012)
                skeleton.set_bone_global_pose_override(idx,pose,1.0,true)

            skeleton.force_update_all_bone_transforms()
            if i in [1,2,5,6]:
                var pose: Node=w.pose
                var spine := skeleton.find_bone("Spine2")
                if spine>=0:
                    var origin := skeleton.get_bone_global_pose(spine).origin
                    pose._arm("right",origin+Vector3(-0.12,-0.22,0.32+sin(clock*0.8+float(i))*0.015),1.0)
                    pose._arm("left",origin+Vector3(0.12,-0.25,0.30),1.0)
