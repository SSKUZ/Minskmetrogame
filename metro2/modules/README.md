# TZ47 — safe modular architecture

Base: `918128859ec26ace688a19b067c5c51b73127568`.
Branch: `feature/metro2-modular-architecture-v47`.
Godot 4.3, Web target. The original main scene and all resource paths remain intact.

## Components

| Catalog key | Scene | Implementation reused |
| --- | --- | --- |
| `v106` | `trains/v106/v106_train.tscn` | Original four-car factory, cab v37, shared doors, lighting, stickers, advertising and passenger equipment |
| `uruchye` | `stations/uruchye/uruchye.tscn` | Inherits the existing route_station_v41 scene without visual overrides |
| `tunnels` | `tunnels/tunnel_system.tscn` | Existing depot_tunnel system and its existing 16 m pool |
| `tunnel_16m` | `tunnels/tunnel_section_16m.tscn` | Same current section builder, fixed single section; no pool processing |
| `depot` | `depot/depot.tscn` | Existing yard, hall, tracks and portal scripts with their original placement |

`core/module_catalog.gd` stores resource paths and loads only the selected scene. It has no train preloads. No GLB, texture or material is duplicated. Existing assets must be restored by the existing preparation process before import, including the archived cab export used by the current workflow.

The train inherits the existing controller. Two composition hooks allow it to omit the old global environment and tunnel creation; legacy defaults are identical. Original train/door physics remains in the old scripts. Original grade/bogie placement is shared in `scripts/depot/v106_route_placement.gd`, called by both the legacy route and the new train. The passenger equipment is initialized after the fourth car, once per train. `consist_ready` signals completion after the deferred fourth car, cab, lights and equipment. Controls and UI remain attached to this component for stage 1; use one active player train.

## Coordinate and connection contract

- One Godot unit equals one metre. +Y is up, travel from depot to station is -Z.
- Keep route/tunnel/train-controller roots at identity transform and scale ONE. Current pool and bogie algorithms use world Z and the existing route height profile. Rotated routes and arbitrary relocated depot profiles are outside stage 1.
- Track centre X is `0.992`. Track markers use the rail datum at Y=0 underground; the train body has the original +0.22 m offset. `spawn_z` sets train distance before adding the train module to the tree. The existing height profile supplies elevation and pitch for each car/bogie.
- Station local Entry Z=92.112, Exit Z=-19.888. Its original route translation Z=-220.112 gives world Entry=-128 and Exit=-240, matching tunnel exclusion boundaries exactly.
- Depot TunnelExit is (0.992,0,96); TrainSpawn track datum is (0.992,6,430). Depot retains all original absolute route dimensions and lights.
- Fixed section connections are (0.992,0,16) and (0.992,0,0); both use +Z basis. To join sections, match position and basis, with no implicit 180-degree rotation. `Catalog.align_connection()` performs this for a fixed section.
- The system scene retains the original route exclusions (portal and Uruchye gap). It creates visible sections when `configure(train,bounds,camera)` is called, normally through `train_module.bind_tunnel(tunnels)` after `consist_ready`. It does not instantiate a train or station.
- A world/environment and global sun belong to the route. Static station/depot scenes keep their own local lights. The train creates neither an environment nor other route modules.

Example route composition, after restoring assets:

```gdscript
const Catalog = preload("res://modules/core/module_catalog.gd")

func _ready() -> void:
    var tunnels := Catalog.create_module("tunnels")
    add_child(tunnels)
    var depot := Catalog.create_module("depot")
    add_child(depot)
    var player := Catalog.create_module("v106")
    player.spawn_z = 430.0
    add_child(player)
    await player.consist_ready
    player.bind_tunnel(tunnels)
    player.attach_station(load(Catalog.SCENES.uruchye),
        Transform3D(Basis.IDENTITY,Vector3(0,0,-220.112)),-210.509)
    player.route_end_distance = -210.509
```

The route can supply `player.route_information` as a Callable returning `current_station`, `next_station` and `at_station`. Without it the passenger equipment receives empty station names, rather than hardcoding a station into the train module. Additional stations can be added as scenes/catalog entries without modifying the train controller. The current tunnel profile still has one fixed station gap; a general route profile is future work.

## Validation and scope

`tests/modular_v47_smoke.gd` checks independent four-car creation, original cab, 64 door leaves, 12 saloon lights, headlights, eight detailed bogies, independent static modules, matching connections, tunnel coverage, a single shared door controller and legacy scene startup. It compares the existing artwork state with the legacy entry point; it does not require or repair missing advertising.

No Web export, APK, Pages publication, visual research, model optimization, resource deletion or TZ48 work is included. Existing Web workflow staging remains unchanged; a future modular build must copy `modules/` along with its dependencies. `viewers/` is reserved, with no viewer implemented at this stage.
