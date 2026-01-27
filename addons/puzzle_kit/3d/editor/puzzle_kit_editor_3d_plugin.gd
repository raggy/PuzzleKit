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
    _editor_button = add_control_to_bottom_panel(_editor, "Board3D")
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
    if event is InputEventMouseMotion:
        var motion_event := event as InputEventMouseMotion
        _editor.preview_raycast(viewport_camera.project_ray_origin(motion_event.position), viewport_camera.project_ray_normal(motion_event.position))
    if event is InputEventMouseButton:
        var button_event := event as InputEventMouseButton
        if button_event.pressed and button_event.button_index == MOUSE_BUTTON_RIGHT:
            print(_editor._board.raycast_piece(viewport_camera.project_ray_origin(button_event.position), viewport_camera.project_ray_normal(button_event.position)))
            return EditorPlugin.AFTER_GUI_INPUT_STOP
    return EditorPlugin.AFTER_GUI_INPUT_PASS

func _make_visible(visible: bool) -> void:
    if visible:
        _editor_button.show()
        make_bottom_panel_item_visible(_editor)
        _editor.set_process(true)
    else:
        _editor_button.hide()
        if _editor.is_visible_in_tree():
            hide_bottom_panel()
        _editor.set_process(false)
