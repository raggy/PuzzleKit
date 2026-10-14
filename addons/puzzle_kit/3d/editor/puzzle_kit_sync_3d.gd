extends EditorDebuggerPlugin

static var instance: EditorDebuggerPlugin

static var live_debug := true
static var edited_scene: Node: set = set_edited_scene

static var last_path_id: int = 0
static var node_path_cache: Dictionary[NodePath, int] = {}
static var res_path_cache: Dictionary[String, int] = {}

func _init() -> void:
    instance = self
    EditorInterface.get_editor_settings().changed.connect(_update_live_debug_from_editor_settings)
    _update_live_debug_from_editor_settings()

func _update_live_debug_from_editor_settings() -> void:
    live_debug = EditorInterface.get_editor_settings().get_project_metadata("debug_options", "run_live_debug", true)

static func set_edited_scene(value: Node) -> void:
    edited_scene = value
    message_all("puzzle_kit_3d:set_edited_scene", [value.scene_file_path if value else ""])

func _setup_session(_session_id: int) -> void:
    node_path_cache.clear()
    res_path_cache.clear()

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
    print("Sending message %s, %s" % [message, data])
    for session: EditorDebuggerSession in instance.get_sessions():
        if not session.is_active:
            continue
        session.send_message(message, data)

static func instantiate_node(node: Node) -> void:
    if not live_debug:
        return

    message_all("puzzle_kit_3d:live_instantiate_node", [edited_scene.get_path_to(node.get_parent()), node.scene_file_path, node.name])

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

static func property_changed(object: Object, property: StringName, value: Variant) -> void:
    if not live_debug:
        return

    if object is Node:
        var node := object as Node
        var path := edited_scene.get_path_to(node)
        var path_id := _get_node_path_cache(path)

        if value is Resource:
            var resource_value: Resource = value
            message_all("puzzle_kit_3d:live_node_prop_res", [path_id, property, resource_value.resource_path])
        elif value is Node:
            var node_value: Node = value
            var node_value_path := edited_scene.get_path_to(node_value)
            var node_value_path_id := _get_node_path_cache(node_value_path)
            message_all("puzzle_kit_3d:live_node_prop_node", [path_id, property, node_value_path_id])
        else:
            message_all("puzzle_kit_3d:live_node_prop", [path_id, property, value])
        
        return
    
    if object is Resource:
        var resource := object as Resource
        var path := resource.resource_path
        var path_id := _get_res_path_cache(path)

        if value is Resource:
            var resource_value: Resource = value
            message_all("puzzle_kit_3d:live_res_prop_res", [path_id, property, resource_value.resource_path])
        else:
            message_all("puzzle_kit_3d:live_res_prop", [path_id, property, value])
        
        return

static func _get_node_path_cache(path: NodePath) -> int:
    if path in node_path_cache:
        return node_path_cache[path]
    
    last_path_id += 1

    node_path_cache[path] = last_path_id
    message_all("puzzle_kit_3d:live_node_path", [path, last_path_id])

    return last_path_id

static func _get_res_path_cache(path: String) -> int:
    if path in res_path_cache:
        return res_path_cache[path]
    
    last_path_id += 1

    res_path_cache[path] = last_path_id
    message_all("puzzle_kit_3d:live_res_path", [path, last_path_id])

    return last_path_id
