extends Node3D
## Prepared architecture only; original dynamic scripts live in their own subtrees.
const Budget = preload("res://modules/line/build_budget.gd")
const Store = preload("res://modules/line/static_resource_store.gd")
var manifest: Dictionary = {}
var line_open := false
var static_ready := false
var static_failed := false
var _leases: Array[int]=[]
var _store: Node

func _ready() -> void:
    var work: RefCounted=get_meta("metro_line_work",null)
    var own_budget := work==null
    if own_budget:
        work=Budget.new(self,1500)
        set_meta("metro_line_work",work)
        hide()
    work.begin(self)
    _store=Store.shared(self)
    var chunks: Array=manifest.get("open_chunks",[]) if line_open else manifest.get("closed_chunks",[])
    for chunk in chunks:
        if not await work.checkpoint(): return
        var fragment: Node3D=await _store.instantiate_chunk(chunk,self)
        if fragment==null:
            static_failed=true
            break
        _leases.append(int(fragment.get_meta("static_resource_token",0)))
        # Retain original parent/name paths. Only the temporary fragment wrapper
        # is extra; it stays empty and owns the resource lease until unloading.
        var children: Array[Node]=fragment.get_children()
        add_child(fragment)
        for child in children:
            fragment.remove_child(child)
            add_child(child)
            if not await work.checkpoint(): return
    work.finish(self)
    if own_budget:
        while not work.pending.is_empty():
            if not await work.checkpoint(): return
            await get_tree().process_frame
        work.release_sources()
    static_ready=not static_failed
    if own_budget and static_ready: show()

func static_loading_complete() -> bool:
    return static_ready or static_failed

func release_static_resources() -> void:
    set_meta("static_cancelled",true)
    if is_instance_valid(_store):
        for token in _leases: _store.release_token(token)
    _leases.clear()

func _exit_tree() -> void:
    release_static_resources()
