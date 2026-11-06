extends Node3D
## Shared train-only lighting: no tunnel geometry receives layer 16.
const SALOON_LAYER := 16
var lights: Array[OmniLight3D] = []
var emitters: Array[BaseMaterial3D] = []
var enabled := true
var button: Button
var cars_lit := 0

func initialize(game: Node3D, train: Node3D, ui: CanvasLayer) -> void:
    var cab := game.get("cab_runtime") as Node3D
    for node in train.get_children():
        if not str(node.name).begins_with("OriginalV106Car0"): continue
        var car := node as Node3D
        var box: AABB = game.call("_get_model_bounds",car)
        var start := maxf(box.position.z,-7.4) if str(car.name) == "OriginalV106Car01" else box.position.z
        var length := box.end.z-start
        for mesh_node in car.find_children("*","MeshInstance3D",true,false):
            var mesh := mesh_node as MeshInstance3D
            if cab != null and cab.is_ancestor_of(mesh): continue
            var bounds := car.global_transform.affine_inverse()*mesh.global_transform*mesh.get_aabb()
            if str(car.name) == "OriginalV106Car01" and bounds.end.z < -7.6: continue
            mesh.layers |= SALOON_LAYER
            # Only existing narrow ceiling luminaire surfaces, never whole walls.
            if bounds.position.y > 3.0 and bounds.size.y < 0.12:
                for surface in range(mesh.mesh.get_surface_count()):
                    var original := mesh.get_active_material(surface) as BaseMaterial3D
                    if original == null: continue
                    var color := original.albedo_color
                    if minf(color.r,minf(color.g,color.b)) < 0.72: continue
                    if bounds.size.x > 0.8 and bounds.size.z > 0.8 and original.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED: continue
                    var material := original.duplicate() as BaseMaterial3D
                    material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
                    material.emission_enabled = true
                    material.emission = Color(0.86,0.90,0.94)
                    mesh.set_surface_override_material(surface,material)
                    emitters.append(material)
        for fraction in [0.20,0.50,0.80]:
            var lamp := OmniLight3D.new()
            lamp.name = "SaloonCeilingLight"
            lamp.position = Vector3(box.get_center().x,3.12,start+length*float(fraction))
            lamp.light_color = Color(0.98,0.98,1.0)
            lamp.light_energy = 1.25
            lamp.omni_range = 6.2
            lamp.omni_attenuation = 1.15
            lamp.light_cull_mask = SALOON_LAYER
            lamp.shadow_enabled = false
            car.add_child(lamp)
            lights.append(lamp)
        cars_lit += 1
    button = Button.new()
    button.position = Vector2(495,55)
    button.custom_minimum_size = Vector2(240,42)
    button.toggle_mode = true
    ui.add_child(button)
    button.pressed.connect(func(): enabled = not enabled; _apply())
    _apply()
    print("SALOON_LIGHTING_READY cars=",cars_lit," lights=",lights.size()," emitters=",emitters.size())

func _apply() -> void:
    for lamp in lights: lamp.visible = enabled
    for material in emitters:
        material.emission_energy_multiplier = 0.65 if enabled else 0.0
    button.text = "СВЕТ САЛОНОВ: "+("ВКЛ." if enabled else "ВЫКЛ.")
    button.set_pressed_no_signal(enabled)
