class_name TileOutline3D
extends Node3D

var _mesh: ArrayMesh
var _mesh_instance: MeshInstance3D

var axis: Vector3.Axis = Vector3.AXIS_Y: set = set_axis
var flipped: bool = false: set = set_flipped
var fill_material: Material: set = set_fill_material
var outline_material: Material: set = set_outline_material

func _init() -> void:
    _mesh = ArrayMesh.new()
    _mesh_instance = MeshInstance3D.new()
    _mesh_instance.mesh = _mesh
    add_child(_mesh_instance)

    var lines_surface_array := []
    lines_surface_array.resize(Mesh.ARRAY_MAX)
    var lines_verts := PackedVector3Array()
    var lines_indices := PackedInt32Array()

    lines_verts.append(Vector3(-0.5, -0.5, -0.5))
    lines_verts.append(Vector3( 0.5, -0.5, -0.5))
    lines_verts.append(Vector3( 0.5, -0.5,  0.5))
    lines_verts.append(Vector3(-0.5, -0.5,  0.5))
    lines_indices.append(0)
    lines_indices.append(1)
    lines_indices.append(2)
    lines_indices.append(3)
    lines_indices.append(0)

    lines_surface_array[Mesh.ARRAY_VERTEX] = lines_verts
    lines_surface_array[Mesh.ARRAY_INDEX] = lines_indices
    _mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINE_STRIP, lines_surface_array)
    _mesh.surface_set_material(0, outline_material)

    var triangles_surface_array := []
    triangles_surface_array.resize(Mesh.ARRAY_MAX)
    var triangles_verts := PackedVector3Array()
    var triangles_indices := PackedInt32Array()

    triangles_verts.append(Vector3(-0.5, -0.5, -0.5))
    triangles_verts.append(Vector3( 0.5, -0.5, -0.5))
    triangles_verts.append(Vector3(-0.5, -0.5,  0.5))
    triangles_verts.append(Vector3( 0.5, -0.5,  0.5))
    triangles_indices.append(0)
    triangles_indices.append(1)
    triangles_indices.append(2)
    triangles_indices.append(3)
    
    triangles_surface_array[Mesh.ARRAY_VERTEX] = triangles_verts
    triangles_surface_array[Mesh.ARRAY_INDEX] = triangles_indices
    _mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLE_STRIP, triangles_surface_array)
    _mesh.surface_set_material(1, fill_material)

func _update_rotation() -> void:
    quaternion = Quaternion.IDENTITY
    match axis:
        Vector3.AXIS_X: rotate_object_local(Vector3.BACK, PI/2 if flipped else -PI/2)
        Vector3.AXIS_Y: if flipped: rotate_object_local(Vector3.BACK, PI)
        Vector3.AXIS_Z: rotate_object_local(Vector3.RIGHT, -PI/2 if flipped else PI/2)

func set_axis(value: Vector3.Axis) -> void:
    if axis == value:
        return
    axis = value
    _update_rotation()

func set_flipped(value: bool) -> void:
    if flipped == value:
        return
    flipped = value
    _update_rotation()

func set_fill_material(value: Material) -> void:
    if _mesh and _mesh.get_surface_count() >= 2:
        _mesh.surface_set_material(1, value)
    fill_material = value

func set_outline_material(value: Material) -> void:
    if _mesh and _mesh.get_surface_count() >= 1:
        _mesh.surface_set_material(0, value)
    outline_material = value

static func create_preview_material(color: Color) -> BaseMaterial3D:
    var material := StandardMaterial3D.new()
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    material.disable_fog = true
    material.albedo_color = color
    return material
