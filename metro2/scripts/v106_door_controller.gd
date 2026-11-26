extends Node
## Door leaves discovered by their imported mesh bounds; GLB originals stay untouched.
## Existing leaf parents move all child meshes together with their caution decal.
signal ready_count(count: int)
var leaves: Array[Dictionary] = []
var openness: float = 0.0
var target_open: bool = false
# The depot-to-Uruchye platform is on the train's left side.
# Only this side is enabled for passenger service.
const PLATFORM_SIDE := -1.0
var validated: bool = false
const SLIDE_METERS := 0.56
const ANIMATION_SECONDS := 1.3

# Legacy mesh-based door discovery is permanently disabled for the web game.
# Original imported meshes remain untouched; cabin access uses authored markers.
func setup(_consist: Node3D) -> void:
    leaves.clear()
    openness = 0.0
    target_open = false
    validated = true
    ready_count.emit(0)

func _process(_delta: float) -> void:
    pass

func request_open(speed_mps: float) -> void:
    if speed_mps > 0.05 or not validated:
        return
    target_open = false

func request_close() -> void:
    target_open = false

func can_move() -> bool:
    return validated
