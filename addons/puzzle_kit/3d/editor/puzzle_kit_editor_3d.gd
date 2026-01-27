@tool
class_name PuzzleKitEditor3D
extends VBoxContainer

@export var palette: ItemList

var _board: Board3D

var _debug_material: StandardMaterial3D
var _debug_mesh: ArrayMesh
var _debug_mesh_instance: MeshInstance3D

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
    _update_palette()

func _update_palette() -> void:
    palette.clear()

    _add_to_palette_from_dir("res://")

func _add_to_palette_from_dir(path: String) -> void:
    for filename in DirAccess.get_files_at(path):
        if not filename.ends_with(".tscn"):
            # Only interested in scenes
            continue
        var file_path := path.path_join(filename)
        var packed_scene := load(file_path) as PackedScene
        if not packed_scene:
            # Failed to load scene
            continue
        var scene_state := packed_scene.get_state()
        if scene_state.get_node_type(0) != "Node3D":
            # Only interested in scenes with Node3D root nodes
            continue
        EditorInterface.get_resource_previewer().queue_resource_preview(file_path, self, "_add_palette_item", null)
    for dir_name in DirAccess.get_directories_at(path):
        if dir_name.begins_with("."):
            # Ignore hidden directories
            continue
        _add_to_palette_from_dir(path.path_join(dir_name))

func _add_palette_item(path: String, preview: Texture2D, _thumbnail_preview: Texture2D, _userdata: Variant) -> void:
    palette.add_item(path, preview)

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
