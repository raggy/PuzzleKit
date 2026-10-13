extends Node

var edited_scene_path := ""
var nodes_by_scene_file_path: Dictionary[String, Array] = {}

func _enter_tree() -> void:
    EngineDebugger.register_message_capture("puzzle_kit_3d", _capture)
    EngineDebugger.send_message("puzzle_kit_3d:setup_session", [])

    var scene_tree := get_tree()
    scene_tree.scene_changed.connect(_on_scene_changed)
    scene_tree.node_added.connect(_add_to_cache)

func _exit_tree() -> void:
    EngineDebugger.unregister_message_capture("puzzle_kit_3d")

func _capture(message: String, data: Array) -> bool:
    prints(message, data)
    match message:
        "set_edited_scene":
            if data.size() != 1 or not data[0] is String:
                printerr("Incorrect arguments for %s: %s" % [message, data])
                return false
            edited_scene_path = data[0]
    return true

func _on_scene_changed() -> void:
    _rebuild_scene_cache()

func _rebuild_scene_cache() -> void:
    nodes_by_scene_file_path.clear()
    _add_branch_to_cache(get_tree().current_scene)

func _add_to_cache(node: Node) -> void:
    if node.scene_file_path.is_empty():
        return
    
    if node.scene_file_path in nodes_by_scene_file_path:
        var nodes := nodes_by_scene_file_path[node.scene_file_path]
        nodes.append(node)
    else:
        nodes_by_scene_file_path[node.scene_file_path] = [node]

func _add_branch_to_cache(node: Node) -> void:
    _add_to_cache(node)

    for i in range(node.get_child_count()):
        _add_branch_to_cache(node.get_child(i))

func _remove_from_cache(node: Node) -> void:
    if node.scene_file_path.is_empty():
        return

    if node.scene_file_path in nodes_by_scene_file_path:
        var nodes := nodes_by_scene_file_path[node.scene_file_path]
        nodes.erase(node)
        if nodes.is_empty():
            nodes_by_scene_file_path.erase(node.scene_file_path)
