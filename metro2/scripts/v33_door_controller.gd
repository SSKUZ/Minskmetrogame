extends Node
## Web-only lightweight compatibility adapter. No GLB traversal, cutting,
## material replacement, generated meshes or moving door animations.
## Passenger and cab access use independent authored/static markers.
signal ready_count(count: int)
var leaves: Array[Dictionary]=[]
var openness: float=0.0
var target_open: bool=false
var validated: bool=true
var side_targets: Dictionary={-1:false,1:false}
var side_open: Dictionary={-1:0.0,1:0.0}

func setup(_consist: Node3D) -> void:
    leaves.clear()
    validated=true
    target_open=false
    openness=0.0
    side_targets={-1:false,1:false}
    side_open={-1:0.0,1:0.0}
    ready_count.emit(0)

func request_side(_side: int, _speed_mps: float) -> bool:
    return validated

func request_open(_speed_mps: float) -> void:
    pass

func request_close() -> void:
    target_open=false

func can_move() -> bool:
    return validated
