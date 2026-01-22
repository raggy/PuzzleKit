@tool
class_name PuzzleKitEditor3D
extends VBoxContainer

var _board: Board3D

var _debug_material: StandardMaterial3D
var _debug_mesh: ArrayMesh
var _debug_mesh_instance: MeshInstance3D

var palette: FlowContainer

func _enter_tree() -> void:
    _debug_material = StandardMaterial3D.new()
    _debug_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    _debug_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    _debug_material.vertex_color_is_srgb = true
    # _debug_material.vertex_color_use_as_albedo = true
    _debug_material.disable_fog = true
    _debug_material.albedo_color = Color.WHITE

    _debug_mesh = ArrayMesh.new()
    _debug_mesh_instance = MeshInstance3D.new()
    _debug_mesh_instance.mesh = _debug_mesh
    add_child(_debug_mesh_instance)


func edit(board: Board3D) -> void:
    _board = board
    if not _board:
        return
    _build_palette()

func _build_palette() -> void:
    if not _board:
        return

func preview_raycast(from: Vector3, direction: Vector3) -> void:
    _debug_mesh.clear_surfaces()

    var points := _board.raycast_points(from, direction)

    if points.is_empty():
        return

    var surface_array := []
    surface_array.resize(Mesh.ARRAY_MAX)

    var verts := PackedVector3Array()
    var indices := PackedInt32Array()

    for point in points:
        add_cube(point, verts, indices)

    surface_array[Mesh.ARRAY_VERTEX] = verts
    surface_array[Mesh.ARRAY_INDEX] = indices

    _debug_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, surface_array)
    _debug_mesh.surface_set_material(0, _debug_material)

func add_cube(center: Vector3, verts: PackedVector3Array, indices: PackedInt32Array) -> void:
    var offset := verts.size()

    verts.append(center + Vector3( 0.5,  0.5,  0.5)) # 0 Right, top, back
    verts.append(center + Vector3(-0.5,  0.5,  0.5)) # 1 Left, top, back
    verts.append(center + Vector3( 0.5, -0.5,  0.5)) # 2 Right, bottom, back
    verts.append(center + Vector3(-0.5, -0.5,  0.5)) # 3 Left, bottom, back
    verts.append(center + Vector3( 0.5,  0.5, -0.5)) # 4 Right, top, front
    verts.append(center + Vector3(-0.5,  0.5, -0.5)) # 5 Left, top, front
    verts.append(center + Vector3( 0.5, -0.5, -0.5)) # 6 Right, bottom, front
    verts.append(center + Vector3(-0.5, -0.5, -0.5)) # 7 Left, bottom, front

    indices.append(offset +  0)
    indices.append(offset +  1)
    indices.append(offset +  2)
    indices.append(offset +  3)
    indices.append(offset +  4)
    indices.append(offset +  5)
    indices.append(offset +  6)
    indices.append(offset +  7)

    indices.append(offset +  0)
    indices.append(offset +  2)
    indices.append(offset +  1)
    indices.append(offset +  3)
    indices.append(offset +  4)
    indices.append(offset +  6)
    indices.append(offset +  5)
    indices.append(offset +  7)

    indices.append(offset +  0)
    indices.append(offset +  4)
    indices.append(offset +  1)
    indices.append(offset +  5)
    indices.append(offset +  2)
    indices.append(offset +  6)
    indices.append(offset +  3)
    indices.append(offset +  7)
