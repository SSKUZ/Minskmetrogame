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
        # Original seat cushions define actual seat heights and positions.
        for node in car.find_children("*","MeshInstance3D",true,false):
            var mesh := node as MeshInstance3D
            if mesh.mesh==null: continue
            var box: AABB=car.global_transform.affine_inverse()*mesh.global_transform*mesh.get_aabb()
            var c := box.get_center()
            if absf(c.x)<0.65 or absf(c.x)>1.2: continue
            if box.end.y<1.38 or box.end.y>1.70 or box.size.y>0.24 or box.size.y<0.025: continue
            if box.size.x<0.25 or box.size.x>0.85 or box.size.z<0.35: continue
            var n := maxi(1,int(floor(box.size.z/0.48)))
            for k in n:
                var p := Vector3(c.x,1.033,box.position.z+(k+0.5)*box.size.z/n)
                if not clear_door(car,p,0.92): continue
                if places.any(func(s):return s.car==car and (s.position as Vector3).distance_to(p)<0.40): continue
                places.append({"car":car,"position":p,"height":box.end.y,"seated":true,"used":false,"heading":-PI/2 if c.x>0 else PI/2})
        var car_doors: Array = doors.filter(func(d):return d.car==car)
        car_doors.sort_custom(func(a,b):return a.marker.position.z<b.marker.position.z)
        for i in range(car_doors.size()-1):
            var z: float=(car_doors[i].marker.position.z+car_doors[i+1].marker.position.z)*0.5
            for side in [-1.0,1.0]:
                places.append({"car":car,"position":Vector3(side*0.48,1.033,z),"height":1.033,"seated":false,"used":false,"heading":0.0})

func clear_door(car: Node3D,p: Vector3,margin: float) -> bool:
    for d in doors:
        if d.car==car and absf(p.z-d.marker.position.z)<margin: return false
    return true

func reserve(car: Node3D,near_z: float,seated: bool) -> Dictionary:
    var candidates := places.filter(func(p):return p.car==car and not p.used and p.seated==seated)
    candidates.sort_custom(func(a,b):return absf(a.position.z-near_z)<absf(b.position.z-near_z))
    if candidates.is_empty() and seated: return reserve(car,near_z,false)
    if candidates.is_empty(): return {}
    candidates[0].used=true
    return candidates[0]

func release(slot: Dictionary) -> void:
    if not slot.is_empty(): slot.used=false
