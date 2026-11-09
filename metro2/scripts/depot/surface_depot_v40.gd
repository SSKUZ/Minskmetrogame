extends "res://scripts/v106_four_cars_preview.gd"
const Route = preload("res://scripts/depot/route_profile.gd")
const TunnelAdapter = preload("res://scripts/depot/depot_tunnel.gd")
const STATION_Z := -220.112
const STATION_ENTRY_Z := -128.0
const STATION_EXIT_Z := -240.0
var _pose_cache: Dictionary = {}
var _rest_poses: Dictionary = {}
var _saloon_equipment: Node3D
var _saloon_fov := 80.0
var _sun: DirectionalLight3D
var _sky: ProceduralSkyMaterial
var flight_position := Vector3.ZERO
var _flight_ui: Control
var _flight_height := 0.0
const PLATFORM_CAMERA_RANGE := 100.0

func _ready() -> void:
    distance = Route.START_Z
    route_end_distance = STATION_Z + 9.603
    tunnel_script = TunnelAdapter
    super._ready()
    # Use the original Station Base alone: no preview train, camera or environment.
    attach_station(preload("res://scenes/depot/route_station_v41.tscn"),
        Transform3D(Basis.IDENTITY,Vector3(0,0,STATION_Z)),route_end_distance)
    _diagnostics_enabled = false
    _install_inspection_ui()
    _saloon_equipment = preload("res://scripts/depot/saloon_equipment.gd").new()
    _saloon_equipment.name = "PassengerSaloonEquipment"
    add_child(_saloon_equipment)
    _saloon_equipment.call("initialize",self,train)
    _ensure_station_camera_anchor(_station)
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

func _install_inspection_ui() -> void:
    for child in _ui_layer.get_children():
        if child is HBoxContainer and (child.name == "ViewModes" or child.name != ""):
            if child.name == "ViewModes" or child.get_child_count() == 2:
                child.hide()
        if child is VBoxContainer and child.name == "CameraMovement":
            child.hide()
    _flight_ui = preload("res://scripts/depot/mobile_inspection_ui.gd").new()
    _ui_layer.add_child(_flight_ui)
    _flight_ui.call("initialize",self)

func _ensure_station_camera_anchor(station: Node3D) -> void:
    if not is_instance_valid(station) or station.has_node("PlatformCameraAnchor"): return
    # Station-local placement on the island platform, not in the wall.
    var anchor := Node3D.new()
    anchor.name = "PlatformCameraAnchor"
    station.add_child(anchor)
    anchor.position = Vector3(-1.65,2.65,25.0)
    anchor.look_at(station.to_global(Vector3(Route.CENTER_X,1.7,99.0)),Vector3.UP)

func platform_camera_available() -> bool:
    if not is_instance_valid(_station) or not is_instance_valid(train): return false
    var head_z := train.global_position.z + _train_bounds.position.z
    return head_z <= STATION_ENTRY_Z + PLATFORM_CAMERA_RANGE and head_z >= STATION_EXIT_Z - 30.0

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
            if not _rest_poses.has(car): _rest_poses[car] = car.transform
            var bounds: AABB = _pose_cache[car]
            var rest: Transform3D = _rest_poses[car]
            var center := rest*bounds.get_center()
            var supports: PackedFloat32Array = _bogie_visuals.setup_car(car,bounds,rest)
            var front_y := Route.height(train.global_position.z+supports[0])
            var rear_y := Route.height(train.global_position.z+supports[1])
            var support_span := maxf(0.1,supports[1]-supports[0])
            var pitch := -atan2(rear_y-front_y,support_span)
            var basis := Basis(Vector3.RIGHT,pitch)*rest.basis
            # Exported cars have different model origins. Rotate about each
            # carriage centre, never its possibly distant GLB origin.
            var balance := (center.z-supports[0])/support_span
            var target := center+Vector3(0,lerpf(front_y,rear_y,balance),0)
            car.transform = Transform3D(basis,target-basis*bounds.get_center())
            _bogie_visuals.update_car(car,train,distance)
        elif car.get_child_count() > 0 and car.get_child(0) is MeshInstance3D:
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
    if camera_mode == "platform" and not platform_camera_available():
        _set_camera_mode("cabin")
    if camera_mode == "flight" and is_instance_valid(_flight_ui):
        var axis: Vector2 = _flight_ui.get("stick")
        # Fly relative to the actual camera view, including vertical pitch.
        var view_basis := Basis.from_euler(Vector3(-orbit_pitch,orbit_yaw,0.0))
        var forward := -view_basis.z
        var right := view_basis.x
        var movement := (right*axis.x-forward*axis.y)*CAMERA_MOVE_SPEED*delta
        var proposed := flight_position+movement
        if proposed.z <= Route.PORTAL_Z:
            # Station and tunnel have a restricted walkable inspection corridor.
            proposed.x = clampf(proposed.x,Route.CENTER_X-3.1,Route.CENTER_X+3.1)
            proposed.y = clampf(proposed.y,1.0,5.4)
            proposed.z = maxf(proposed.z,STATION_EXIT_Z+3.0)
        else:
            proposed.y = clampf(proposed.y,1.0,35.0)
        flight_position = proposed
        _update_camera()
    if distance > 442.0:
        distance = 442.0
        speed = 0.0
        train.position.z = distance
        _update_camera()
    _update_atmosphere()
    if hud != null:
        var phase := "ЭЛЕКТРОДЕПО" if distance > 300.0 else "ПОДХОД К ПОРТАЛУ" if distance > 96.0 else "УРУЧЬЕ" if distance < STATION_ENTRY_Z + 10.0 else "ТОННЕЛЬ"
        hud.text = "%s | 4 ВАГОНА | %.0f км/ч | %.0f м от депо | %s" % [phase,speed*3.6,Route.START_Z-distance,camera_mode]

func _update_camera() -> void:
    if not is_instance_valid(camera) or not is_instance_valid(train): return
    # Placement must advance even when flight/platform cameras return early.
    _place_consist()
    if camera_mode == "flight":
        camera.global_position = flight_position
        camera.global_basis = Basis.from_euler(Vector3(-orbit_pitch,orbit_yaw,0))
        return
    if camera_mode == "platform":
        if is_instance_valid(_station):
            var anchor := _station.get_node_or_null("PlatformCameraAnchor") as Node3D
            if is_instance_valid(anchor):
                camera.global_transform = anchor.global_transform
                return
        return
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
        if is_instance_valid(_saloon_equipment):
            var mount := _saloon_equipment.call("camera_mount",selected) as Node3D
            camera.global_position = mount.global_position
            camera.global_basis = mount.global_basis*Basis.from_euler(Vector3(-orbit_pitch,orbit_yaw,0))
            camera.fov = _saloon_fov
    else:
        super._update_camera()
        camera.global_basis = cars[0].global_basis*Basis.from_euler(Vector3(-orbit_pitch,orbit_yaw,0))

func _set_camera_mode(mode: String) -> void:
    if mode == "platform" and not platform_camera_available(): return
    if mode == "flight":
        flight_position = camera.global_position
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
    # Local station approach lighting, leaving the rest of the tunnel dark.
    var station_light := (1.0-smoothstep(STATION_ENTRY_Z-8.0,STATION_ENTRY_Z+28.0,camera.global_position.z))*smoothstep(STATION_EXIT_Z-24.0,STATION_EXIT_Z+6.0,camera.global_position.z)
    if station_light > 0.0:
        _environment.ambient_light_energy = lerpf(_environment.ambient_light_energy,0.42,station_light)
        _environment.ambient_light_color = _environment.ambient_light_color.lerp(Color(0.88,0.90,0.92),station_light)
        _environment.fog_depth_begin = lerpf(_environment.fog_depth_begin,110.0,station_light)
        _environment.fog_depth_end = lerpf(_environment.fog_depth_end,210.0,station_light)
        camera.far = lerpf(camera.far,220.0,station_light)

func _zoom_view(ratio: float) -> void:
    if camera_mode == "salon":
        # CCTV stays in its ceiling corner; a pinch changes optics, not location.
        _saloon_fov = clampf(_saloon_fov/maxf(ratio,0.01),35.0,100.0)
        if is_instance_valid(camera): camera.fov = _saloon_fov
    else:
        super._zoom_view(ratio)

func passenger_information() -> Dictionary:
    var station_name := "УРУЧЧА"
    if is_instance_valid(_station):
        station_name = str(_station.get_meta("passenger_name",station_name))
    var nose_z := distance-9.65
    if is_instance_valid(train) and train.has_node("OriginalV106Car01"):
        var lead := train.get_node("OriginalV106Car01") as Node3D
        if _pose_cache.has(lead):
            var bounds: AABB = _pose_cache[lead]
            nose_z = lead.to_global(Vector3(bounds.get_center().x,bounds.get_center().y,bounds.position.z)).z
    var at_platform := nose_z <= STATION_ENTRY_Z and nose_z >= STATION_EXIT_Z
    return {"current_station":station_name,"next_station":station_name,"at_station":at_platform and absf(speed) <= 0.05}
