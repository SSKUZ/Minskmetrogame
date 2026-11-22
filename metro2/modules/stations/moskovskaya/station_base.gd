extends Node3D
## Station-local Station Base adaptation; coordinates, gauge and connection datum retained.
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

@export var station_id := "station"
@export var track_min_z := TRACK_MIN_Z
@export var track_max_z := TRACK_MAX_Z
@export var rail_center := 0.9
@export var rail_width := 0.12


func _ready() -> void:
    var platform_center_z := TRAIN_LENGTH / 2.0
    var platform_max_x := PLATFORM_CENTER_X + PLATFORM_WIDTH / 2.0
    var platform_min_x := platform_max_x - PLATFORM_WIDTH
    # Running rails and sleepers use the detailed Uruchye builder below.
    # Do not construct the former box rails or plain sleeper geometry.
    var platform_mat := _material(Color("#9aabb4"))
    var edge_mat := _material(Color("#f3b948"))

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

    var infrastructure := preload("res://scripts/infrastructure/station_infrastructure.gd").new()
    infrastructure.name = "StationInfrastructure"
    infrastructure.station_id = station_id
    infrastructure.track_min_z = track_min_z
    infrastructure.track_max_z = track_max_z
    infrastructure.portal_min_z = -12.888
    infrastructure.portal_max_z = 92.112
    add_child(infrastructure)

    var tracks := preload("res://modules/stations/moskovskaya/trackwork.gd").new()
    tracks.name="DetailedMoskovskayaTrackwork"
    add_child(tracks)
    tracks.build(track_min_z,track_max_z)

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
