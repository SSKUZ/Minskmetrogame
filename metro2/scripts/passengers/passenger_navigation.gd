extends RefCounted
## Static furniture and dynamic body discs share one bounded visibility graph.
var obstacles: Array[Rect2]=[]
var platform:=Rect2(-10.0,-11.0,9.1,101.0)

static func distance_to_segment(p: Vector2,a: Vector2,b: Vector2) -> float:
    var delta:=b-a
    var t:=clampf((p-a).dot(delta)/maxf(delta.length_squared(),0.000001),0,1)
    return p.distance_to(a+delta*t)

func clear_segment(a: Vector3,b: Vector3,people: Array=[],use_static: bool=true) -> bool:
    var start:=Vector2(a.x,a.z)
    var finish:=Vector2(b.x,b.z)
    if use_static:
        for shape in obstacles:
            var box:=shape.grow(0.32)
            if box.has_point(start) or box.has_point(finish):return false
            var corners: Array[Vector2]=[box.position,Vector2(box.end.x,box.position.y),box.end,Vector2(box.position.x,box.end.y)]
            for i in range(4):
                if Geometry2D.segment_intersects_segment(start,finish,corners[i],corners[(i+1)%4])!=null:return false
    for person in people:
        var center:=Vector2(person.position.x,person.position.z)
        var clearance: float=person.clearance
        # An agent already close to someone may back away without teleporting.
        if start.distance_to(center)<clearance and (finish-start).dot(start-center)>=0:continue
        if distance_to_segment(center,start,finish)<clearance:return false
    return true

func route(a: Vector3,b: Vector3,people: Array=[],region: Rect2=Rect2(),use_static: bool=true) -> Array[Vector3]:
    if clear_segment(a,b,people,use_static):return [b]
    var bounds:=platform if region.size==Vector2.ZERO else region
    var nodes: Array[Vector3]=[a,b]
    if use_static:
        var corridor:=Rect2(Vector2(a.x,a.z),Vector2.ZERO).expand(Vector2(b.x,b.z)).grow(1.6)
        for shape in obstacles:
            if not shape.intersects(corridor):continue
            var box:=shape.grow(0.38)
            for point in [box.position,Vector2(box.end.x,box.position.y),box.end,Vector2(box.position.x,box.end.y)]:
                if bounds.has_point(point):nodes.append(Vector3(point.x,a.y,point.y))
    var nearby: Array=people.filter(func(person):return distance_to_segment(Vector2(person.position.x,person.position.z),Vector2(a.x,a.z),Vector2(b.x,b.z))<float(person.clearance)+0.25)
    nearby.sort_custom(func(left,right):return a.distance_squared_to(left.position)<a.distance_squared_to(right.position))
    for person in nearby.slice(0,6):
        var center: Vector3=person.position
        var radius: float=float(person.clearance)/cos(PI/8.0)+0.035
        for i in range(8):
            var angle:=float(i)*TAU/8.0
            var point:=Vector3(center.x+cos(angle)*radius,a.y,center.z+sin(angle)*radius)
            if bounds.has_point(Vector2(point.x,point.z)):nodes.append(point)
    var costs: Array[float]=[]
    var previous: Array[int]=[]
    var visited: Array[bool]=[]
    for i in nodes.size():costs.append(INF);previous.append(-1);visited.append(false)
    costs[0]=0.0
    for iteration in nodes.size():
        var best: int=-1
        for i in nodes.size():
            if not visited[i] and (best<0 or costs[i]<costs[best]):best=i
        if best<0 or costs[best]==INF:break
        if best==1:break
        visited[best]=true
        for i in nodes.size():
            if visited[i] or not clear_segment(nodes[best],nodes[i],people,use_static):continue
            var cost:=costs[best]+nodes[best].distance_to(nodes[i])
            if cost<costs[i]:costs[i]=cost;previous[i]=best
    var result: Array[Vector3]=[]
    if costs[1]==INF:return result
    var index:=1
    while index!=0:result.push_front(nodes[index]);index=previous[index]
    return result
