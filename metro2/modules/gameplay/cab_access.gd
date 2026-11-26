extends RefCounted
## Ready V106 side doors only. No surface access, mesh splitting or geometry jobs.
const Native = preload("res://modules/trains/v106/native_cab_doors.gd")
var error_message:=""

func collect(consist: Node3D) -> Array[Dictionary]:
    var records: Array[Dictionary]=Native.collect(consist)
    if records.size()!=2: error_message="Не загружены две готовые боковые двери V106"
    return records

func prepare(car: Node3D, _cab: Node3D, _definitions: Array) -> Array[Dictionary]:
    var result: Array[Dictionary]=[]
    var door:=car.get_node_or_null("NativeCabSideDoor") as Node3D
    if door!=null: result.append(door.interaction_record())
    else: error_message="Не загружена готовая боковая дверь V106"
    return result

func cancel() -> void:
    pass
