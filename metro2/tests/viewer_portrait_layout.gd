extends SceneTree
var failures: Array[String] = []
func _initialize() -> void:
    call_deferred("_run")
func _run() -> void:
    var viewer := load("res://viewers/module_viewer.tscn").instantiate() as Node3D
    root.add_child(viewer)
    for dimensions in [Vector2i(480,1000),Vector2i(1000,480)]:
        root.size = dimensions
        for i in range(3): await process_frame
        viewer._layout_ui()
        viewer.get("_train_tools").show()
        for i in range(3): await process_frame
        var area := viewer.get_viewport().get_visible_rect()
        for name in ["_toolbar","_joystick","_menu","_train_tools"]:
            var control := viewer.get(name) as Control
            var rect: Rect2 = control.get_global_rect()
            if rect.position.x < 0 or rect.position.y < 0 or rect.end.x > area.size.x+1 or rect.end.y > area.size.y+1:
                failures.append(name+" outside viewport "+str(dimensions)+" "+str(rect))
        var joystick_rect: Rect2 = viewer.get("_joystick").get_global_rect()
        for button in viewer.get("_train_tools").get_children():
            if button is Button and button.get_global_rect().intersects(joystick_rect):
                failures.append("Joystick overlaps train control: "+button.text)
        for name in ["_toolbar","_joystick","_train_tools"]:
            for button in viewer.get(name).get_children():
                if button is Button:
                    var rect: Rect2 = button.get_global_rect()
                    if rect.end.x > area.size.x+1 or rect.end.y > area.size.y+1:
                        failures.append("Button clipped: "+button.text)
    viewer.queue_free()
    for i in range(2): await process_frame
    print("PORTRAIT_LAYOUT_", "PASS" if failures.is_empty() else "FAIL", failures)
    quit(0 if failures.is_empty() else 1)
