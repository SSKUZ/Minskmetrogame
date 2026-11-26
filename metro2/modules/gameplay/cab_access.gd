extends RefCounted
## Marker-only adapter. No mesh reads, cutting, generated doors or animations.
const DATA := "res://modules/gameplay/cab_access_points.json"
var error_message:=""

func prepare_points(consist: Node3D) -> Array[Dictionary]:
    var result: Array[Dictionary]=[]
    var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(DATA))
    if not parsed is Dictionary:
        error_message="Не прочитаны точки входа V106"
        return result
    var data: Dictionary=parsed
    for definition in data.cars:
        var number: int=int(definition.number)
        var car:=consist.get_node_or_null("OriginalV106Car%02d" % number) as Node3D
        if car==null:
            error_message="Не найден головной вагон №"+str(number)
            return []
        if car.has_meta("metro_instant_cab_points"):
            result.append(car.get_meta("metro_instant_cab_points"))
            continue
        var authored: Node3D=car if str(car.name)==str(definition.authored_root) else car.find_child(str(definition.authored_root),true,false) as Node3D
        # Imported GLTF may use its authored root as the scene root; the train
        # renames only that root to OriginalV106CarXX. Its own frame is then local.
        if authored==null and car.get_meta("hasCab",false): authored=car
        if authored==null:
            # Exact root-scene names are also retained as source scene resources.
            # Car 1/4 root transforms are already on car when no wrapper exists.
            var scene: String=car.scene_file_path
            if (number==1 and scene.contains("v106_car01")) or (number==4 and scene.contains("v106_car_04")): authored=car
        if authored==null:
            error_message="Не найдена исходная система координат кабины №"+str(number)
            return []
        var frame: Transform3D=car.global_transform.affine_inverse()*authored.global_transform
        var root:=Node3D.new()
        root.name="InstantCabAccessPoints"
        car.add_child(root)
        var points: Dictionary={}
        for name in data.markers:
            var marker:=Marker3D.new()
            marker.name=str(name)
            marker.position=frame*_v(data.markers[name])
            marker.set_meta("functional_point",{"kind":str(name),"car":number,"units":"metres","source":DATA})
            root.add_child(marker)
            points[name]=marker
        var inside: Array[Vector3]=[]
        var outside: Array[Vector3]=[]
        for value in data.interior_alternatives: inside.append(frame*_v(value))
        for value in data.exterior_alternatives: outside.append(frame*_v(value))
        var zone: AABB=frame*AABB(_v(data.cab_zone.minimum),_v(data.cab_zone.size))
        var record: Dictionary={"car":car,"number":number,"entry":points.CabEntryPoint,
            "interior":points.CabInteriorSpawn,"exterior":points.CabExteriorSpawn,
            "interior_alternatives":inside,"exterior_alternatives":outside,
            "zone":zone,"rules":data.interaction,"driving_workplace":bool(definition.driving_workplace)}
        root.set_meta("portable_frame",frame)
        root.set_meta("source",DATA)
        car.set_meta("metro_instant_cab_points",record)
        result.append(record)
    return result

func cancel() -> void:
    pass

func _v(values: Array) -> Vector3:
    return Vector3(float(values[0]),float(values[1]),float(values[2]))
