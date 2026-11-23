extends Node3D
## Native grooved tread mesh and MultiMesh poses. The lower opening has two parallel escalators.
var parameters: Dictionary
var direction: float=1.0
var steps: MultiMesh
var phase: float=0.0

func _ready() -> void:
    var mesh := ArrayMesh.new()
    var dark := _material(Color("#42494b"),0.66,0.52)
    var steel := _material(Color("#a8afb0"),0.78,0.30)
    var edge := _material(Color("#c6ad4c"),0.35,0.56)
    var pitch: float=parameters.step_pitch_m
    var width: float=parameters.tread_width_m
    var st := SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
    _box(st,Vector3(width,0.19,pitch-0.004),Vector3(0,-0.095,0))
    st.commit(mesh);mesh.surface_set_material(0,dark)
    st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
    for i in range(39):
        var x: float=-width*0.48+float(i)*width*0.96/38.0
        _box(st,Vector3(0.010,0.006,pitch-0.016),Vector3(x,0.003,0))
        _box(st,Vector3(0.010,0.175,0.006),Vector3(x,-0.09,pitch*0.5-0.003))
    st.commit(mesh);mesh.surface_set_material(1,steel)
    st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
    _box(st,Vector3(width,0.006,0.016),Vector3(0,0.004,pitch*0.5-0.012))
    for side in [-1.0,1.0]:_box(st,Vector3(0.014,0.006,pitch-0.020),Vector3(side*(width*0.5-0.012),0.004,0))
    st.commit(mesh);mesh.surface_set_material(2,edge)
    steps=MultiMesh.new();steps.transform_format=MultiMesh.TRANSFORM_3D;steps.mesh=mesh
    steps.instance_count=int(round(float(parameters.run_m)/pitch))
    var node := MultiMeshInstance3D.new();node.name="MovingGroovedTreads";node.multimesh=steps;add_child(node)
    _poses()

func _process(delta: float) -> void:
    phase=fposmod(phase+direction*float(parameters.belt_speed_mps)*delta,float(parameters.run_m))
    _poses()

func _poses() -> void:
    var run: float=parameters.run_m
    var flat: float=parameters.flat_m
    for i in range(steps.instance_count):
        var distance: float=fposmod((float(i)+0.5)*float(parameters.step_pitch_m)+phase,run)
        var drop: float=clampf((distance-flat)/(run-flat*2.0),0.0,1.0)*float(parameters.rise_m)
        steps.set_instance_transform(i,Transform3D(Basis.IDENTITY,Vector3(0,-drop,-distance)))

func _material(color: Color,metallic: float,roughness: float) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new();mat.albedo_color=color;mat.metallic=metallic;mat.roughness=roughness;return mat

func _box(st: SurfaceTool,size: Vector3,centre: Vector3) -> void:
    var box := BoxMesh.new();box.size=size
    var arrays := box.get_mesh_arrays()
    var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
    var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
    var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
    for index in indices:
        st.set_normal(normals[index]);st.set_uv(Vector2(vertices[index].x,vertices[index].z));st.add_vertex(vertices[index]+centre)
