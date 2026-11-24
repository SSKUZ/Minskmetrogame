extends RefCounted
const Agent = preload("res://scripts/passengers/passenger_agent.gd")
const LIBRARY := "res://assets/passengers/manifest.json"
# Explicit original resources let the existing pack planner retain every model.
const MODELS := ["res://assets/passengers/boy-low.glb","res://assets/passengers/elder-man-low.glb","res://assets/passengers/elder-woman-low.glb","res://assets/passengers/girl-low.glb","res://assets/passengers/man-casual-low.glb","res://assets/passengers/man-hoodie-low.glb","res://assets/passengers/man-jacket-low.glb","res://assets/passengers/man-shirt-low.glb","res://assets/passengers/woman-coat-low.glb","res://assets/passengers/woman-longhair-low.glb","res://assets/passengers/woman-skirt-low.glb","res://assets/passengers/woman-suit-low.glb"]
var cache: Dictionary = {}

func spawn(parent: Node3D,count: int,navigation: RefCounted,available_doors: Array) -> Array:
    var result: Array=[]
    for i in count: result.append(spawn_one(parent,i,count,navigation,available_doors))
    finish_groups(result)
    return result

var _variants: Array = []

func spawn_one(parent: Node3D,i: int,count: int,navigation: RefCounted,available_doors: Array) -> Node3D:
    if _variants.is_empty():
        var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(LIBRARY))
        _variants=manifest.models.filter(func(m):return str(m.file).ends_with("-low.glb"))
    var variants: Array=_variants
    var filename: String=variants[i%variants.size()].file
    if not cache.has(filename): cache[filename]=load("res:/" + "/assets/passengers/"+filename)
    var a=Agent.new()
    a.name="Passenger%02d"%i
    parent.add_child(a)
    a.setup(cache[filename],i)
    # Adjacent companions share a door and remain together in one car.
    a.group_id=int(i/2) if i%6<2 else -1
    var z := 3.0+float(i)*73.0/maxf(1,count-1)
    var point := Vector3(-2.0-float(i%2)*0.7,1.1805,z)
    while navigation.obstacles.any(func(o):return o.grow(0.35).has_point(Vector2(point.x,point.z))): point.x-=0.4
    a.position=point
    return a

func finish_groups(result: Array) -> void:
    for a in result:
        if a.group_id<0: continue
        var companions: Array=result.filter(func(b):return b.group_id==a.group_id)
        var slowest: float=a.walk_speed
        for b in companions: slowest=minf(slowest,b.walk_speed)
        for b in companions: b.walk_speed=slowest
