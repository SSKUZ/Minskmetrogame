extends RefCounted
## Offline metadata helpers. Not an autoload, exporter, viewer or scene generator.
const Catalog = preload("res://modules/core/module_catalog.gd")
const FORMAT_VERSION := 1
var _adapters: Array[RefCounted] = []

static func draft_from_catalog(id: String,kind: String="") -> Dictionary:
    # Read the one existing registry; never load/instantiate its scene here.
    if not Catalog.SCENES.has(id):
        push_error("Unregistered portable module: "+id)
        return {}
    var scene_path: String=Catalog.SCENES[id]
    var module_kind: String=kind
    if module_kind.is_empty():
        if scene_path.begins_with("res://modules/stations/"):module_kind="station"
        elif scene_path.begins_with("res://modules/trains/"):module_kind="train"
        elif scene_path.begins_with("res://modules/tunnels/"):module_kind="tunnel"
        elif scene_path.begins_with("res://modules/depot/"):module_kind="depot"
        else:module_kind="other"
    return {
        "format_version":FORMAT_VERSION,
        "module":{"id":id,"type":module_kind,"scene":scene_path},
        "source_frame":{
            "engine":"Godot","engine_version":"4.3",
            "metres_per_unit":Catalog.METRES_PER_UNIT,
            "handedness":"right","up_axis":"+Y",
            "forward_axis":"-Z","route_positive_axis":"+Z",
            "origin":"module_root","matrix_layout":"column_major_4x4",
            "quaternion_layout":"xyzw"
        },
        # Explicitly unresolved: 53.2 must choose and document Roblox conversion.
        "target_frame":{"platform":"Roblox","studs_per_metre":null,"basis_from_source":null},
        "geometry_sources":[{
            "id":"scene","kind":"scene","path":scene_path,
            "requires_initialization":true,"status":"unassessed"
        }],
        "materials":[],"textures":[],"points":[],"zones":[],
        "data":{"parameters":[],"routes":[],"equipment_states":[],"animations":[],"references":[]},
        "adapter_hints":[],
        "limitations":[{
            "code":"not_assessed",
            "detail":"Draft from catalog only; geometry, semantics, materials and target conversion require assessment."
        }]
    }

static func vector_data(value: Vector3) -> Array:
    return [value.x,value.y,value.z]

static func transform_data(value: Transform3D) -> Array:
    # Local, unscaled Godot coordinates; do not apply a Roblox conversion here.
    return [value.basis.x.x,value.basis.x.y,value.basis.x.z,0.0,
        value.basis.y.x,value.basis.y.y,value.basis.y.z,0.0,
        value.basis.z.x,value.basis.z.y,value.basis.z.z,0.0,
        value.origin.x,value.origin.y,value.origin.z,1.0]

static func point(id: String,role: String,pose: Transform3D,node_path: String="") -> Dictionary:
    return {"id":id,"role":role,"transform":transform_data(pose),"node_path":node_path}

static func box_zone(id: String,role: String,pose: Transform3D,size: Vector3) -> Dictionary:
    return {"id":id,"role":role,"transform":transform_data(pose),
        "shape":{"kind":"box","size":vector_data(size)}}

func register_adapter(adapter: RefCounted) -> Error:
    # Caller supplies a trusted object. Never execute paths found in a JSON file.
    if adapter==null:return ERR_INVALID_PARAMETER
    for method in ["adapter_id","accepts","inspect"]:
        if not adapter.has_method(method):return ERR_INVALID_PARAMETER
    var id: String=str(adapter.call("adapter_id"))
    if id.is_empty():return ERR_INVALID_PARAMETER
    for existing in _adapters:
        if str(existing.call("adapter_id"))==id:return ERR_ALREADY_EXISTS
    _adapters.append(adapter)
    return OK

func adapter_for(descriptor: Dictionary) -> RefCounted:
    # Last registered matching adapter wins, allowing a specialised override.
    if descriptor.get("format_version",0)!=FORMAT_VERSION:return null
    for i in range(_adapters.size()-1,-1,-1):
        if bool(_adapters[i].call("accepts",descriptor)):return _adapters[i]
    return null
