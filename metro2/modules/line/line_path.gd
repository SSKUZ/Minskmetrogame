extends RefCounted
## Metres, +Z model forward basis; increasing journey progress travels toward -Z.
## Station transforms remain unchanged. Curvature starts and ends outside their portals.
const Depot = preload("res://scripts/depot/route_profile.gd")
var stations: Array[Dictionary] = []
var spans: Array[Dictionary] = []
var lower_z := -10000.0
const DEPOT_STOP := 430.0
const TRACK_2_X := -11.732

func configure_route(layout: Dictionary, info: Dictionary) -> bool:
    # Only scalar/Vector data survives station eviction. No PackedScene or Node.
    stations.clear()
    spans.clear()
    var previous_exit: float=float(layout.first_station_root_z)
    for i in range(layout.station_module_ids.size()):
        var id: String=str(layout.station_module_ids[i])
        var datum: Dictionary=layout.station_datums.get(id,{})
        if datum.is_empty():
            push_error("Streaming: missing saved route datum for "+id)
            return false
        var root_z: float=float(layout.first_station_root_z) if i==0 else previous_exit-float(layout.tunnel_lengths_m[i-1])-float(datum.entry_local[2])
        var record: Dictionary={"module_id":id,"info_id":str(info.station_ids[i]),"index":i,
            "root_z":root_z,"stop_z":root_z+float(datum.stop_local_z),
            "low":root_z+float(datum.low_local_z),"high":root_z+float(datum.high_local_z),
            "entry_local_z":float(datum.entry_local[2]),"exit_local_z":float(datum.exit_local[2]),
            "portal_shape":str(datum.get("portal_shape","round")),
            "portal_spring_y":float(datum.get("portal_spring_y",2.3)),
            "portal_crown_m":float(datum.get("portal_crown_m",0.0)),
            "low_profile":Vector2(float(datum.low_profile[0]),float(datum.low_profile[1])),
            "high_profile":Vector2(float(datum.high_profile[0]),float(datum.high_profile[1]))}
        stations.append(record)
        if i>0:
            spans.append({"high":float(stations[i-1].low),"low":float(record.high),
                "bend_m":float(layout.tunnel_bends_m[i-1]),"high_profile":stations[i-1].low_profile,
                "low_profile":record.high_profile,
                "low_portal":record,"high_portal":stations[i-1]})
        previous_exit=float(record.low)
    if stations.is_empty(): return false
    lower_z=float(stations[-1].low)-160.0
    spans.push_front({"high":Depot.PORTAL_Z,"low":float(stations[0].high),"bend_m":0.0,
        "low_profile":stations[0].high_profile,"low_portal":stations[0]})
    spans.append({"high":float(stations[-1].low),"low":lower_z,"bend_m":0.0,
        "high_profile":stations[-1].low_profile,"high_portal":stations[-1]})
    return true

func nearest_station(z: float) -> Dictionary:
    var nearest: Dictionary={}
    var separation: float=INF
    for station in stations:
        var d: float=absf(z-float(station.stop_z))
        if d<separation:
            nearest=station
            separation=d
    return nearest

func info_points() -> Array[Dictionary]:
    var points: Array[Dictionary]=[]
    for station in stations:
        points.append({"id":str(station.info_id),"position":Vector3(0.992,0.22,float(station.stop_z)),"side":-1})
    return points

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

func portal_morph(z: float) -> Dictionary:
    for span in spans:
        if z<float(span.low) or z>float(span.high): continue
        var low_weight: float=1.0-smoothstep(0.0,12.0,z-float(span.low))
        var high_weight: float=1.0-smoothstep(0.0,12.0,float(span.high)-z)
        var portal: Dictionary=span.get("low_portal",{}) if low_weight>=high_weight else span.get("high_portal",{})
        if portal.is_empty() or str(portal.portal_shape)=="round": return {}
        return {"weight":maxf(low_weight,high_weight),"shape":portal.portal_shape,
            "spring":portal.portal_spring_y,"crown":portal.portal_crown_m}
    return {}

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
