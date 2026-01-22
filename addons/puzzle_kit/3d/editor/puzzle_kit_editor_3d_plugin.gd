@tool
extends EditorPlugin

var _editor: PuzzleKitEditor3D
var _editor_button: Button

func _enable_plugin() -> void:
    pass

func _disable_plugin() -> void:
    pass

func _enter_tree() -> void:
    _editor = PuzzleKitEditor3D.new()
    _editor_button = add_control_to_bottom_panel(_editor, "Board3D")
    _editor_button.hide()

func _exit_tree() -> void:
    remove_control_from_bottom_panel(_editor)
    _editor.queue_free()
    _editor = null
    _editor_button = null

func _edit(object: Object) -> void:
    _editor.edit(object as Board3D)

    if object:
        _editor_button.show()
    else:
        _editor_button.hide()

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
