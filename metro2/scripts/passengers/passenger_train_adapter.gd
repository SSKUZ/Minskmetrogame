extends RefCounted
## PassengerLayout: original GLB geometry -> reusable car/door/place contract.
var doors: Array[Dictionary] = []
var places: Array[Dictionary] = []
var cars: Array[Node3D] = []

func configure(train: Node3D,controller: Node) -> void:
    doors.clear();places.clear();cars.clear()
    for car in train.get_children():
        if not str(car.name).begins_with("OriginalV106Car"): continue
        cars.append(car)
        var seams: Dictionary = {}
        for leaf in controller.leaves:
            var moving: Node3D = leaf.parts[0].node
            if not car.is_ancestor_of(moving): continue
            var center: Vector3 = leaf.center
            if center.x>=0: continue
            var seam: float = leaf.seam
            var key := roundi(seam*100)
            if seams.has(key): continue
            seams[key]=true
            var marker := Marker3D.new()
            marker.name="PassengerDoor%02d" % doors.size()
            car.add_child(marker)
            marker.position=Vector3(center.x,1.033,seam)
            doors.append({"id":doors.size(),"car":car,"marker":marker,"enter":[],"exit":[],"active":null})
        # Upholstery is one merged mesh spanning both benches in the source
        # GLBs. Read anchors extracted from its actual horizontal cushion faces.
        var catalog: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://modules/passengers/v106_seats.json"))
        var original: Dictionary=catalog.cars.get(str(car.name),{})
        for seat in original.get("seats",[]):
            var xyz: Array=seat.position
            var p:=Vector3(float(xyz[0]),float(xyz[1]),float(xyz[2]))
            if not clear_door(car,p,0.80):continue
            places.append({"car":car,"position":p,"height":float(seat.height),"seated":true,"used":false,"heading":float(seat.heading)})
        var car_doors: Array = doors.filter(func(d):return d.car==car)
        car_doors.sort_custom(func(a,b):return a.marker.position.z<b.marker.position.z)
        for i in range(car_doors.size()-1):
            var z: float=(car_doors[i].marker.position.z+car_doors[i+1].marker.position.z)*0.5
            for side in [-1.0,1.0]:
                places.append({"car":car,"position":Vector3(side*0.42,1.033,z),"height":1.033,"seated":false,"used":false,"heading":0.0})

func clear_door(car: Node3D,p: Vector3,margin: float) -> bool:
    for d in doors:
        if d.car==car and absf(p.z-d.marker.position.z)<margin: return false
    return true

func reserve(car: Node3D,near_z: float,seated: bool) -> Dictionary:
    var candidates := places.filter(func(p):return p.car==car and not p.used and p.seated==seated)
    if seated:
        candidates=candidates.filter(func(p):return not places.any(func(other):return other.car==car and other.used and not other.seated and signf(other.position.x)==signf(p.position.x) and absf(other.position.z-p.position.z)<0.7))
    else:
        # Keep the opposite aisle lane and approaches to occupied seats clear.
        candidates=candidates.filter(func(p):return not places.any(func(other):return other.car==car and other.used and ((not other.seated and absf(other.position.z-p.position.z)<0.9) or (other.seated and signf(other.position.x)==signf(p.position.x) and absf(other.position.z-p.position.z)<0.7))))
    candidates.sort_custom(func(a,b):return absf(a.position.z-near_z)<absf(b.position.z-near_z))
    if candidates.is_empty() and seated: return reserve(car,near_z,false)
    if candidates.is_empty(): return {}
    candidates[0].used=true
    return candidates[0]

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
