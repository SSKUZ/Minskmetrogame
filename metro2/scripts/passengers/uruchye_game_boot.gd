extends Node3D
## A real first frame before any heavy train resource is loaded/instantiated.
const GAME_PATH := "res://scenes/passengers/uruchye_passenger_demo.tscn"
var label: Label
var overlay: CanvasLayer
var boot_camera: Camera3D

func _ready() -> void:
    # The game and every auxiliary viewport must share the main 3D scenario.
    var main_viewport:=get_viewport()
    main_viewport.disable_3d=false
    main_viewport.world_3d=World3D.new()
    var world:=WorldEnvironment.new()
    var environment:=Environment.new()
    environment.background_mode=Environment.BG_COLOR
    environment.background_color=Color("#253243")
    environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color=Color("#dce7f0")
    environment.ambient_light_energy=0.7
    world.environment=environment;add_child(world)
    var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-65,-20,0)
    light.light_energy=0.6;light.shadow_enabled=false;add_child(light)
    boot_camera=Camera3D.new();boot_camera.position=Vector3(-3.0,3.0,32.0)
    boot_camera.rotation.y=PI;boot_camera.current=true;add_child(boot_camera)
    overlay=CanvasLayer.new();overlay.layer=80;add_child(overlay)
    label=Label.new();label.text="МИНСКОЕ МЕТРО 2.0 · Загрузка игровой сцены…"
    label.position=Vector2(24,170);label.add_theme_font_size_override("font_size",22)
    overlay.add_child(label)
    await get_tree().process_frame
    await get_tree().process_frame
    # Web export uses a single-threaded renderer. Instantiate GPU resources
    # from the main thread after the loading screen has its first frame.
    label.text="Подготовка станции, кабины и состава…"
    if OS.has_feature("web"):
        JavaScriptBridge.eval("window.metroBootStage && window.metroBootStage('Подготовка 3D-ресурсов игры')",true)
    var scene:=load(GAME_PATH) as PackedScene
    if scene==null:
        label.text="Не удалось загрузить игровую сцену"
        return
    var game:=scene.instantiate()
    add_child(game)
    # The HTML overlay remains until the playable controller and passengers
    # explicitly report ready; engine.startGame alone is not scene readiness.
    while not is_instance_valid(game.get("passengers")):
        await get_tree().process_frame
    var controller:=game.get("train") as Node3D
    var game_camera:=controller.get("camera") as Camera3D
    boot_camera.clear_current(false)
    boot_camera.queue_free()
    get_viewport().disable_3d=false
    game_camera.make_current()
    overlay.queue_free()
