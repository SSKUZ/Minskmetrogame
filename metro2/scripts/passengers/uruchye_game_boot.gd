extends Node3D
## A real first frame before any heavy train resource is loaded/instantiated.
const GAME_PATH := "res://scenes/passengers/uruchye_passenger_demo.tscn"
var label: Label
var overlay: CanvasLayer
var boot_camera: Camera3D

func _ready() -> void:
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
    var result:=ResourceLoader.load_threaded_request(GAME_PATH,"PackedScene")
    if result!=OK:
        label.text="Не удалось начать загрузку сцены: %s"%result
        return
    while true:
        var progress: Array=[]
        var status:=ResourceLoader.load_threaded_get_status(GAME_PATH,progress)
        if status==ResourceLoader.THREAD_LOAD_LOADED:break
        if status==ResourceLoader.THREAD_LOAD_FAILED or status==ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
            label.text="Ошибка загрузки игровой сцены. Нажмите «Повторить загрузку»."
            return
        if not progress.is_empty():label.text="МИНСКОЕ МЕТРО 2.0 · Подготовка ресурсов: %d%%"%int(float(progress[0])*100)
        await get_tree().process_frame
    var scene:=ResourceLoader.load_threaded_get(GAME_PATH) as PackedScene
    label.text="Создание станции, оригинальной кабины и пассажиров…"
    var game:=scene.instantiate()
    add_child(game)
    # The HTML overlay remains until the playable controller and passengers
    # explicitly report ready; engine.startGame alone is not scene readiness.
    while not is_instance_valid(game.get("passengers")):
        await get_tree().process_frame
    overlay.queue_free()
