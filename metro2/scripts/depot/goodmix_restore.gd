extends RefCounted
## Upright prints on original framed saloon surfaces; never reuse imported UVs.
const POSTER = preload("res://assets/saloon_v49/goodmix-duo-zakhar.jpg")

static func _print(parent: Node3D,label: String,center: Vector3,size: Vector2,normal: Vector3) -> void:
    var material := StandardMaterial3D.new()
    material.albedo_texture=POSTER
    material.albedo_color=Color.WHITE
    material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
    material.cull_mode=BaseMaterial3D.CULL_DISABLED
    material.texture_repeat=false
    material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
    var right := Vector3.UP.cross(normal).normalized()
    var up := Vector3.UP
    var p := center+normal*0.006
    var points := [p-right*size.x*0.5-up*size.y*0.5,p+right*size.x*0.5-up*size.y*0.5,p+right*size.x*0.5+up*size.y*0.5,p-right*size.x*0.5+up*size.y*0.5]
    var uvs := [Vector2(0,1),Vector2(1,1),Vector2(1,0),Vector2(0,0)]
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    for index in [0,1,2,0,2,3]:
        st.set_normal(normal)
        st.set_uv(uvs[index])
        st.add_vertex(points[index])
    var mesh := MeshInstance3D.new()
    mesh.name=label
    mesh.mesh=st.commit()
    mesh.material_override=material
    mesh.layers=17
    mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent.add_child(mesh)

static func apply(train: Node3D) -> void:
    var mounts: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/saloon_v49/mounts.json"))
    for car in train.get_children():
        if not car is Node3D or str(car.name) not in ["OriginalV106Car01","OriginalV106Car04"]: continue
        if car.has_node("GoodmixUprightV54"): continue
        var holder := Node3D.new()
        holder.name="GoodmixUprightV54"
        var front := str(car.name)=="OriginalV106Car01"
        var layout: Dictionary=mounts[str(car.name)]
        var middle := (float(layout.door_z[0])+float(layout.door_z[3]))*0.5
        var found := {"end":false,"left":false,"right":false}
        for node in car.find_children("*","MeshInstance3D",true,false):
            var label := str(node.name).to_lower()
            if not label.contains("goodmix") or label.contains("frame"): continue
            var original := node as MeshInstance3D
            if original.mesh==null: continue
            var box: AABB=car.global_transform.affine_inverse()*original.global_transform*original.get_aabb()
            var center := box.get_center()
            if box.size.y<0.10: continue
            if box.size.z<0.12 and box.size.x>0.45:
                if not found.end:
                    var normal := Vector3.BACK if center.z<middle else Vector3.FORWARD
                    _print(holder,"GoodmixEndUpright",center,Vector2(box.size.x,box.size.y),normal)
                    found.end=true
                # Printed face only; retain the original physical frame.
                original.hide()
            elif box.size.x<0.12 and box.size.z>0.10:
                var key := "left" if center.x<0 else "right"
                if not found[key]:
                    _print(holder,"GoodmixSideUpright"+key,center,Vector2(box.size.z,box.size.y),Vector3.RIGHT if center.x<0 else Vector3.LEFT)
                    found[key]=true
                original.hide()
        if not found.end:
            var z := float(layout.door_z[0])-1.195+0.004 if front else float(layout.door_z[3])+1.195-0.004
            _print(holder,"GoodmixEndUpright",Vector3(0,2.44,z),Vector2(1.48,1.04),Vector3.BACK if front else Vector3.FORWARD)
        for side in [-1.0,1.0]:
            var key := "left" if side<0 else "right"
            if not found[key]:
                var z := float(layout.door_z[0])+0.65 if front else float(layout.door_z[3])-0.65
                _print(holder,"GoodmixSideUpright"+key,Vector3(side*1.193,2.48,z),Vector2(0.42,0.295),Vector3.RIGHT if side<0 else Vector3.LEFT)
        car.add_child(holder)
