extends RefCounted
## Paths, not preloads: creating a station/depot never loads train GLBs.
const SCENES := {
    "mihalovo":"res://modules/stations/mihalovo/mihalovo.tscn",
    "full_line":"res://modules/line/full_line.tscn",
    "grushevka":"res://modules/stations/grushevka/grushevka.tscn",
    "institut_kultury":"res://modules/stations/institut_kultury/institut_kultury.tscn",
    "ploshchad_lenina":"res://modules/stations/ploshchad_lenina/ploshchad_lenina.tscn",
    "oktyabrskaya":"res://modules/stations/oktyabrskaya/oktyabrskaya.tscn",
    "ploshchad_pobedy":"res://modules/stations/ploshchad_pobedy/ploshchad_pobedy.tscn",
    "yakuba_kolasa":"res://modules/stations/yakuba_kolasa/yakuba_kolasa.tscn",
    "akademiya_nauk":"res://modules/stations/akademiya_nauk/akademiya_nauk.tscn",
    "vostok":"res://modules/stations/vostok/vostok.tscn",
    "moskovskaya":"res://modules/stations/moskovskaya/moskovskaya.tscn",
    "park_chelyuskintsev":"res://modules/stations/park_chelyuskintsev/park_chelyuskintsev.tscn",
    "borisovsky_trakt":"res://modules/stations/borisovsky_trakt/borisovsky_trakt.tscn",
    "v106":"res://modules/trains/v106/v106_train.tscn",
    "uruchye":"res://modules/stations/uruchye/uruchye.tscn",
    "tunnels":"res://modules/tunnels/tunnel_system.tscn",
    "tunnel_16m":"res://modules/tunnels/tunnel_section_16m.tscn",
    "depot":"res://modules/depot/depot.tscn",
}
const StaticStation = preload("res://modules/line/static_station.gd")
const METRES_PER_UNIT := 1.0
const TRAIN_BODY_OFFSET := Vector3(0,0.22,0)

static func prepared_station_data(id: String) -> Dictionary:
    var path := "res://modules/stations/"+id+"/prebuilt/index.json"
    if not FileAccess.file_exists(path): return {}
    var data: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
    if not data is Dictionary or bool(data.get("legacy",false)): return {}
    return data

static func create_module(id: String, prepared_data: Dictionary = {}) -> Node3D:
    assert(SCENES.has(id),"Unknown module: " + id)
    var prepared: Dictionary=prepared_data if not prepared_data.is_empty() else prepared_station_data(id)
    if not prepared.is_empty():
        var station := StaticStation.new()
        station.name=id+"Module"
        station.manifest=prepared
        return station
    var scene := load(SCENES[id]) as PackedScene
    assert(scene != null,"Module scene failed to load: " + id)
    return scene.instantiate() as Node3D

static func connection(module: Node3D, id: String) -> Transform3D:
    # Track centre at rail datum. Both markers use the route's +Z basis;
    # travel toward Uruchye is -Z. No implicit 180-degree turn.
    return (module.get_node("Connections/" + id) as Node3D).global_transform

static func align_connection(module: Node3D, id: String, target: Transform3D) -> void:
    var local := module.global_transform.affine_inverse() * connection(module,id)
    module.global_transform = target * local.affine_inverse()
