extends RefCounted
## Metres, +Z model forward basis; increasing journey progress travels toward -Z.
## Station transforms remain unchanged. Curvature starts and ends outside their portals.
const Depot = preload("res://scripts/depot/route_profile.gd")
var stations: Array[Dictionary] = []
var spans: Array[Dictionary] = []
var lower_z := -10000.0
const DEPOT_STOP := 430.0
const TRACK_2_X := -11.732

func position_at(z: float, track_x: float = Depot.CENTER_X) -> Vector3:
    return Vector3(track_x + lateral(z), Depot.height(z), z)

func lateral(z: float) -> float:
    for span in spans:
        if z > float(span.high) or z < float(span.low): continue
        var u := (z-float(span.low))/(float(span.high)-float(span.low))
        # Quartic, with zero displacement AND tangent at both portal joins.
        return float(span.bend_m)*16.0*u*u*(1.0-u)*(1.0-u)
    return 0.0

func cross_section_at(z: float) -> Vector2:
    var standard := Vector2(3.15,7.0)
    for span in spans:
        if z<float(span.low) or z>float(span.high): continue
        var from_low := smoothstep(0.0,12.0,z-float(span.low))
        var from_high := smoothstep(0.0,12.0,float(span.high)-z)
        var low: Vector2=span.get("low_profile",standard)
        var high: Vector2=span.get("high_profile",standard)
        return low.lerp(standard,from_low).min(high.lerp(standard,from_high))
    return standard

func frame_at(z: float, track_x: float = Depot.CENTER_X) -> Transform3D:
    var tangent := (position_at(z+0.05,track_x)-position_at(z-0.05,track_x)).normalized()
    var right := Vector3.UP.cross(tangent).normalized()
    return Transform3D(Basis(right,tangent.cross(right).normalized(),tangent), position_at(z,track_x))

func in_station(z: float, margin: float = 0.0) -> bool:
    for s in stations:
        if z >= float(s.low)-margin and z <= float(s.high)+margin: return true
    return false

func tunnel_pieces(z0: float, z1: float) -> Array[Vector2]:
    var pieces: Array[Vector2] = [Vector2(maxf(z0,lower_z),minf(z1,Depot.PORTAL_Z))]
    for station in stations:
        var next: Array[Vector2] = []
        for piece in pieces:
            if float(station.high) <= piece.x or float(station.low) >= piece.y:
                next.append(piece)
            else:
                if float(station.low)>piece.x: next.append(Vector2(piece.x,float(station.low)))
                if float(station.high)<piece.y: next.append(Vector2(float(station.high),piece.y))
        pieces=next
    return pieces.filter(func(p: Vector2) -> bool: return p.y-p.x>0.001)
