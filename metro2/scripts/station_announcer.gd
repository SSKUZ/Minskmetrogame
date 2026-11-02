extends Node
## Reuses original browser recordings; no synthesized or invented speech.
signal announcement_started(kind: String)
signal announcement_finished(kind: String)
const ARRIVAL := "res://audio/malinovka_arrival.mp3"
const DEPARTURE := "res://audio/malinovka_departure_petrovshchina.mp3"
var player: AudioStreamPlayer
var current_kind := ""
var phase := 0 # 0: arrival, 1: departure, 2: optional notices, 3: complete
var safety_files: Array[String] = ["res://audio/safety_pickpockets.mp3", "res://audio/safety_fraud.mp3"]
var safety_index := 0

func _ready() -> void:
    player = AudioStreamPlayer.new()
    player.name = "StationAnnouncementAudio"
    player.volume_db = 0.0
    add_child(player)
    player.finished.connect(_on_finished)

func reset_sequence() -> void:
    player.stop()
    phase = 0
    safety_index = 0

func press_info(approaching: bool, at_station: bool, doors_open: bool, moving: bool) -> String:
    if player.playing:
        return "Объявление ещё звучит"
    if phase == 0:
        if not approaching:
            return "Объявление станции доступно при подъезде"
        if play_arrival():
            phase = 1
            return "Станция Малиновка"
        return "Нет аудиозаписи прибытия"
    if phase == 1:
        if not at_station or not doors_open or moving:
            return "Следующая станция: объявление после открытия дверей"
        if play_departure():
            phase = 2
            return "Осторожно, двери закрываются. Следующая станция"
        return "Нет аудиозаписи отправления"
    if phase == 2:
        if doors_open:
            return "Дополнительное объявление после закрытия дверей"
        while safety_index < safety_files.size():
            var path: String = safety_files[safety_index]
            safety_index += 1
            if _play("safety", path):
                return "Дополнительное объявление"
        phase = 3
        return "Дополнительных записей пока нет"
    return "Объявления этого участка завершены"

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
