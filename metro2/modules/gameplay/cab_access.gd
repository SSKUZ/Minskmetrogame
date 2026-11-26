extends RefCounted
## Marker-only adapter. No mesh reads, cutting, generated doors or animations.
const DATA := "res://modules/gameplay/cab_access_points.json"
var error_message:=""

func prepare_points(consist: Node3D) -> Array[Dictionary]:
    var result: Array[Dictionary]=[]
    error_message=""
    if not is_instance_valid(consist):
        error_message="Не создан состав V106 для точек доступа"
        return result
    var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(DATA))
    if not parsed is Dictionary:
        error_message="Не прочитаны точки входа V106"
        return result
    var data: Dictionary=parsed
    if not _valid_data(data):
        error_message="Некорректные данные точек входа V106: "+DATA
        return result
    # Resolve only authored scene roots. Never walk meshes to discover a door.
    var frames: Array[Dictionary]=[]
    for definition in data.cars:
        var number: int=int(definition.number)
        var car:=consist.get_node_or_null("OriginalV106Car%02d" % number) as Node3D
        if car==null:
            error_message="Не найден головной вагон №"+str(number)
            return []
        var authored: Node3D=car if str(car.name)==str(definition.authored_root) else car.get_node_or_null(NodePath(str(definition.authored_root))) as Node3D
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
        frames.append({"car":car,"number":number,"authored":authored,"definition":definition})
    # Validate the whole request before adding any markers; retry is idempotent.
    for item in frames:
        var car: Node3D=item.car
        var number: int=int(item.number)
        var definition: Dictionary=item.definition
        if car.has_meta("metro_instant_cab_points"):
            var cached: Dictionary=car.get_meta("metro_instant_cab_points")
            if is_instance_valid(cached.get("entry")) and is_instance_valid(cached.get("interior")) and is_instance_valid(cached.get("exterior")):
                result.append(cached)
                continue
            var previous:=car.get_node_or_null("InstantCabAccessPoints")
            if previous!=null:
                car.remove_child(previous)
                previous.queue_free()
            car.remove_meta("metro_instant_cab_points")
        var authored: Node3D=item.authored
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

func _valid_vector(value: Variant) -> bool:
    if not value is Array or value.size()!=3: return false
    for coordinate in value:
        if not (coordinate is float or coordinate is int) or not is_finite(float(coordinate)): return false
    return true

func _valid_data(data: Dictionary) -> bool:
    for key in ["cars","markers","interior_alternatives","exterior_alternatives","cab_zone","interaction"]:
        if not data.has(key): return false
    if not data.cars is Array or data.cars.size()!=2: return false
    if not data.markers is Dictionary or not data.cab_zone is Dictionary or not data.interaction is Dictionary: return false
    var numbers: Array[int]=[]
    for definition in data.cars:
        if not definition is Dictionary: return false
        if not definition.has_all(["number","authored_root","driving_workplace"]): return false
        if not (definition.number is int or definition.number is float): return false
        var number: int=int(definition.number)
        if number not in [1,4] or number in numbers: return false
        numbers.append(number)
        if not definition.authored_root is String or not str(definition.authored_root).is_valid_filename(): return false
    for name in ["CabEntryPoint","CabInteriorSpawn","CabExteriorSpawn"]:
        if not _valid_vector(data.markers.get(name)): return false
    if data.markers.size()!=3: return false
    for key in ["interior_alternatives","exterior_alternatives"]:
        if not data[key] is Array: return false
        for point in data[key]:
            if not _valid_vector(point): return false
    if not _valid_vector(data.cab_zone.get("minimum")) or not _valid_vector(data.cab_zone.get("size")): return false
    for extent in data.cab_zone.size:
        if float(extent)<=0.0: return false
    if not data.interaction.has_all(["horizontal_range","vertical_range","max_speed","heading_radians","preserve_world_view","require_existing_collision"]): return false
    for key in ["horizontal_range","vertical_range","max_speed","heading_radians"]:
        var value: Variant=data.interaction[key]
        if not (value is float or value is int) or not is_finite(float(value)): return false
    return float(data.interaction.horizontal_range)>0.0 and float(data.interaction.vertical_range)>0.0 and float(data.interaction.max_speed)>=0.0
