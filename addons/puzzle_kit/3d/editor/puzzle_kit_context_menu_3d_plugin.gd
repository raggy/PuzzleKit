class_name PuzzleKitContextMenu3DPlugin
extends EditorContextMenuPlugin

var editor: PuzzleKitEditor3D

func _popup_menu(paths: PackedStringArray) -> void:
    if paths.size() != 1:
        return
    
    var edited_scene_root := EditorInterface.get_edited_scene_root()
    var selected_node := edited_scene_root.get_node(paths[0])
    if selected_node is Board3D:
        add_context_menu_item("Edit with PuzzleKit", edit_board)

func edit_board(args: Array) -> void:
    if args.size() != 1:
        return
    
    if not args[0] is Board3D:
        return

    var board: Board3D = args[0]
    if board.scene_file_path.is_empty() or EditorInterface.get_edited_scene_root().is_editable_instance(board):
        editor.edit(board)
    else:
        EditorInterface.open_scene_from_path(board.scene_file_path)
