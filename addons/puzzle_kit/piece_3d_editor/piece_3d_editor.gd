@tool
extends EditorPlugin

const piece_3d_tile_editor_scene: PackedScene = preload("res://addons/puzzle_kit/piece_3d_editor/piece_3d_tile_editor.tscn")
const piece_3d_new_tile_scene: PackedScene = preload("res://addons/puzzle_kit/piece_3d_editor/piece_3d_tile_editor.tscn")

var _piece: Piece3D

var _tile_editors: Array[Piece3DTileEditor] = []

func _enter_tree() -> void:
    pass

func _exit_tree() -> void:
    _piece = null
    _stop_editing()

func _handles(object: Object) -> bool:
    if object is Piece3D:
        var piece := object as Piece3D
        return piece.get_parent() is SubViewport
    return false

func _make_visible(visible: bool) -> void:
    pass

func _edit(object: Object) -> void:
    if _piece:
        _stop_editing()

    _piece = object as Piece3D

    if _piece:
        _start_editing()

func _start_editing():
    for tile in _piece.tiles:
        var editor := piece_3d_tile_editor_scene.instantiate()
        editor.position = tile.position
        editor.filled = true
        editor.hovered = false
        tile.add_child(editor)
        _tile_editors.append(editor)

func _stop_editing():
    for editor in _tile_editors:
        editor.queue_free()
    _tile_editors.clear()

func _forward_3d_gui_input(viewport_camera: Camera3D, event: InputEvent) -> int:
    if event is InputEventMouseMotion:
        var mouse_motion_event := event as InputEventMouseMotion
        var hovered_tile_editor: Piece3DTileEditor = null

        # Only hover when no buttons are held
        if mouse_motion_event.button_mask == 0:
            hovered_tile_editor = _get_tile_editor_at_position(viewport_camera, event.position)

        for editor in _tile_editors:
            editor.hovered = editor == hovered_tile_editor

    # if event is InputEventMouseButton:
    #     var mouse_button_event := event as InputEventMouseButton
    #     if mouse_button_event.button_index == MOUSE_BUTTON_LEFT:
    #         print(mouse_button_event.pressed)
    #         return EditorPlugin.AFTER_GUI_INPUT_STOP
    
    return EditorPlugin.AFTER_GUI_INPUT_PASS

func _get_tile_editor_at_position(viewport_camera: Camera3D, viewport_position: Vector2) -> Piece3DTileEditor:
    const RAY_LENGTH := 10000.0
    var space_state := viewport_camera.get_world_3d().direct_space_state
    var origin := viewport_camera.project_ray_origin(viewport_position)
    var normal := viewport_camera.project_ray_normal(viewport_position)
    var query := PhysicsRayQueryParameters3D.create(origin, origin + normal * RAY_LENGTH)
    query.collide_with_areas = true
    var result := space_state.intersect_ray(query)

    # Collided with nothing
    if result.is_empty():
        return null

    for editor in _tile_editors:
        if editor.rigid_body == result.collider:
            print(result.normal)
            return editor
    
    # Collided with something other than an editor's rigid body
    return null
