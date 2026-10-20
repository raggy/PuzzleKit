extends Node

var message_queue: Array
var next_message_id: int

var edited_scene_path := ""

var nodes_by_scene_file_path: Dictionary[String, Array] = {}

var removed_nodes: Dictionary[Node, Dictionary] = {}

var node_path_cache: Dictionary[int, NodePath] = {}
var res_path_cache: Dictionary[int, String] = {}

func _enter_tree() -> void:
    EngineDebugger.register_message_capture("puzzle_kit_3d", _capture)
    EngineDebugger.send_message("puzzle_kit_3d:setup_session", [])

    var scene_tree := get_tree()
    scene_tree.scene_changed.connect(_on_scene_changed)
    scene_tree.node_added.connect(_add_to_cache)

func _exit_tree() -> void:
    EngineDebugger.unregister_message_capture("puzzle_kit_3d")

func _process(_delta: float) -> void:
    _dequeue_messages()

func _capture(message: String, data: Array) -> bool:
    if not data[0] is int:
        printerr("Invalid data in message (data[0] should be int): %s" % data)
        return true
    var message_id: int = data.pop_front()
    if message == "set_current_message_id":
        next_message_id = message_id + 1
    else:
        message_queue.append([message_id, message, data])
    return true

func _dequeue_messages() -> void:
    message_queue.sort_custom(_message_queue_sort)
    while not message_queue.is_empty():
        var message_queue_head: Variant = message_queue.get(0)
        if not message_queue_head is Array:
            printerr("Head of message queue was not an Array: %s" % message_queue_head)
            message_queue.remove_at(0)
            continue
        var message_sequence: Array = message_queue_head
        if not message_sequence[0] is int or not message_sequence[1] is String or not message_sequence[2] is Array:
            printerr("Invalid message sequence in message_queue: %s" % message_sequence)
            message_queue.remove_at(0)
            continue
        if message_sequence[0] != next_message_id:
            # Since message_queue is sorted in ascending order of message_id, if the head is incorrect, we can stop looking for now
            break
        message_queue.remove_at(0)
        var message: String = message_sequence[1]
        var data: Array = message_sequence[2]
        _parse_message(message, data)

func _message_queue_sort(a: Array, b: Array) -> bool:
    if a.is_empty() or b.is_empty() or not a[0] is int or not b[0] is int:
        return false
    return a[0] < b[0]

func _parse_message(message: String, data: Array) -> void:
    # prints(message, data)
    next_message_id += 1
    match message:
        "set_edited_scene":
            if data.size() != 1 or not data[0] is String:
                printerr("Incorrect arguments for %s: %s" % [message, data])
                return
            edited_scene_path = data[0]
        "node_path":
            if data.size() != 2 or not data[0] is NodePath or not data[1] is int:
                printerr("Incorrect arguments for %s: %s" % [message, data])
                return
            var path: NodePath = data[0]
            var path_id: int = data[1]
            node_path_cache[path_id] = path
        "res_path":
            if data.size() != 2 or not data[0] is String or not data[1] is int:
                printerr("Incorrect arguments for %s: %s" % [message, data])
                return
            var path: String = data[0]
            var path_id: int = data[1]
            res_path_cache[path_id] = path
        "instantiate_node_3d":
            if data.size() != 4 or not data[0] is NodePath or not data[1] is String or not data[2] is StringName or not data[3] is Transform3D:
                printerr("Incorrect arguments for %s: %s" % [message, data])
                return
            var parent_node_path: NodePath = data[0]
            var node_scene_file_path: String = data[1]
            var node_name: String = data[2]
            var node_transform: Transform3D = data[3]
            _instantiate_node_3d(parent_node_path, node_scene_file_path, node_name, node_transform)
        "create_board_3d":
            if data.size() != 3 or not data[0] is NodePath or not data[1] is String or not data[2] is int:
                printerr("Incorrect arguments for %s: %s" % [message, data])
                return
            var parent_node_path: NodePath = data[0]
            var board_name: String = data[1]
            var pos: int = data[2]
            _create_board_3d(parent_node_path, board_name, pos)
        "remove_node":
            if data.size() != 1 or not data[0] is NodePath:
                printerr("Incorrect arguments for %s: %s" % [message, data])
                return
            var path: NodePath = data[0]
            _remove_node(path)
        "remove_and_keep_node":
            if data.size() != 2 or not data[0] is NodePath or not data[1] is int:
                printerr("Incorrect arguments for %s: %s" % [message, data])
                return
            var path: NodePath = data[0]
            var keep_id: int = data[1]
            _remove_and_keep_node(path, keep_id)
        "restore_node":
            if data.size() != 2 or not data[0] is int or not data[1] is NodePath:
                printerr("Incorrect arguments for %s: %s" % [message, data])
                return
            var keep_id: int = data[0]
            var parent_node_path: NodePath = data[1]
            _restore_node(keep_id, parent_node_path)
        "reparent_node":
            if data.size() != 3 or not data[0] is NodePath or not data[1] is NodePath or not data[2] is String:
                printerr("Incorrect arguments for %s: %s" % [message, data])
                return
            var node_path: NodePath = data[0]
            var parent_node_path: NodePath = data[1]
            var node_name: String = data[2]
            _reparent_node(node_path, parent_node_path, node_name)
        "reset_piece_state":
            if data.size() != 1 or not data[0] is NodePath:
                printerr("Incorrect arguments for %s: %s" % [message, data])
                return
            var node_path: NodePath = data[0]
            _reset_piece_state(node_path)
        "node_prop_res":
            if data.size() != 3 or not data[0] is int or not data[1] is StringName or not data[2] is String:
                printerr("Incorrect arguments for %s: %s" % [message, data])
                return
            var path_id: int = data[0]
            var property_name: StringName = data[1]
            var value_resource_path: String = data[2]
            _node_prop_res(path_id, property_name, value_resource_path)
        "node_prop_node":
            if data.size() != 3 or not data[0] is int or not data[1] is StringName or not data[2] is int:
                printerr("Incorrect arguments for %s: %s" % [message, data])
                return
            var path_id: int = data[0]
            var property_name: StringName = data[1]
            var value_path_id: int = data[2]
            _node_prop_node(path_id, property_name, value_path_id)
        "node_prop":
            if data.size() != 3 or not data[0] is int or not data[1] is StringName or not data[2] is Variant:
                printerr("Incorrect arguments for %s: %s" % [message, data])
                return
            var path_id: int = data[0]
            var property_name: StringName = data[1]
            var value: Variant = data[2]
            _node_prop(path_id, property_name, value)
        "res_prop_res":
            if data.size() != 3 or not data[0] is int or not data[1] is StringName or not data[2] is String:
                printerr("Incorrect arguments for %s: %s" % [message, data])
                return
            var path_id: int = data[0]
            var property_name: StringName = data[1]
            var value_resource_path: String = data[2]
            _res_prop_res(path_id, property_name, value_resource_path)
        "res_prop":
            if data.size() != 3 or not data[0] is int or not data[1] is StringName or not data[2] is Variant:
                printerr("Incorrect arguments for %s: %s" % [message, data])
                return
            var path_id: int = data[0]
            var property_name: StringName = data[1]
            var value: Variant = data[2]
            _res_prop(path_id, property_name, value)
        "add_to_group":
            if data.size() != 2 or not data[0] is NodePath or not data[1] is StringName:
                printerr("Incorrect arguments for %s: %s" % [message, data])
                return
            var node_path: NodePath = data[0]
            var group: StringName = data[1]
            _add_to_group(node_path, group)
        "remove_from_group":
            if data.size() != 2 or not data[0] is NodePath or not data[1] is StringName:
                printerr("Incorrect arguments for %s: %s" % [message, data])
                return
            var node_path: NodePath = data[0]
            var group: StringName = data[1]
            _remove_from_group(node_path, group)

func _instantiate_node_3d(parent_node_path: NodePath, node_scene_file_path: String, node_name: String, node_transform: Transform3D) -> void:
    var packed_scene := load(node_scene_file_path) as PackedScene
    if not packed_scene:
        printerr("Could not load PackedScene at %s" % node_scene_file_path)
        return
    if not edited_scene_path in nodes_by_scene_file_path:
        return
    var scene_nodes := nodes_by_scene_file_path[edited_scene_path]
    for scene_node: Node in scene_nodes:
        if not scene_node.has_node(parent_node_path):
            printerr("Couldn't find parent node at %s in %s" % [parent_node_path, scene_node])
            continue
        var parent_node := scene_node.get_node(parent_node_path)
        var node := packed_scene.instantiate() as Node3D
        if not node:
            printerr("Could not create Node3D from scene at %s" % node_scene_file_path)
            continue
        node.name = node_name
        node.transform = node_transform
        parent_node.add_child(node)

func _create_board_3d(parent_node_path: NodePath, board_name: String, pos: int) -> void:
    if not edited_scene_path in nodes_by_scene_file_path:
        return
    var scene_nodes := nodes_by_scene_file_path[edited_scene_path]
    for scene_node: Node in scene_nodes:
        if not scene_node.has_node(parent_node_path):
            printerr("Couldn't find parent node at %s in %s" % [parent_node_path, scene_node])
            continue
        var parent_node := scene_node.get_node(parent_node_path)
        var board := Board3D.new()
        board.name = board_name
        parent_node.add_child(board)
        parent_node.move_child(board, pos)

func _remove_node(path: NodePath) -> void:
    if not edited_scene_path in nodes_by_scene_file_path:
        return
    var scene_nodes := nodes_by_scene_file_path[edited_scene_path]
    for scene_node: Node in scene_nodes:
        if not scene_node.has_node(path):
            printerr("Couldn't find node at %s in %s" % [path, scene_node])
            continue
        var node := scene_node.get_node(path)
        if not scene_node.is_ancestor_of(node):
            printerr("Node was not a descendant of %s" % scene_node)
            continue
        node.free()

func _remove_and_keep_node(path: NodePath, keep_id: int) -> void:
    if not edited_scene_path in nodes_by_scene_file_path:
        return
    var scene_nodes := nodes_by_scene_file_path[edited_scene_path]
    for scene_node: Node in scene_nodes:
        if not scene_node.has_node(path):
            printerr("Couldn't find node at %s in %s" % [path, scene_node])
            continue
        var node := scene_node.get_node(path)
        if not scene_node.is_ancestor_of(node):
            printerr("Node was not a descendant of %s" % scene_node)
            continue
        node.get_parent().remove_child(node)
        var removed_nodes_for_scene_node: Dictionary = removed_nodes.get_or_add(scene_node, {})
        removed_nodes_for_scene_node[keep_id] = node

func _restore_node(keep_id: int, parent_node_path: NodePath) -> void:
    if not edited_scene_path in nodes_by_scene_file_path:
        return
    var scene_nodes := nodes_by_scene_file_path[edited_scene_path]
    for scene_node: Node in scene_nodes:
        if not scene_node.has_node(parent_node_path):
            printerr("Couldn't find parent node at %s in %s" % [parent_node_path, scene_node])
            continue
        var parent_node := scene_node.get_node(parent_node_path)
        if not scene_node in removed_nodes:
            printerr("No removed nodes for %s" % scene_node)
            continue
        var removed_nodes_for_scene_node: Dictionary = removed_nodes.get(scene_node)
        if not keep_id in removed_nodes_for_scene_node:
            printerr("Node ID %s not kept for %s" % [keep_id, scene_node])
            continue
        var node: Node = removed_nodes_for_scene_node[keep_id]
        removed_nodes_for_scene_node.erase(keep_id)
        if removed_nodes_for_scene_node.is_empty():
            removed_nodes.erase(scene_node)
        parent_node.add_child(node)

func _reparent_node(node_path: NodePath, parent_node_path: NodePath, node_name: String) -> void:
    if not edited_scene_path in nodes_by_scene_file_path:
        return
    var scene_nodes := nodes_by_scene_file_path[edited_scene_path]
    for scene_node: Node in scene_nodes:
        if not scene_node.has_node(node_path):
            printerr("Couldn't find node at %s in %s" % [node_path, scene_node])
            continue
        if not scene_node.has_node(parent_node_path):
            printerr("Couldn't find parent node at %s in %s" % [parent_node_path, scene_node])
            continue
        var node := scene_node.get_node(node_path)
        if not scene_node.is_ancestor_of(node):
            printerr("Node was not a descendant of %s" % scene_node)
            continue
        var parent_node := scene_node.get_node(parent_node_path)
        if not scene_node.is_ancestor_of(parent_node) and not scene_node == parent_node:
            printerr("Parent node was not a descendant of %s" % scene_node)
            continue
        node.get_parent().remove_child(node)
        node.name = node_name
        parent_node.add_child(node)

func _reset_piece_state(node_path: NodePath) -> void:
    if not edited_scene_path in nodes_by_scene_file_path:
        return
    var scene_nodes := nodes_by_scene_file_path[edited_scene_path]
    for scene_node: Node in scene_nodes:
        if not scene_node.has_node(node_path):
            printerr("Couldn't find node at %s in %s" % [node_path, scene_node])
            continue
        var node := scene_node.get_node(node_path)
        for piece in Piece3D.find_descendant_pieces(node):
            piece._commit_changes()
            if piece.visual:
                piece.visual._reset_cached_state_to_current()
                piece.visual._snap_to_piece_state()

func _node_prop_res(path_id: int, property_name: StringName, value_resource_path: String) -> void:
    if not ResourceLoader.exists(value_resource_path):
        printerr("No resource at path: %s" % value_resource_path)
        return
    var value_resource := ResourceLoader.load(value_resource_path)
    _node_prop(path_id, property_name, value_resource)

func _node_prop_node(path_id: int, property_name: StringName, value_path_id: int) -> void:
    if not path_id in node_path_cache:
        printerr("No node path cached for id: %s" % path_id)
        return
    var path := node_path_cache[path_id]
    if not value_path_id in node_path_cache:
        printerr("No node path cached for id: %s" % value_path_id)
        return
    var value_path := node_path_cache[value_path_id]
    if not edited_scene_path in nodes_by_scene_file_path:
        return
    var scene_nodes := nodes_by_scene_file_path[edited_scene_path]
    for scene_node: Node in scene_nodes:
        if not scene_node.has_node(path):
            printerr("Couldn't find node at %s in %s" % [path, scene_node])
            continue
        var node := scene_node.get_node(path)
        if not scene_node.has_node(value_path):
            printerr("Couldn't find node at %s in %s" % [value_path, scene_node])
            continue
        var value_node := scene_node.get_node(value_path)
        node.set(property_name, value_node)

func _node_prop(path_id: int, property_name: StringName, value: Variant) -> void:
    if not path_id in node_path_cache:
        printerr("No node path cached for id: %s" % path_id)
        return
    var path := node_path_cache[path_id]
    if not edited_scene_path in nodes_by_scene_file_path:
        return
    var scene_nodes := nodes_by_scene_file_path[edited_scene_path]
    for scene_node: Node in scene_nodes:
        if not scene_node.has_node(path):
            printerr("Couldn't find node at %s in %s" % [path, scene_node])
            continue
        var node := scene_node.get_node(path)
        node.set(property_name, value)

func _res_prop_res(path_id: int, property_name: StringName, value_resource_path: String) -> void:
    if not ResourceLoader.exists(value_resource_path):
        printerr("No resource at path: %s" % value_resource_path)
        return
    var value_resource := ResourceLoader.load(value_resource_path)
    _res_prop(path_id, property_name, value_resource)

func _res_prop(path_id: int, property_name: StringName, value: Variant) -> void:
    if not path_id in res_path_cache:
        printerr("No res path cached for id: %s" % path_id)
        return
    var resource_path := res_path_cache[path_id]
    if not ResourceLoader.exists(resource_path):
        printerr("No resource at path: %s" % resource_path)
        return
    var resource := ResourceLoader.load(resource_path)
    resource.set(property_name, value)

func _add_to_group(node_path: NodePath, group: StringName) -> void:
    if not edited_scene_path in nodes_by_scene_file_path:
        return
    var scene_nodes := nodes_by_scene_file_path[edited_scene_path]
    for scene_node: Node in scene_nodes:
        if not scene_node.has_node(node_path):
            printerr("Couldn't find node at %s in %s" % [node_path, scene_node])
            continue
        var node := scene_node.get_node(node_path)
        if not scene_node.is_ancestor_of(node):
            printerr("Node was not a descendant of %s" % scene_node)
            continue
        node.add_to_group(group)
        # Recalculate Piece3D.flags
        if node is Piece3D:
            var piece := node as Piece3D
            piece.flags = GroupFilter.groups_to_flags(piece.get_groups())

func _remove_from_group(node_path: NodePath, group: StringName) -> void:
    if not edited_scene_path in nodes_by_scene_file_path:
        return
    var scene_nodes := nodes_by_scene_file_path[edited_scene_path]
    for scene_node: Node in scene_nodes:
        if not scene_node.has_node(node_path):
            printerr("Couldn't find node at %s in %s" % [node_path, scene_node])
            continue
        var node := scene_node.get_node(node_path)
        if not scene_node.is_ancestor_of(node):
            printerr("Node was not a descendant of %s" % scene_node)
            continue
        node.remove_from_group(group)
        # Recalculate Piece3D.flags
        if node is Piece3D:
            var piece := node as Piece3D
            piece.flags = GroupFilter.groups_to_flags(piece.get_groups())

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
