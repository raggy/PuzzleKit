extends Node3D

var _mesh: ArrayMesh
var _mesh_instance: MeshInstance3D

var _node_generated_from: WeakRef

var fill_material: Material: set = set_fill_material
var outline_material: Material: set = set_outline_material
var outline_xray_material: Material: set = set_outline_xray_material

func _init() -> void:
    _mesh = ArrayMesh.new()
    _mesh_instance = MeshInstance3D.new()
    _mesh_instance.mesh = _mesh
    add_child(_mesh_instance)

func generate_from(node: Node3D, force: bool = false) -> void:
    if not node:
        _mesh.clear_surfaces()   
        return

    if not force and _node_generated_from and node == _node_generated_from.get_ref():
        return
    # Save a reference to node so we can skip redundant regenerations
    _node_generated_from = weakref(node)

    _mesh.clear_surfaces()    

    var pieces: Array[Piece3D] = []
    Piece3D.find_descendant_pieces(node, pieces)

    if pieces.is_empty():
        return

    var start := pieces[0].grid_position
    var end := start
    var cells: Dictionary[Vector3i, int] = { start: 1 }

    for i in range(1, pieces.size()):
        var piece_position := pieces[i].grid_position
        start = start.min(piece_position)
        end = end.max(piece_position)
        if piece_position in cells:
            cells[piece_position] = cells[piece_position] + 1
        else:
            cells[piece_position] = 1

    var lines_surface_array := []
    lines_surface_array.resize(Mesh.ARRAY_MAX)
    var lines_verts := PackedVector3Array()
    var lines_indices := PackedInt32Array()
    var lines_verts_to_indices: Dictionary[Vector3, int] = {}

    var triangles_surface_array := []
    triangles_surface_array.resize(Mesh.ARRAY_MAX)
    var triangles_verts := PackedVector3Array()
    var triangles_indices := PackedInt32Array()
    var triangles_verts_to_indices: Dictionary[Vector3, int] = {}
    
    for x in range(start.x - 1, end.x + 1):
        for y in range(start.y - 1, end.y + 1):
            for z in range(start.z - 1, end.z + 1):
                var here := Vector3i(x, y, z)
                var c_here := here in cells
                var c_r := (here + Vector3i.RIGHT) in cells
                var c_u := (here + Vector3i.UP) in cells
                var c_b := (here + Vector3i.BACK) in cells
                var c_ru := (here + Vector3i.RIGHT + Vector3i.UP) in cells
                var c_rb := (here + Vector3i.RIGHT + Vector3i.BACK) in cells
                var c_ub := (here + Vector3i.UP + Vector3i.BACK) in cells

                # Add lines
                if ((c_here or c_ru) and not c_r and not c_u) \
                or (not c_here and not c_ru and (c_r or c_u)):
                    add_vert(node.to_local(Vector3(here) + Vector3( 0.5,  0.5,  0.5)), lines_verts, lines_indices, lines_verts_to_indices)
                    add_vert(node.to_local(Vector3(here) + Vector3( 0.5,  0.5, -0.5)), lines_verts, lines_indices, lines_verts_to_indices)
                if ((c_here or c_rb) and not c_r and not c_b) \
                or (not c_here and not c_rb and (c_r or c_b)):
                    add_vert(node.to_local(Vector3(here) + Vector3( 0.5,  0.5,  0.5)), lines_verts, lines_indices, lines_verts_to_indices)
                    add_vert(node.to_local(Vector3(here) + Vector3( 0.5, -0.5,  0.5)), lines_verts, lines_indices, lines_verts_to_indices)
                if ((c_here or c_ub) and not c_u and not c_b) \
                or (not c_here and not c_ub and (c_u or c_b)):
                    add_vert(node.to_local(Vector3(here) + Vector3( 0.5,  0.5,  0.5)), lines_verts, lines_indices, lines_verts_to_indices)
                    add_vert(node.to_local(Vector3(here) + Vector3(-0.5,  0.5,  0.5)), lines_verts, lines_indices, lines_verts_to_indices)
                
                # Add faces
                if c_here and not c_r:
                    add_vert(node.to_local(Vector3(here) + Vector3( 0.5,  0.5,  0.5)), triangles_verts, triangles_indices, triangles_verts_to_indices)
                    add_vert(node.to_local(Vector3(here) + Vector3( 0.5,  0.5, -0.5)), triangles_verts, triangles_indices, triangles_verts_to_indices)
                    add_vert(node.to_local(Vector3(here) + Vector3( 0.5, -0.5, -0.5)), triangles_verts, triangles_indices, triangles_verts_to_indices)
                    add_vert(node.to_local(Vector3(here) + Vector3( 0.5, -0.5, -0.5)), triangles_verts, triangles_indices, triangles_verts_to_indices)
                    add_vert(node.to_local(Vector3(here) + Vector3( 0.5, -0.5,  0.5)), triangles_verts, triangles_indices, triangles_verts_to_indices)
                    add_vert(node.to_local(Vector3(here) + Vector3( 0.5,  0.5,  0.5)), triangles_verts, triangles_indices, triangles_verts_to_indices)
                elif not c_here and c_r:
                    add_vert(node.to_local(Vector3(here) + Vector3( 0.5,  0.5,  0.5)), triangles_verts, triangles_indices, triangles_verts_to_indices)
                    add_vert(node.to_local(Vector3(here) + Vector3( 0.5, -0.5, -0.5)), triangles_verts, triangles_indices, triangles_verts_to_indices)
                    add_vert(node.to_local(Vector3(here) + Vector3( 0.5,  0.5, -0.5)), triangles_verts, triangles_indices, triangles_verts_to_indices)
                    add_vert(node.to_local(Vector3(here) + Vector3( 0.5, -0.5, -0.5)), triangles_verts, triangles_indices, triangles_verts_to_indices)
                    add_vert(node.to_local(Vector3(here) + Vector3( 0.5,  0.5,  0.5)), triangles_verts, triangles_indices, triangles_verts_to_indices)
                    add_vert(node.to_local(Vector3(here) + Vector3( 0.5, -0.5,  0.5)), triangles_verts, triangles_indices, triangles_verts_to_indices)
                if c_here and not c_u:
                    add_vert(node.to_local(Vector3(here) + Vector3( 0.5,  0.5,  0.5)), triangles_verts, triangles_indices, triangles_verts_to_indices)
                    add_vert(node.to_local(Vector3(here) + Vector3(-0.5,  0.5, -0.5)), triangles_verts, triangles_indices, triangles_verts_to_indices)
                    add_vert(node.to_local(Vector3(here) + Vector3( 0.5,  0.5, -0.5)), triangles_verts, triangles_indices, triangles_verts_to_indices)
                    add_vert(node.to_local(Vector3(here) + Vector3(-0.5,  0.5, -0.5)), triangles_verts, triangles_indices, triangles_verts_to_indices)
                    add_vert(node.to_local(Vector3(here) + Vector3( 0.5,  0.5,  0.5)), triangles_verts, triangles_indices, triangles_verts_to_indices)
                    add_vert(node.to_local(Vector3(here) + Vector3(-0.5,  0.5,  0.5)), triangles_verts, triangles_indices, triangles_verts_to_indices)
                elif not c_here and c_u:
                    add_vert(node.to_local(Vector3(here) + Vector3( 0.5,  0.5,  0.5)), triangles_verts, triangles_indices, triangles_verts_to_indices)
                    add_vert(node.to_local(Vector3(here) + Vector3( 0.5,  0.5, -0.5)), triangles_verts, triangles_indices, triangles_verts_to_indices)
                    add_vert(node.to_local(Vector3(here) + Vector3(-0.5,  0.5, -0.5)), triangles_verts, triangles_indices, triangles_verts_to_indices)
                    add_vert(node.to_local(Vector3(here) + Vector3(-0.5,  0.5, -0.5)), triangles_verts, triangles_indices, triangles_verts_to_indices)
                    add_vert(node.to_local(Vector3(here) + Vector3(-0.5,  0.5,  0.5)), triangles_verts, triangles_indices, triangles_verts_to_indices)
                    add_vert(node.to_local(Vector3(here) + Vector3( 0.5,  0.5,  0.5)), triangles_verts, triangles_indices, triangles_verts_to_indices)
                if c_here and not c_b:
                    add_vert(node.to_local(Vector3(here) + Vector3( 0.5,  0.5,  0.5)), triangles_verts, triangles_indices, triangles_verts_to_indices)
                    add_vert(node.to_local(Vector3(here) + Vector3( 0.5, -0.5,  0.5)), triangles_verts, triangles_indices, triangles_verts_to_indices)
                    add_vert(node.to_local(Vector3(here) + Vector3(-0.5, -0.5,  0.5)), triangles_verts, triangles_indices, triangles_verts_to_indices)
                    add_vert(node.to_local(Vector3(here) + Vector3(-0.5, -0.5,  0.5)), triangles_verts, triangles_indices, triangles_verts_to_indices)
                    add_vert(node.to_local(Vector3(here) + Vector3(-0.5,  0.5,  0.5)), triangles_verts, triangles_indices, triangles_verts_to_indices)
                    add_vert(node.to_local(Vector3(here) + Vector3( 0.5,  0.5,  0.5)), triangles_verts, triangles_indices, triangles_verts_to_indices)
                elif not c_here and c_b:
                    add_vert(node.to_local(Vector3(here) + Vector3( 0.5,  0.5,  0.5)), triangles_verts, triangles_indices, triangles_verts_to_indices)
                    add_vert(node.to_local(Vector3(here) + Vector3(-0.5, -0.5,  0.5)), triangles_verts, triangles_indices, triangles_verts_to_indices)
                    add_vert(node.to_local(Vector3(here) + Vector3( 0.5, -0.5,  0.5)), triangles_verts, triangles_indices, triangles_verts_to_indices)
                    add_vert(node.to_local(Vector3(here) + Vector3(-0.5, -0.5,  0.5)), triangles_verts, triangles_indices, triangles_verts_to_indices)
                    add_vert(node.to_local(Vector3(here) + Vector3( 0.5,  0.5,  0.5)), triangles_verts, triangles_indices, triangles_verts_to_indices)
                    add_vert(node.to_local(Vector3(here) + Vector3(-0.5,  0.5,  0.5)), triangles_verts, triangles_indices, triangles_verts_to_indices)

    lines_surface_array[Mesh.ARRAY_VERTEX] = lines_verts
    lines_surface_array[Mesh.ARRAY_INDEX] = lines_indices
    _mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, lines_surface_array)
    _mesh.surface_set_material(0, outline_material)

    _mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, lines_surface_array)
    _mesh.surface_set_material(1, outline_xray_material)
    
    triangles_surface_array[Mesh.ARRAY_VERTEX] = triangles_verts
    triangles_surface_array[Mesh.ARRAY_INDEX] = triangles_indices
    _mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, triangles_surface_array)
    _mesh.surface_set_material(2, fill_material)

func set_fill_material(value: Material) -> void:
    if _mesh and _mesh.get_surface_count() >= 3:
        _mesh.surface_set_material(2, value)
    fill_material = value

func set_outline_material(value: Material) -> void:
    if _mesh and _mesh.get_surface_count() >= 1:
        _mesh.surface_set_material(0, value)
    outline_material = value

func set_outline_xray_material(value: Material) -> void:
    if _mesh and _mesh.get_surface_count() >= 2:
        _mesh.surface_set_material(1, value)
    outline_xray_material = value

static func add_vert(vert: Vector3, verts: PackedVector3Array, indices: PackedInt32Array, verts_to_indices: Dictionary[Vector3, int]) -> void:
    indices.append(vert_to_index(vert, verts, verts_to_indices))

static func vert_to_index(vert: Vector3, verts: PackedVector3Array, verts_to_indices: Dictionary[Vector3, int]) -> int:
    if vert in verts_to_indices:
        return verts_to_indices[vert]
    # Add new vert
    var index := verts.size()
    verts.append(vert)
    verts_to_indices[vert] = index
    return index
