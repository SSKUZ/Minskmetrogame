extends Node3D
## Station-local adaptation of StationBaseStatic; original coordinates and track geometry retained.
## Static, engine-native reproduction of Three.js Station Base technical geometry.
## Source: feature/mobile-render-diagnostics (StationDefinition, TrackModule,
## PlatformModule, data/station-base/v106.js). Units: metres. No gameplay.

const TRACK_PATH = preload("res://scripts/playable_track_path.gd")
const PLATFORM_LENGTH := 105.0
const PLATFORM_WIDTH := 10.0
const TRAIN_LENGTH := 79.224
const PLATFORM_TOP_Y := 1.1805
const PLATFORM_THICKNESS := 0.2
const STOP_Z := 9.603
const EDGE_OFFSET := 1.362
const PLATFORM_CENTER_X := -5.37
const TRACK_MIN_Z := -220.0
const TRACK_MAX_Z := 420.0
const SLEEPER_PITCH := 0.65

@export var track_min_z := TRACK_MIN_Z
@export var track_max_z := TRACK_MAX_Z
@export var rail_center := 0.9
@export var rail_width := 0.12


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
    var track_length := track_max_z - track_min_z
    var track_center_z := (track_min_z + track_max_z) / 2.0

    for track_index in range(2):
        var x: float = tracks[track_index]
        var track_root := Node3D.new()
        track_root.name = "Track%d" % (track_index + 1)
        add_child(track_root)
        # Track 1 follows the playable S-curve; track 2 remains straight.
        # Build one piecewise path without overlapping straight rail geometry.
        var segment_length := 1.0 if track_index == 0 else track_length
        var segment_count := int(ceilf(track_length / segment_length))
        var rail_mesh := BoxMesh.new()
        rail_mesh.size = Vector3(rail_width, 0.16, 1.0)
        rail_mesh.material = rail_mat
        var bed_mesh := BoxMesh.new()
        bed_mesh.size = Vector3(3.0, 0.12, 1.0)
        bed_mesh.material = bed_mat
        var rails := MultiMesh.new()
        rails.transform_format = MultiMesh.TRANSFORM_3D
        rails.mesh = rail_mesh
        rails.instance_count = segment_count * 2
        var beds := MultiMesh.new()
        beds.transform_format = MultiMesh.TRANSFORM_3D
        beds.mesh = bed_mesh
        beds.instance_count = segment_count
        for i in range(segment_count):
            var za: float = track_min_z + float(i) * segment_length
            var zb: float = minf(za + segment_length, track_max_z)
            var z: float = (za + zb) * 0.5
            var lateral: float = TRACK_PATH.offset(z) if track_index == 0 else 0.0
            var yaw: float = TRACK_PATH.heading(z) if track_index == 0 else 0.0
            var basis := Basis(Vector3.UP, yaw)
            var length_scale := Basis().scaled(Vector3(1.0, 1.0, zb - za))
            for side in range(2):
                var rail_x: float = -rail_center if side == 0 else rail_center
                var rail_position := Vector3(x + lateral, -0.08, z) + basis * Vector3(rail_x, 0.0, 0.0)
                rails.set_instance_transform(i * 2 + side, Transform3D(basis * length_scale, rail_position))
            beds.set_instance_transform(i, Transform3D(basis * length_scale, Vector3(x + lateral, -0.3, z)))
        var rails_instance := MultiMeshInstance3D.new()
        rails_instance.name = "Rails"
        rails_instance.multimesh = rails
        track_root.add_child(rails_instance)
        var beds_instance := MultiMeshInstance3D.new()
        beds_instance.name = "Beds"
        beds_instance.multimesh = beds
        track_root.add_child(beds_instance)
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
            var z: float = track_min_z + float(i) * SLEEPER_PITCH
            var lateral: float = TRACK_PATH.offset(z) if track_index == 0 else 0.0
            var yaw: float = TRACK_PATH.heading(z) if track_index == 0 else 0.0
            multi.set_instance_transform(i, Transform3D(Basis(Vector3.UP, yaw),
                Vector3(x + lateral, -0.2, z)))
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

    # Visible stop target and modest station lighting, with no new assets.
    var marker_mat := _material(Color("#e8e9ee"))
    _box(self, "TrainStopMarker", Vector3(0.18, 0.012, 0.7),
        Vector3(platform_max_x - 0.18, PLATFORM_TOP_Y + 0.012, STOP_Z),
        marker_mat)
    for i in range(6):
        var light := OmniLight3D.new()
        light.name = "PlatformLight%02d" % (i + 1)
        light.position = Vector3(platform_center_x, 4.3,
            platform_center_z - PLATFORM_LENGTH * 0.5 + 8.0 + float(i) * 18.0)
        light.light_color = Color(0.89, 0.94, 1.0)
        light.light_energy = 0.65
        light.omni_range = 13.0
        light.shadow_enabled = false
        add_child(light)

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
