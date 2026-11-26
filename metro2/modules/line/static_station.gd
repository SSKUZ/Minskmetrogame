extends Node3D
## Prepared architecture only; original dynamic scripts live in their own subtrees.
const Budget = preload("res://modules/line/build_budget.gd")
const Store = preload("res://modules/line/static_resource_store.gd")
var manifest: Dictionary = {}
var line_open := false
var static_ready := false
var static_failed := false
var static_error:=""
signal static_progress(message: String)
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
    _store.progress.connect(_resource_progress)
    var chunks: Array=manifest.get("open_chunks",[]) if line_open else manifest.get("closed_chunks",[])
    var completed:=0
    if chunks.is_empty():
        static_failed=true
        static_error="В индексе станции отсутствуют фрагменты геометрии"
    for chunk in chunks:
        static_progress.emit("Геометрия станции: %d/%d" % [completed+1,chunks.size()])
        if not await work.checkpoint():
            static_failed=true
            static_error="Подготовка станции отменена"
            break
        var fragment: Node3D=await _store.instantiate_chunk(chunk,self)
        if fragment==null:
            static_failed=true
            static_error=_store.error_message
            break
        _leases.append(int(fragment.get_meta("static_resource_token",0)))
        var target: Node=get_node_or_null(NodePath(str(chunk.get("attach_parent","."))))
        if target==null:
            static_failed=true
            static_error="Не найден родитель фрагмента станции: "+str(chunk.get("attach_parent","."))
            _store.release_chunk(fragment)
            fragment.free()
            break
        # Retain original parent/name paths. Only the temporary fragment wrapper
        # is extra; it stays empty and owns the resource lease until unloading.
        var children: Array[Node]=fragment.get_children()
        add_child(fragment)
        for child in children:
            _set_subtree_owner(child,null)
            fragment.remove_child(child)
            target.add_child(child)
            _set_subtree_owner(child,self)
            if not await work.checkpoint():
                static_failed=true
                static_error="Подготовка станции отменена"
                break
        if static_failed: break
        completed+=1
    work.finish(self)
    if own_budget:
        while not work.pending.is_empty():
            if not await work.checkpoint(): return
            await get_tree().process_frame
        work.release_sources()
    if manifest.has("platform_navigation"): set_meta("metro_platform_navigation",manifest.platform_navigation)
    if not static_failed and int(manifest.get("walking_collision",0))>0: set_meta("metro_walk_collision",int(manifest.walking_collision))
    static_ready=not static_failed
    if own_budget and static_ready: show()

func _resource_progress(consumer_id: int, message: String) -> void:
    if consumer_id==get_instance_id(): static_progress.emit(message)

func _set_subtree_owner(node: Node, new_owner: Node) -> void:
    node.owner=new_owner
    for child in node.get_children(): _set_subtree_owner(child,new_owner)

func static_loading_complete() -> bool:
    return static_ready or static_failed

func release_static_resources() -> void:
    set_meta("static_cancelled",true)
    if is_instance_valid(_store):
        for token in _leases: _store.release_token(token)
    _leases.clear()

func _exit_tree() -> void:
    release_static_resources()
