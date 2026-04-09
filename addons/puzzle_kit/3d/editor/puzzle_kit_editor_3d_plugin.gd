@tool
extends EditorPlugin

var _editor_scene := load("res://addons/puzzle_kit/3d/editor/puzzle_kit_editor_3d.tscn") as PackedScene
var _editor: PuzzleKitEditor3D
var _editor_button: Button

func _enable_plugin() -> void:
    pass

func _disable_plugin() -> void:
    pass

func _enter_tree() -> void:
    _editor = _editor_scene.instantiate()
    _editor.undo_redo = get_undo_redo()
    _editor_button = add_control_to_bottom_panel(_editor, "PuzzleKit")
    _editor_button.hide()

func _exit_tree() -> void:
    remove_control_from_bottom_panel(_editor)
    _editor.queue_free()
    _editor = null
    _editor_button = null

func _edit(object: Object) -> void:
    _editor.edit(object as Board3D)

func _handles(object: Object) -> bool:
    return object is Board3D

func _forward_3d_gui_input(viewport_camera: Camera3D, event: InputEvent) -> int:
    return _editor.forward_spatial_input_event(viewport_camera, event)

func _make_visible(visible: bool) -> void:
    if visible:
        if not _editor.mode_buttons_group.get_pressed_button():
            _editor.select_mode_button.button_pressed = true
        _editor._on_tool_mode_changed()
        _editor_button.show()
        make_bottom_panel_item_visible(_editor)
        _editor.set_process(true)
    else:
        _editor_button.hide()
        if _editor.is_visible_in_tree():
            hide_bottom_panel()
        _editor.set_process(false)
