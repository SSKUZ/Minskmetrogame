extends "res://scripts/v106_four_cars_preview.gd"
const Route = preload("res://scripts/depot/route_profile.gd")
const TunnelAdapter = preload("res://scripts/depot/depot_tunnel.gd")
const STATION_Z := -1116.112
const STATION_ENTRY_Z := -1024.0
const STATION_EXIT_Z := -1136.0
var _pose_cache: Dictionary = {}
var _sun: DirectionalLight3D
var _sky: ProceduralSkyMaterial

func _ready() -> void:
    distance = Route.START_Z
    route_end_distance = STATION_Z + 9.603
    tunnel_script = TunnelAdapter
    super._ready()
    # Use the original Station Base alone: no preview train, camera or environment.
    attach_station(preload("res://scenes/depot/route_station_v41.tscn"),
        Transform3D(Basis.IDENTITY,Vector3(0,0,STATION_Z)),route_end_distance)
    _diagnostics_enabled = false
    for node in get_children():
        if node is DirectionalLight3D:
            _sun = node as DirectionalLight3D
            break
    if _sun != null:
        _sun.rotation_degrees = Vector3(-47,-38,0)
        _sun.light_color = Color(1.0,0.97,0.88)
        _sun.light_energy = 1.05
        _sun.shadow_enabled = true
        _sun.shadow_bias = 0.07
        _sun.shadow_normal_bias = 0.7
        _sun.directional_shadow_max_distance = 180.0
    _sky = ProceduralSkyMaterial.new()
    _sky.sky_top_color = Color(0.22,0.38,0.54)
    _sky.sky_horizon_color = Color(0.72,0.78,0.80)
    _sky.ground_horizon_color = Color(0.65,0.69,0.65)
    _sky.ground_bottom_color = Color(0.30,0.34,0.31)
    var sky := Sky.new()
    sky.sky_material = _sky
    sky.radiance_size = Sky.RADIANCE_SIZE_64
    _environment.sky = sky
    _environment.background_mode = Environment.BG_SKY
    _environment.ambient_light_color = Color(0.74,0.79,0.82)
    orbit_yaw = PI-0.05
    orbit_pitch = 0.08
    orbit_radius = 42.0
    _update_camera()
    _update_atmosphere()
    if OS.has_feature("web"):
        var near_station = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('start') === 'station'",true)
        if near_station == true:
            call_deferred("_start_near_station")

func _start_near_station() -> void:
    # Measure from the original head-car nose to the leading platform edge.
    var lead := train.get_node("OriginalV106Car01") as Node3D
    var bounds: AABB = _pose_cache[lead]
    distance = STATION_ENTRY_Z + 50.0 - bounds.position.z
    train.position.z = distance
    speed = 0.0
    _configure_tunnel()
    _set_camera_mode("cabin")
    _update_atmosphere()

func _place_consist() -> void:
    if not is_instance_valid(train): return
    for node in train.get_children():
        if not node is Node3D: continue
        var car := node as Node3D
        if str(car.name).begins_with("OriginalV106Car"):
            if not _pose_cache.has(car): _pose_cache[car] = _get_model_bounds(car)
            var bounds: AABB = _pose_cache[car]
            var center_z := train.global_position.z+car.position.z+bounds.get_center().z
            var wheelbase := bounds.size.z*0.33
            var front_y := Route.height(center_z-wheelbase)
            var back_y := Route.height(center_z+wheelbase)
            car.position.y = (front_y+back_y)*0.5
            car.rotation.x = -atan2(back_y-front_y,wheelbase*2.0)
        elif car.get_child_count() > 0 and car.get_child(0) is MeshInstance3D:
            # Existing visual couplers follow the same grade; their meshes stay intact.
            if not car.has_meta("route_coupler_z"):
                var z := (car.get_child(0) as Node3D).position.z
                car.set_meta("route_coupler_z",z)
                car.position.z = z
                for child in car.get_children():
                    if child is Node3D: (child as Node3D).position.z -= z
            var z := float(car.get_meta("route_coupler_z"))
            car.position.y = Route.height(train.global_position.z+z)
            car.rotation.x = -atan(Route.grade(train.global_position.z+z))

func _configure_tunnel() -> void:
    _place_consist()
    super._configure_tunnel()

func _physics_process(delta: float) -> void:
    super._physics_process(delta)
    if distance > 442.0:
        distance = 442.0
        speed = 0.0
        train.position.z = distance
        _update_camera()
    _update_atmosphere()
    if hud != null:
        var phase := "ЭЛЕКТРОДЕПО" if distance > 300.0 else "ПОДХОД К ПОРТАЛУ" if distance > 96.0 else "МАЛИНОВКА" if distance < STATION_ENTRY_Z + 10.0 else "ТОННЕЛЬ"
        hud.text = "%s | 4 ВАГОНА | %.0f км/ч | %.0f м от депо | %s" % [phase,speed*3.6,Route.START_Z-distance,camera_mode]

func _update_camera() -> void:
    if not is_instance_valid(camera) or not is_instance_valid(train): return
    _place_consist()
    var cars: Array[Node3D] = []
    for node in train.get_children():
        if node is Node3D and str(node.name).begins_with("OriginalV106Car"): cars.append(node as Node3D)
    if cars.is_empty(): return
    var selected := cars[clampi(_focused_car,0,cars.size()-1)]
    if camera_mode == "external":
        var bounds: AABB = _pose_cache[selected]
        var focus := selected.to_global(bounds.get_center())+camera_pan
        var offset := Vector3(sin(orbit_yaw)*cos(orbit_pitch),sin(orbit_pitch),cos(orbit_yaw)*cos(orbit_pitch))*orbit_radius
        var desired := focus+offset
        if is_instance_valid(_tunnel): desired = _tunnel.call("constrain_camera",desired)
        camera.global_position = desired
        if desired.distance_squared_to(focus) > 0.001: camera.look_at(focus,Vector3.UP)
    elif camera_mode == "salon":
        camera.global_position = selected.to_global(Vector3(0,2.35,-2)+camera_pan)
        camera.global_basis = selected.global_basis*Basis.from_euler(Vector3(-orbit_pitch,orbit_yaw,0))
    else:
        super._update_camera()
        camera.global_basis = cars[0].global_basis*Basis.from_euler(Vector3(-orbit_pitch,orbit_yaw,0))

func _set_camera_mode(mode: String) -> void:
    super._set_camera_mode(mode)
    if mode == "external" and distance > Route.PORTAL_Z:
        orbit_yaw = PI-0.05
        orbit_pitch = 0.10
        orbit_radius = 25.0
        _update_camera()

func _update_atmosphere() -> void:
    if _environment == null or not is_instance_valid(camera): return
    # Sun is occluded by the shed/retaining walls. The remaining ambient and
    # atmospheric depth fade over the final 24 m in the shaded portal approach.
    var daylight := smoothstep(96.0,120.0,camera.global_position.z)
    # Daytime sky must not shine through the open end of a pooled tunnel.
    # Fade it with the existing portal transition; underground, use a dark
    # background. A future station supplies actual geometry and local lights.
    _environment.background_energy_multiplier = daylight
    _environment.background_color = Color(0.002,0.003,0.004)
    _environment.background_mode = Environment.BG_COLOR if daylight <= 0.0 else Environment.BG_SKY
    _environment.ambient_light_energy = lerpf(0.085,0.46,daylight)
    _environment.ambient_light_color = Color(0.50,0.49,0.46).lerp(Color(0.74,0.79,0.82),daylight)
    _environment.fog_depth_begin = lerpf(60.0,290.0,daylight)
    _environment.fog_depth_end = lerpf(120.0,720.0,daylight)
    _environment.fog_light_color = Color(0.006,0.008,0.012).lerp(Color(0.66,0.73,0.76),daylight)
    _environment.fog_light_energy = lerpf(0.025,0.8,daylight)
    if _sun != null: _sun.light_energy = lerpf(0.025,1.05,daylight)
    camera.far = lerpf(120.0,760.0,daylight)
