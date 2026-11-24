extends RefCounted
## Cooperative main-thread construction, never a worker scene-tree mutation.
var max_slice_usec := 2000
var cancelled := false
var pending: Dictionary = {}
var owner: Node
var _slice_started := 0

func _init(root: Node = null, slice_usec: int = 2000) -> void:
    owner=root
    max_slice_usec=slice_usec
    _slice_started=Time.get_ticks_usec()

func begin(node: Node) -> void:
    pending[node.get_instance_id()]=true

func finish(node: Node) -> void:
    pending.erase(node.get_instance_id())

func checkpoint() -> bool:
    if cancelled or not is_instance_valid(owner) or not owner.is_inside_tree(): return false
    if Time.get_ticks_usec()-_slice_started>=max_slice_usec:
        await owner.get_tree().process_frame
        _slice_started=Time.get_ticks_usec()
    return not cancelled and is_instance_valid(owner) and owner.is_inside_tree()

func cancel() -> void:
    cancelled=true
    pending.clear()
