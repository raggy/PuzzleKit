extends EditorDebuggerPlugin

static var instance: EditorDebuggerPlugin
static var live_debug := true

var edited_scene: Node: set = set_edited_scene

static func _static_init() -> void:
    EditorInterface.get_editor_settings().changed.connect(_update_live_debug_from_editor_settings)
    _update_live_debug_from_editor_settings()

    # EditorInterface.get_edited_scene_root()

static func _update_live_debug_from_editor_settings() -> void:
    live_debug = EditorInterface.get_editor_settings().get_project_metadata("debug_options", "run_live_debug", true)

func _init() -> void:
    instance = self

func set_edited_scene(value: Node) -> void:
    edited_scene = value
    message_all("puzzle_kit_3d:set_edited_scene", [value.scene_file_path if value else ""])

func _has_capture(capture: String) -> bool:
    return capture == "puzzle_kit_3d"

@warning_ignore("unused_parameter")
func _capture(message: String, data: Array, session_id: int) -> bool:
    match message:
        "puzzle_kit_3d:setup_session":
            var session := get_session(session_id)
            session.send_message("puzzle_kit_3d:set_edited_scene", [edited_scene.scene_file_path if edited_scene else ""])
            return true
    return false

static func message_all(message: String, data: Array) -> void:
    for session: EditorDebuggerSession in instance.get_sessions():
        if not session.is_active:
            continue
        session.send_message(message, data)

static func instantiate_node(parent: NodePath, path: String, name: String) -> void:
    if not live_debug:
        return
    
    message_all("puzzle_kit_3d:live_instantiate_node", [parent, path, name])

static func remove_node(at: NodePath) -> void:
    if not live_debug:
        return
    
    message_all("puzzle_kit_3d:live_remove_node", [at])

static func remove_and_keep_node(at: NodePath, keep_id: int) -> void:
    if not live_debug:
        return
    
    message_all("puzzle_kit_3d:live_remove_and_keep_node", [at, keep_id])

static func restore_node(id: int, at: NodePath, pos: int) -> void:
    if not live_debug:
        return
    
    message_all("puzzle_kit_3d:live_restore_node", [id, at, pos])

static func reparent_node(at: NodePath, new_place: NodePath, new_name: String, pos: int) -> void:
    if not live_debug:
        return
    
    message_all("puzzle_kit_3d:live_reparent_node", [at, new_place, new_name, pos])
