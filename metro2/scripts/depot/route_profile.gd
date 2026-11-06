extends RefCounted
const CENTER_X := 0.992
const PORTAL_Z := 96.0
const RAMP_TOP_Z := 300.0
const START_Z := 430.0
const HEIGHT := 6.0
const GAUGE := 1.520
const RAIL_CENTER := (GAUGE+0.095)*0.5

static func height(z: float) -> float:
    var u := clampf((z-PORTAL_Z)/(RAMP_TOP_Z-PORTAL_Z),0.0,1.0)
    return HEIGHT*u*u*(3.0-2.0*u)

static func grade(z: float) -> float:
    var u := clampf((z-PORTAL_Z)/(RAMP_TOP_Z-PORTAL_Z),0.0,1.0)
    return HEIGHT*6.0*u*(1.0-u)/(RAMP_TOP_Z-PORTAL_Z)

static func ground(x: float,z: float) -> float:
    var base := 8.0-height(z)*0.4
    var far := smoothstep(80.0,240.0,absf(x-CENTER_X))
    return base+far*(sin(x*0.017+z*0.006)*1.1+sin(z*0.024-x*0.009)*0.6)

static func pose(x: float,z: float,offset_y: float = 0.0) -> Transform3D:
    return Transform3D(Basis(Vector3.RIGHT,-atan(grade(z))),Vector3(CENTER_X+x,height(z)+offset_y,z))
