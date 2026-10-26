extends EditorDebuggerPlugin

static var message_queue: Array

static var last_path_id: int = 0
static var node_path_cache: Dictionary[NodePath, int] = {}
static var res_path_cache: Dictionary[String, int] = {}

var live_debug := true
var next_message_id := 0

func _init() -> void:
    EditorInterface.get_editor_settings().changed.connect(_update_live_debug_from_editor_settings)
    _update_live_debug_from_editor_settings()

    var scene_tree := Engine.get_main_loop() as SceneTree
    scene_tree.process_frame.connect(_dequeue_messages)

func _update_live_debug_from_editor_settings() -> void:
    live_debug = EditorInterface.get_editor_settings().get_project_metadata("debug_options", "run_live_debug", true)

func _dequeue_messages() -> void:
    if not live_debug:
        message_queue.clear()
        return

    while not message_queue.is_empty():
        if message_queue.size() == 1:
            printerr("message_queue had only one element, clearing")
            message_queue.clear()
            break
        if not message_queue[0] is String:
            printerr("Invalid message in message_queue: %s" % message_queue[0])
            message_queue.pop_front()
            message_queue.pop_front()
            continue
        if not message_queue[1] is Array:
            printerr("Invalid data in message_queue: %s" % message_queue[1])
            message_queue.pop_front()
            message_queue.pop_front()
            continue
        var message: String = message_queue.pop_front()
        var data: Array = message_queue.pop_front()
        data.push_front(next_message_id)
        next_message_id += 1
        for session: EditorDebuggerSession in get_sessions():
            if not session.is_active:
                continue
            session.send_message(message, data)

func set_edited_scene(value: Node) -> void:
    queue_message("puzzle_kit_3d:set_edited_scene", [value.scene_file_path if value else ""])

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
            var edited_scene := EditorInterface.get_edited_scene_root()
            session.send_message("puzzle_kit_3d:set_current_message_id", [next_message_id])
            next_message_id += 1
            session.send_message("puzzle_kit_3d:set_edited_scene", [next_message_id, edited_scene.scene_file_path if edited_scene else ""])
            next_message_id += 1
            return true
    return false

static func queue_message(message: String, data: Array) -> void:
    message_queue.append(message)
    message_queue.append(data)

static func instantiate_node_3d(node: Node3D) -> void:
    queue_message("puzzle_kit_3d:instantiate_node_3d", [EditorInterface.get_edited_scene_root().get_path_to(node.get_parent()), node.scene_file_path, node.name, node.transform])

static func create_board_3d(parent_node_path: NodePath, board_name: String, pos: int) -> void:
    queue_message("puzzle_kit_3d:create_board_3d", [parent_node_path, board_name, pos])

static func remove_node(node: Node) -> void:
    queue_message("puzzle_kit_3d:remove_node", [EditorInterface.get_edited_scene_root().get_path_to(node)])

static func remove_and_keep_node(at: NodePath, node_id: int) -> void:
    queue_message("puzzle_kit_3d:remove_and_keep_node", [at, node_id])

static func restore_node(node_id: int, parent_node_path: NodePath) -> void:
    queue_message("puzzle_kit_3d:restore_node", [node_id, parent_node_path])

static func reparent_node(at: NodePath, new_place: NodePath, new_name: String) -> void:
    queue_message("puzzle_kit_3d:reparent_node", [at, new_place, new_name])

static func reset_piece_state(at: NodePath) -> void:
    queue_message("puzzle_kit_3d:reset_piece_state", [at])

static func property_changed(object: Object, property: StringName, value: Variant) -> void:
    if object is Node:
        var node := object as Node
        var path := EditorInterface.get_edited_scene_root().get_path_to(node)
        var path_id := _get_node_path_cache(path)

        if value is Resource:
            var resource_value: Resource = value
            queue_message("puzzle_kit_3d:node_prop_res", [path_id, property, resource_value.resource_path])
        elif value is Node:
            var node_value: Node = value
            var node_value_path := EditorInterface.get_edited_scene_root().get_path_to(node_value)
            var node_value_path_id := _get_node_path_cache(node_value_path)
            queue_message("puzzle_kit_3d:node_prop_node", [path_id, property, node_value_path_id])
        else:
            queue_message("puzzle_kit_3d:node_prop", [path_id, property, value])
        
        return
    
    if object is Resource:
        var resource := object as Resource
        var path := resource.resource_path
        var path_id := _get_res_path_cache(path)

        if value is Resource:
            var resource_value: Resource = value
            queue_message("puzzle_kit_3d:res_prop_res", [path_id, property, resource_value.resource_path])
        else:
            queue_message("puzzle_kit_3d:res_prop", [path_id, property, value])
        
        return

static func add_to_group(node: Node, group: StringName) -> void:
    queue_message("puzzle_kit_3d:add_to_group", [EditorInterface.get_edited_scene_root().get_path_to(node), group])

static func remove_from_group(node: Node, group: StringName) -> void:
    queue_message("puzzle_kit_3d:remove_from_group", [EditorInterface.get_edited_scene_root().get_path_to(node), group])

static func _get_node_path_cache(path: NodePath) -> int:
    if path in node_path_cache:
        return node_path_cache[path]
    
    last_path_id += 1

    node_path_cache[path] = last_path_id
    queue_message("puzzle_kit_3d:node_path", [path, last_path_id])

    return last_path_id

static func _get_res_path_cache(path: String) -> int:
    if path in res_path_cache:
        return res_path_cache[path]
    
    last_path_id += 1

    res_path_cache[path] = last_path_id
    queue_message("puzzle_kit_3d:res_path", [path, last_path_id])

    return last_path_id
