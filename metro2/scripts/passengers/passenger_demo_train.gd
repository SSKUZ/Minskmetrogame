extends Node3D
const MODELS=[preload("res://assets/v106_lod1/v106_car01_lod1_mesh289_normals_fixed.glb"),preload("res://assets/v106_original/car02/v106_car_02.glb"),preload("res://assets/v106_original/car03/v106_car_03.glb"),preload("res://assets/v106_original/car04/v106_car_04.glb")]
const Bogies=preload("res://scripts/depot/v106_bogies.gd")
var _bogie_visuals=Bogies.new()
var train: Node3D
var door_system: Node
var cab_runtime: Node3D
var cars: Array[Node3D]=[]
var front := 0.0
var back := 0.0

func _ready() -> void:
    train=Node3D.new();train.name="OriginalFourCarV106";add_child(train)
    train.position=Vector3(0.992,0.22,0)
    var previous: Node3D
    var previous_body:=AABB()
    for i in MODELS.size():
        var car: Node3D=MODELS[i].instantiate()
        car.name="OriginalV106Car%02d"%(i+1)
        train.add_child(car);cars.append(car)
        var bounds:=_get_model_bounds(car)
        var body: AABB=_bogie_visuals.body_bounds(car,bounds)
        if previous!=null:
            var gap: float=_bogie_visuals.half_body_gap(previous,_get_model_bounds(previous),car,bounds)
            car.position.z=previous.position.z+previous_body.end.z+gap-body.position.z
        _bogie_visuals.setup_car(car,bounds,car.transform)
        previous=car;previous_body=body
        front=minf(front,car.position.z+body.position.z)
        back=maxf(back,car.position.z+body.end.z)
    door_system=preload("res://scripts/v33_door_controller.gd").new()
    add_child(door_system);door_system.setup(train)
    preload("res://scripts/v106_warning_stickers.gd").restore(train,door_system)
    preload("res://scripts/depot/saloon_advertising_v46.gd").decorate(self,train,door_system)
    var ui:=CanvasLayer.new();add_child(ui)
    var lighting=preload("res://scripts/train_interior_v36.gd").new();add_child(lighting)
    lighting.initialize(self,train,ui)
    ui.hide()

func move_to(z: float) -> void:
    train.position.z=z
    for car in cars: _bogie_visuals.update_car(car,train,z)

func _get_model_bounds(root: Node3D) -> AABB:
    var found := false
    var result := AABB()
    var pending: Array[Node] = [root]
    while not pending.is_empty():
        var node: Node = pending.pop_back()
        if node is MeshInstance3D:
            var mesh_node := node as MeshInstance3D
            if mesh_node.mesh != null:
                var local_bounds := mesh_node.get_aabb()
                var xf := root.global_transform.affine_inverse() * mesh_node.global_transform
                var transformed := xf * local_bounds
                if not found:
                    result = transformed
                    found = true
                else:
                    result = result.merge(transformed)
        for child in node.get_children():
            pending.append(child)
    return result

