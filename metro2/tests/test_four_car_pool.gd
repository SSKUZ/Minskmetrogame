extends SceneTree
func _initialize() -> void:
    call_deferred("run_tests")
func run_tests() -> void:
    var script: GDScript = load("res://scripts/v106_four_cars_preview.gd")
    var game := Node3D.new()
    game.set_script(script)
    root.add_child(game)
    await process_frame
    await process_frame
    game.set_physics_process(false)
    var tunnel: Node3D = game._tunnel
    assert(game.train.get_node_or_null("OriginalV106Car04") != null)
    assert(absf(game._train_bounds.size.z-81.27547)<0.01)
    var peak := 0
    var cases := 0
    for mode in ["external","cabin","salon"]:
        game._set_camera_mode(mode)
        for step in range(301):
            game.distance = 300.0-float(step)
            game.train.position.z = game.distance
            game._update_camera()
            var old: Dictionary = {}
            for section in tunnel._sections:
                if section.visible:
                    old[section.get_instance_id()] = section.position.z
            tunnel.sync_to_view()
            assert(tunnel.coverage_is_valid())
            peak = maxi(peak,tunnel.active_module_count())
            for section in tunnel._sections:
                if old.has(section.get_instance_id()) and absf(float(old[section.get_instance_id()])-section.position.z)>0.1:
                    var old_center: float = float(old[section.get_instance_id()])+8.0
                    assert(absf(old_center-game.camera.global_position.z)>56.0)
            cases += 1
    game._set_camera_mode("external")
    game.speed = 0.0
    game.throttle = true
    game._physics_process(1.0)
    assert(game.speed > 0.0)
    game.throttle = false
    game.brake = true
    game._physics_process(1.0)
    assert(is_zero_approx(game.speed))
    assert(game.station_illumination(150.0)<game.station_illumination(100.0))
    assert(game.station_illumination(100.0)<game.station_illumination(60.0))
    assert(game.station_illumination(60.0)<game.station_illumination(30.0))
    var station_root := Node3D.new()
    var station_scene := PackedScene.new()
    assert(station_scene.pack(station_root)==OK)
    station_root.free()
    game.attach_station(station_scene,Transform3D(Basis(),Vector3(0,0,0)),0.0)
    assert(is_instance_valid(game._station))
    print("POOL_TEST_PASS cases=",cases," peak_modules=",peak," recycles=",tunnel.recycle_count," cars=4 length=",game._train_bounds.size.z)
    game.free()
    quit()
