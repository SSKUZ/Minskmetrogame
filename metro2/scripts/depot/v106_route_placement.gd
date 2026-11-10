extends RefCounted
const Route = preload("res://scripts/depot/route_profile.gd")

## Shared original placement and bogies; both legacy and modular trains call this.
static func place(game: Node3D, pose_cache: Dictionary, rest_poses: Dictionary) -> void:
    if not is_instance_valid(game.train): return
    for node in game.train.get_children():
        if not node is Node3D: continue
        var car := node as Node3D
        if str(car.name).begins_with("OriginalV106Car"):
            if not pose_cache.has(car): pose_cache[car] = game._get_model_bounds(car)
            if not rest_poses.has(car): rest_poses[car] = car.transform
            var bounds: AABB = pose_cache[car]
            var rest: Transform3D = rest_poses[car]
            var center := rest*bounds.get_center()
            var supports: PackedFloat32Array = game._bogie_visuals.setup_car(car,bounds,rest)
            var front_y := Route.height(game.train.global_position.z+supports[0])
            var rear_y := Route.height(game.train.global_position.z+supports[1])
            var support_span := maxf(0.1,supports[1]-supports[0])
            var pitch := -atan2(rear_y-front_y,support_span)
            var basis := Basis(Vector3.RIGHT,pitch)*rest.basis
            # Exported cars have different model origins. Rotate about each
            # carriage centre, never its possibly distant GLB origin.
            var balance := (center.z-supports[0])/support_span
            var target := center+Vector3(0,lerpf(front_y,rear_y,balance),0)
            car.transform = Transform3D(basis,target-basis*bounds.get_center())
            game._bogie_visuals.update_car(car,game.train,game.distance)
        elif car.get_child_count() > 0 and car.get_child(0) is MeshInstance3D:
            if not car.has_meta("route_coupler_z"):
                var z := (car.get_child(0) as Node3D).position.z
                car.set_meta("route_coupler_z",z)
                car.position.z = z
                for child in car.get_children():
                    if child is Node3D: (child as Node3D).position.z -= z
            var z := float(car.get_meta("route_coupler_z"))
            car.position.y = Route.height(game.train.global_position.z+z)
            car.rotation.x = -atan(Route.grade(game.train.global_position.z+z))

