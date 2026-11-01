extends Node3D
## Static, engine-native reproduction of Three.js Station Base technical geometry.
## Source: feature/mobile-render-diagnostics (StationDefinition, TrackModule,
## PlatformModule, data/station-base/v106.js). Units: metres. No gameplay.

const PLATFORM_LENGTH := 105.0
const PLATFORM_WIDTH := 10.0
const TRAIN_LENGTH := 79.224
const PLATFORM_TOP_Y := 1.1805
const PLATFORM_THICKNESS := 0.2
const EDGE_OFFSET := 1.362
const PLATFORM_CENTER_X := -5.37
const TRACK_MIN_Z := -220.0
const TRACK_MAX_Z := 420.0
const SLEEPER_PITCH := 0.65

func _ready() -> void:
    var platform_center_z := TRAIN_LENGTH / 2.0
    var platform_max_x := PLATFORM_CENTER_X + PLATFORM_WIDTH / 2.0
    var platform_min_x := platform_max_x - PLATFORM_WIDTH
    var tracks := [platform_max_x + EDGE_OFFSET, platform_min_x - EDGE_OFFSET]
    var rail_mat := _material(Color("#899ba6"), 0.75, 0.34)
    var bed_mat := _material(Color("#43515b"))
    var sleeper_mat := _material(Color("#54616a"))
    var platform_mat := _material(Color("#9aabb4"))
    var edge_mat := _material(Color("#f3b948"))
    var track_length := TRACK_MAX_Z - TRACK_MIN_Z
    var track_center_z := (TRACK_MIN_Z + TRACK_MAX_Z) / 2.0

    for track_index in range(2):
        var x: float = tracks[track_index]
        var track_root := Node3D.new()
        track_root.name = "Track%d" % (track_index + 1)
        add_child(track_root)
        _box(track_root, "Bed", Vector3(3.0, 0.12, track_length),
            Vector3(x, -0.3, track_center_z), bed_mat)
        for side in [-0.9, 0.9]:
            _box(track_root, "Rail", Vector3(0.12, 0.16, track_length),
                Vector3(x + side, -0.08, track_center_z), rail_mat)
        var sleeper_count := int(floor(track_length / SLEEPER_PITCH))
        var sleepers := MultiMeshInstance3D.new()
        sleepers.name = "Sleepers"
        var sleeper_mesh := BoxMesh.new()
        sleeper_mesh.size = Vector3(2.3, 0.1, 0.2)
        sleeper_mesh.material = sleeper_mat
        var multi := MultiMesh.new()
        multi.transform_format = MultiMesh.TRANSFORM_3D
        multi.mesh = sleeper_mesh
        multi.instance_count = sleeper_count
        for i in range(sleeper_count):
            multi.set_instance_transform(i, Transform3D(Basis(),
                Vector3(x, -0.2, TRACK_MIN_Z + i * SLEEPER_PITCH)))
        sleepers.multimesh = multi
        track_root.add_child(sleepers)

    var platform_center_x := (platform_min_x + platform_max_x) / 2.0
    _box(self, "IslandPlatform", Vector3(PLATFORM_WIDTH, PLATFORM_THICKNESS, PLATFORM_LENGTH),
        Vector3(platform_center_x, PLATFORM_TOP_Y - PLATFORM_THICKNESS / 2.0, platform_center_z),
        platform_mat)
    _box(self, "SafetyEdgeTrack1", Vector3(0.055, 0.005, PLATFORM_LENGTH),
        Vector3(platform_max_x - 0.25, PLATFORM_TOP_Y + 0.003, platform_center_z),
        edge_mat)
    _box(self, "SafetyEdgeTrack2", Vector3(0.055, 0.005, PLATFORM_LENGTH),
        Vector3(platform_min_x + 0.25, PLATFORM_TOP_Y + 0.003, platform_center_z),
        edge_mat)

func _material(color: Color, metallic: float = 0.0, roughness: float = 1.0) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.metallic = metallic
    m.roughness = roughness
    return m

func _box(parent: Node3D, label: String, size: Vector3,
        position: Vector3, material: Material) -> void:
    var node := MeshInstance3D.new()
    node.name = label
    var mesh := BoxMesh.new()
    mesh.size = size
    mesh.material = material
    node.mesh = mesh
    node.position = position
    parent.add_child(node)
