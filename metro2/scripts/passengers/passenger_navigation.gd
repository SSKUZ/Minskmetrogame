extends RefCounted
## PassengerNavigation.platformPath / crowdDetour: bounded visibility graph.
## The station adapter supplies its furniture footprints; threshold paths stay fixed.
var obstacles: Array[Rect2] = []
var platform := Rect2(-10.0,-11.0,9.1,101.0)

func clear_segment(a: Vector3,b: Vector3) -> bool:
    var from := Vector2(a.x,a.z)
    var to := Vector2(b.x,b.z)
    for shape in obstacles:
        var box := shape.grow(0.32)
        if box.has_point(from) or box.has_point(to): return false
        var corners := [box.position,Vector2(box.end.x,box.position.y),box.end,Vector2(box.position.x,box.end.y)]
        for i in range(4):
            if Geometry2D.segment_intersects_segment(from,to,corners[i],corners[(i+1)%4]) != null: return false
    return true

func route(a: Vector3,b: Vector3) -> Array[Vector3]:
    if clear_segment(a,b): return [b]
    var nodes: Array[Vector3] = [a,b]
    for shape in obstacles:
        var box := shape.grow(0.38)
        for p in [box.position,Vector2(box.end.x,box.position.y),box.end,Vector2(box.position.x,box.end.y)]:
            if platform.has_point(p): nodes.append(Vector3(p.x,a.y,p.y))
    var cost: Array[float] = []
    var previous: Array[int] = []
    var visited: Array[bool] = []
    for i in nodes.size():
        cost.append(INF); previous.append(-1); visited.append(false)
    cost[0] = 0.0
    for iteration in nodes.size():
        var best := -1
        for i in nodes.size():
            if not visited[i] and (best<0 or cost[i]<cost[best]): best=i
        if best<0 or cost[best]==INF: break
        if best==1: break
        visited[best]=true
        for i in nodes.size():
            if visited[i] or not clear_segment(nodes[best],nodes[i]): continue
            var distance := cost[best]+nodes[best].distance_to(nodes[i])
            if distance<cost[i]: cost[i]=distance;previous[i]=best
    var result: Array[Vector3] = []
    if cost[1]==INF: return result
    var index := 1
    while index!=0:
        result.push_front(nodes[index]);index=previous[index]
    return result
