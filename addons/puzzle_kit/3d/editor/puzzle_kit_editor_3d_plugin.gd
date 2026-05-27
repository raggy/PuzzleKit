@tool
extends EditorPlugin

var _editor_scene := load("res://addons/puzzle_kit/3d/editor/puzzle_kit_editor_3d.tscn") as PackedScene
var _editor: PuzzleKitEditor3D
var _editor_button: Button

var _context_menu: PuzzleKitContextMenu3DPlugin

func _enable_plugin() -> void:
    pass

func _disable_plugin() -> void:
    pass

func _enter_tree() -> void:
    set_input_event_forwarding_always_enabled()

    _editor = _editor_scene.instantiate()
    _editor.undo_redo = get_undo_redo()
    _editor_button = add_control_to_bottom_panel(_editor, "PuzzleKit")

    _context_menu = PuzzleKitContextMenu3DPlugin.new()
    _context_menu.board_edit_requested.connect(_edit_board)
    add_context_menu_plugin(EditorContextMenuPlugin.CONTEXT_SLOT_SCENE_TREE, _context_menu)

func _exit_tree() -> void:
    remove_control_from_bottom_panel(_editor)
    _editor.queue_free()
    _editor = null
    _editor_button = null

    _context_menu.board_edit_requested.disconnect(_edit_board)
    remove_context_menu_plugin(_context_menu)
    _context_menu = null

func _forward_3d_gui_input(viewport_camera: Camera3D, event: InputEvent) -> int:
    return _editor.forward_spatial_input_event(viewport_camera, event)

func _edit_board(board: Board3D) -> void:
    if not board:
        return
    
    make_bottom_panel_item_visible(_editor)

    if board.scene_file_path.is_empty() or EditorInterface.get_edited_scene_root().is_editable_instance(board):
        _editor.edit(board)
        _editor.show()
    else:
        EditorInterface.open_scene_from_path(board.scene_file_path)
        _editor.show()
