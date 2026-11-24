extends "res://scripts/station/uruchye_architecture.gd"
## The original rotation logic operates on prepared screens, without construction.
func _ready() -> void:
    _screens.clear()
    for node in find_children("AdvertisingScreen*","MeshInstance3D",true,false):
        var screen := node as MeshInstance3D
        screen.mesh=screen.mesh.duplicate() as Mesh
        (screen.mesh as QuadMesh).material=(screen.mesh as QuadMesh).material.duplicate() as Material
        _screens.append(screen)
