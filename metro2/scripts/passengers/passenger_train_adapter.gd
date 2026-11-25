extends RefCounted
## PassengerLayout: original GLB geometry -> reusable car/door/place contract.
var doors: Array[Dictionary] = []
var places: Array[Dictionary] = []
var cars: Array[Node3D] = []
var controller: Node
var platform_selected := false
var platform_area := Rect2()
var platform_height := 1.1805

func configure(train: Node3D,door_controller: Node) -> void:
    controller=door_controller
    doors.clear();places.clear();cars.clear()
    for car in train.get_children():
        if not str(car.name).begins_with("OriginalV106Car"): continue
        cars.append(car)
        var seams: Dictionary = {}
        for leaf in controller.leaves:
            var moving: Node3D = leaf.parts[0].node
            if not car.is_ancestor_of(moving): continue
            var center: Vector3 = leaf.center
            var seam: float = leaf.seam
            var side: int=-1 if center.x<0.0 else 1
            var key := "%d:%d" % [side,roundi(seam*100)]
            if seams.has(key): continue
            seams[key]=true
            var marker := Marker3D.new()
            marker.name="PassengerDoor%02d" % doors.size()
            car.add_child(marker)
            marker.position=Vector3(center.x,1.033,seam)
            doors.append({"id":doors.size(),"car":car,"marker":marker,"enter":[],"exit":[],"active":null,"side":side,"available":side<0})
        # Upholstery is one merged mesh spanning both benches in the source
        # GLBs. Read anchors extracted from its actual horizontal cushion faces.
        var catalog: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://modules/passengers/v106_seats.json"))
        var original: Dictionary=catalog.cars.get(str(car.name),{})
        for seat in original.get("seats",[]):
            var xyz: Array=seat.position
            var p:=Vector3(float(xyz[0]),float(xyz[1]),float(xyz[2]))
            if not clear_door(car,p,0.80):continue
            places.append({"car":car,"position":p,"height":float(seat.height),"seated":true,"used":false,"heading":float(seat.heading)})
        var car_doors: Array = doors.filter(func(d):return d.car==car and int(d.side)<0)
        car_doors.sort_custom(func(a,b):return a.marker.position.z<b.marker.position.z)
        for i in range(car_doors.size()-1):
            var z: float=(car_doors[i].marker.position.z+car_doors[i+1].marker.position.z)*0.5
            for side in [-1.0,1.0]:
                places.append({"car":car,"position":Vector3(side*0.42,1.033,z),"height":1.033,"seated":false,"used":false,"heading":0.0,"grip":_handrail_grip(car,Vector3(side*0.42,1.033,z))})

func clear_door(car: Node3D,p: Vector3,margin: float) -> bool:
    for d in doors:
        if d.car==car and absf(p.z-d.marker.position.z)<margin: return false
    return true

func select_platform(area: Rect2, height: float, navigation: RefCounted=null) -> int:
    platform_selected=true
    platform_area=area
    platform_height=height
    var count := 0
    for d in doors:
        var point: Vector3=landing(d)
        var along: Vector3=d.car.global_basis.z.normalized()*0.70
        d.available=absf(d.marker.global_position.y-height)<0.6 and area.has_point(Vector2(point.x+along.x,point.z+along.z)) and area.has_point(Vector2(point.x-along.x,point.z-along.z))
        if d.available and navigation!=null:
            d.available=navigation.clear_segment(point,landing(d,0.80))
        if d.available: count+=1
    return count

func outward(d: Dictionary) -> Vector3:
    var axis: Vector3=d.car.global_basis.x*float(d.side)
    axis.y=0.0
    return axis.normalized()

func landing(d: Dictionary, distance: float=1.15) -> Vector3:
    var point: Vector3=d.marker.global_position+outward(d)*distance
    point.y=platform_height
    return point

func usable(d: Dictionary, require_open: bool=true) -> bool:
    if not bool(d.get("available",true)): return false
    return not require_open or (is_instance_valid(controller) and float(controller.side_open[int(d.get("side",-1))])>=0.99)

func door(id: int) -> Dictionary:
    return doors[id] if id>=0 and id<doors.size() else {}

func reserve(car: Node3D,near_z: float,seated: bool) -> Dictionary:
    for preference in [seated,not seated]:
        var candidates: Array=[]
        for place in places:
            if place.car!=car or place.used or bool(place.seated)!=preference: continue
            var blocked := false
            for other in places:
                if other.car!=car or not other.used: continue
                if preference:
                    blocked=not other.seated and signf(other.position.x)==signf(place.position.x) and absf(other.position.z-place.position.z)<0.7
                else:
                    blocked=(not other.seated and absf(other.position.z-place.position.z)<0.9) or (other.seated and signf(other.position.x)==signf(place.position.x) and absf(other.position.z-place.position.z)<0.7)
                if blocked: break
            if not blocked: candidates.append(place)
        candidates.sort_custom(func(a,b):return absf(a.position.z-near_z)<absf(b.position.z-near_z))
        if not candidates.is_empty():
            candidates[0].used=true
            return candidates[0]
    return {}

func release(slot: Dictionary) -> void:
    if not slot.is_empty(): slot.used=false

func aisle_bounds(car: Node3D) -> Rect2:
    var lo:=INF
    var hi:=-INF
    for d in doors:
        if d.car==car:
            lo=minf(lo,d.marker.position.z);hi=maxf(hi,d.marker.position.z)
    for p in places:
        if p.car==car:
            lo=minf(lo,p.position.z);hi=maxf(hi,p.position.z)
    return Rect2(-0.43,lo-0.3,0.86,hi-lo+0.6)

func _handrail_grip(car: Node3D,place: Vector3) -> Vector3:
    var nearest := Vector3(place.x,2.20,place.z)
    var score := INF
    for node in car.find_children("*","MeshInstance3D",true,false):
        var mesh := node as MeshInstance3D
        if mesh.mesh==null: continue
        var box: AABB=car.global_transform.affine_inverse()*mesh.global_transform*mesh.get_aabb()
        var center := box.get_center()
        if absf(center.x)>1.25 or center.y<1.7 or center.y>2.9: continue
        var vertical := box.size.y>0.65 and box.size.x<0.16 and box.size.z<0.16
        var longitudinal := box.size.z>0.8 and box.size.x<0.16 and box.size.y<0.16
        if not vertical and not longitudinal: continue
        var target := Vector3(center.x,clampf(2.20,box.position.y,box.end.y),clampf(place.z,box.position.z,box.end.z))
        var distance := Vector3(place.x,2.20,place.z).distance_squared_to(target)
        if distance<score: score=distance;nearest=target
    return nearest
