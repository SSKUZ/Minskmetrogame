extends RefCounted
## Runtime visual overrides only. Original meshes/material resources are never edited.
const WEAR = preload("res://assets/saloon_v49/interior_wear.gdshader")
const DO_NOT_LEAN = preload("res://assets/saloon_v49/do_not_lean.svg")
# Explicit dependency for the fixed-mount artwork loader / standalone staging.
const EMERGENCY_EXIT = preload("res://assets/saloon_v49/emergency_exit.svg")
const MOUNTS := "res://assets/saloon_v49/mounts.json"
const PRINT_LAYERS := 1 | (1 << 4)
# Original GLB linear colours: floor, blue upholstery, beige panels, handrails.
const COLOURS := [Vector3(0.162029,0.177888,0.181164),Vector3(0.029557,0.057805,0.095307),Vector3(0.679542,0.637597,0.520996),Vector3(0.386429,0.401978,0.376262)]

static func apply(train: Node3D,door_system: Node) -> void:
    var visual = load("res://scripts/depot/saloon_realism_v49.gd").new()
    var mounts: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MOUNTS))
    var leaves: Array = door_system.get("leaves")
    var index := 0
    for car in train.get_children():
        if not mounts.has(str(car.name)): continue
        visual._car(car,mounts[str(car.name)],leaves,index)
        index+=1

func _car(car: Node3D,layout: Dictionary,leaves: Array,index: int) -> void:
    if car.has_meta("v49_visuals"): return
    var moving: Array[Node3D] = []
    var labels := 0
    for leaf in leaves:
        var root := leaf.parts[0].node as Node3D
        if not car.is_ancestor_of(root): continue
        moving.append(root)
        if _glass_label(car,root): labels+=1
    var counts := [0,0,0,0]
    for node in car.find_children("*","MeshInstance3D",true,false):
        var mesh := node as MeshInstance3D
        if mesh.mesh == null: continue
        var skip := false
        var ancestor: Node = mesh
        while ancestor != car:
            if str(ancestor.name) in ["OriginalCabIntegration","SaloonArtworkV46","V49DoNotLean"] or ancestor in moving:
                skip=true
                break
            ancestor=ancestor.get_parent()
        if skip: continue
        for surface in range(mesh.mesh.get_surface_count()):
            var material := mesh.get_active_material(surface) as StandardMaterial3D
            if material == null or material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or material.albedo_texture != null: continue
            var kind := _kind(material.albedo_color)
            if kind < 0: continue
            var wear := ShaderMaterial.new()
            wear.shader=WEAR
            wear.set_shader_parameter("base_color",material.albedo_color)
            wear.set_shader_parameter("original_metallic",material.metallic)
            wear.set_shader_parameter("original_roughness",material.roughness)
            wear.set_shader_parameter("surface_kind",kind)
            wear.set_shader_parameter("mesh_to_car",car.global_transform.affine_inverse()*mesh.global_transform)
            wear.set_shader_parameter("passenger_z",Vector2(layout.passenger_z[0],layout.passenger_z[1]))
            wear.set_shader_parameter("doorway_z",Vector4(layout.door_z[0],layout.door_z[1],layout.door_z[2],layout.door_z[3]))
            wear.set_shader_parameter("car_seed",float(index+1))
            mesh.set_surface_override_material(surface,wear)
            counts[kind]+=1
    car.set_meta("v49_visuals",{"material_surfaces":counts,"glass_labels":labels})
    print("V49_MATERIALS car=%s surfaces=%s glass_labels=%d" % [car.name,counts,labels])

func _kind(colour: Color) -> int:
    var linear := colour.srgb_to_linear()
    for i in range(COLOURS.size()):
        if Vector3(colour.r,colour.g,colour.b).distance_to(COLOURS[i]) < 0.006 or Vector3(linear.r,linear.g,linear.b).distance_to(COLOURS[i]) < 0.006:
            return i
    return -1

func _glass_label(car: Node3D,root: Node3D) -> bool:
    if root.has_node("V49DoNotLean"): return true
    for node in root.find_children("*","MeshInstance3D",true,false):
        var glass := node as MeshInstance3D
        if glass.mesh == null: continue
        var transparent := false
        for surface in range(glass.mesh.get_surface_count()):
            var material := glass.get_active_material(surface) as BaseMaterial3D
            if material != null and material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
                transparent=true
        if not transparent: continue
        var box: AABB = (car.global_transform.affine_inverse()*glass.global_transform)*glass.mesh.get_aabb()
        if box.size.x > 0.1 or box.size.z < 0.15 or box.size.y < 0.3 or box.get_center().y < 1.3: continue
        var normal := Vector3(-signf(box.get_center().x),0,0)
        var center := box.get_center()
        center.x=box.position.x if normal.x < 0.0 else box.end.x
        center+=normal*0.003
        center.y=box.position.y+minf(0.17,box.size.y*0.25)
        var right := Vector3.BACK if normal.x < 0.0 else Vector3.FORWARD
        var width := minf(0.36,box.size.z*0.88)
        var up := Vector3.UP*width*160.0/1024.0*0.5
        right*=width*0.5
        var transform := root.global_transform.affine_inverse()*car.global_transform
        var points := [center-right-up,center+right-up,center+right+up,center-right+up]
        var uv := [Vector2(0,1),Vector2(1,1),Vector2(1,0),Vector2(0,0)]
        var material := StandardMaterial3D.new()
        material.albedo_texture=DO_NOT_LEAN
        material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
        material.cull_mode=BaseMaterial3D.CULL_DISABLED
        material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
        material.texture_repeat=false
        material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
        var tool := SurfaceTool.new()
        tool.begin(Mesh.PRIMITIVE_TRIANGLES)
        for i in [0,2,1,0,3,2]:
            tool.set_normal((transform.basis*normal).normalized())
            tool.set_uv(uv[i])
            tool.add_vertex(transform*points[i])
        var label := MeshInstance3D.new()
        label.name="V49DoNotLean"
        label.mesh=tool.commit()
        label.material_override=material
        label.layers=PRINT_LAYERS
        label.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        root.add_child(label)
        return true
    return false
