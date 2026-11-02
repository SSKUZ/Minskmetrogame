extends Node
## Reuses original browser recordings; no synthesized or invented speech.
signal announcement_started(kind: String)
signal announcement_finished(kind: String)
const ARRIVAL := "res://audio/malinovka_arrival.mp3"
const DEPARTURE := "res://audio/malinovka_departure_petrovshchina.mp3"
var player: AudioStreamPlayer
var current_kind := ""
var queued_kind := ""

func _ready() -> void:
    player = AudioStreamPlayer.new()
    player.name = "StationAnnouncementAudio"
    player.volume_db = 0.0
    add_child(player)
    player.finished.connect(_on_finished)

func play_arrival() -> bool:
    return _play("arrival", ARRIVAL)

func play_departure() -> bool:
    return _play("departure", DEPARTURE)

func _play(kind: String, path: String) -> bool:
    if not ResourceLoader.exists(path):
        push_warning("Missing original announcement: " + path)
        return false
    var stream := load(path) as AudioStream
    if stream == null:
        return false
    if player.playing:
        player.stop()
    current_kind = kind
    player.stream = stream
    player.play()
    announcement_started.emit(kind)
    return true

func _on_finished() -> void:
    announcement_finished.emit(current_kind)
    current_kind = ""
