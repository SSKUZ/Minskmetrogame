extends Node3D
## Native extruded contour strokes matched to the Russian photo inset; no substituted system font.
const DATA := "res://modules/stations/ploshchad_lenina/art/belarusian_letter_shapes.json"
var tools_by_material: Dictionary={}

func _ready() -> void:
    var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(DATA))
    var bronze := _metal(Color("#ac8c4e"),0.70,0.36)
    var recess := _metal(Color("#68604c"),0.60,0.48)
    var edge := _metal(Color("#403c31"),0.55,0.50)
    for row in data.rows:
        var text: String=row.text
        var advance: float=0.0
        for character in text:advance+=float(data.glyphs[character].width)+0.16
        advance-=0.16
        var sx: float=float(row.width)/(advance+float(data.stroke_width))
        var sy: float=float(row.height)/(0.95+float(data.stroke_width))
        var cursor: float=-advance*sx*0.5
        for character in text:
            var glyph: Dictionary=data.glyphs[character]
            for coordinates in glyph.paths:
                var line := PackedVector2Array()
                for point in coordinates:line.append(Vector2(float(point[0]),float(point[1])))
                # Mitered strokes preserve the channel-like outlines of the reference photograph.
                for part in Geometry2D.offset_polyline(line,float(data.stroke_width)*0.5,Geometry2D.JOIN_MITER,Geometry2D.END_BUTT):
                    var polygon := _placed(part,sx,sy,cursor,float(row.bottom)+sy*float(data.stroke_width)*0.5)
                    _extrude(polygon,0.0,float(data.depth),edge)
                    _extrude(polygon,float(data.depth),float(data.depth)+0.003,bronze)
                for part in Geometry2D.offset_polyline(line,float(data.inner_width)*0.5,Geometry2D.JOIN_MITER,Geometry2D.END_BUTT):
                    _extrude(_placed(part,sx,sy,cursor,float(row.bottom)+sy*float(data.stroke_width)*0.5),float(data.depth)+0.003,float(data.depth)+0.004,recess)
            cursor+=(float(glyph.width)+0.16)*sx
    for mat in tools_by_material:
        var st: SurfaceTool=tools_by_material[mat]
        var mesh := st.commit();mesh.surface_set_material(0,mat)
        var node := MeshInstance3D.new();node.mesh=mesh;node.name="BronzeContourLetters";add_child(node)
    tools_by_material.clear()

func _metal(color: Color,metallic: float,roughness: float) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new();mat.albedo_color=color;mat.metallic=metallic;mat.roughness=roughness;mat.cull_mode=BaseMaterial3D.CULL_DISABLED
    return mat

func _placed(source: PackedVector2Array,sx: float,sy: float,x: float,y: float) -> PackedVector2Array:
    var result := PackedVector2Array()
    for point in source:result.append(Vector2(point.x*sx+x,point.y*sy+y))
    return result

func _extrude(polygon: PackedVector2Array,z0: float,z1: float,mat: Material) -> void:
    if polygon.size()<3:return
    if not tools_by_material.has(mat):
        var st := SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);tools_by_material[mat]=st
    var surface: SurfaceTool=tools_by_material[mat]
    var indices := Geometry2D.triangulate_polygon(polygon)
    for i in range(0,indices.size(),3):
        for k in range(3):
            var point: Vector2=polygon[indices[i+k]]
            surface.set_normal(Vector3.FORWARD);surface.set_uv(point);surface.add_vertex(Vector3(point.x,point.y,z0))
        for k in [2,1,0]:
            var point: Vector2=polygon[indices[i+k]]
            surface.set_normal(Vector3.BACK);surface.set_uv(point);surface.add_vertex(Vector3(point.x,point.y,z1))
    for i in range(polygon.size()):
        var a: Vector2=polygon[i];var b: Vector2=polygon[(i+1)%polygon.size()]
        var normal := Vector3(b.y-a.y,a.x-b.x,0).normalized()
        for point in [Vector3(a.x,a.y,z0),Vector3(b.x,b.y,z0),Vector3(b.x,b.y,z1),Vector3(a.x,a.y,z0),Vector3(b.x,b.y,z1),Vector3(a.x,a.y,z1)]:
            surface.set_normal(normal);surface.set_uv(Vector2(point.x,point.y));surface.add_vertex(point)
