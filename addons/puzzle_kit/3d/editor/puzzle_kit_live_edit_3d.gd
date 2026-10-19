extends Node

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

func _capture(message: String, data: Array) -> bool:
    prints(message, data)
    match message:
        "set_edited_scene":
            if data.size() != 1 or not data[0] is String:
                printerr("Incorrect arguments for %s: %s" % [message, data])
                return true
            edited_scene_path = data[0]
            return true
        "node_path":
            if data.size() != 2 or not data[0] is NodePath or not data[1] is int:
                printerr("Incorrect arguments for %s: %s" % [message, data])
                return true
            var path: NodePath = data[0]
            var path_id: int = data[1]
            node_path_cache[path_id] = path
            return true
        "res_path":
            if data.size() != 2 or not data[0] is String or not data[1] is int:
                printerr("Incorrect arguments for %s: %s" % [message, data])
                return true
            var path: String = data[0]
            var path_id: int = data[1]
            res_path_cache[path_id] = path
            return true
        "instantiate_node_3d":
            if data.size() != 4 or not data[0] is NodePath or not data[1] is String or not data[2] is StringName or not data[3] is Transform3D:
                printerr("Incorrect arguments for %s: %s" % [message, data])
                return true
            var parent_node_path: NodePath = data[0]
            var node_scene_file_path: String = data[1]
            var node_name: String = data[2]
            var node_transform: Transform3D = data[3]
            _instantiate_node_3d(parent_node_path, node_scene_file_path, node_name, node_transform)
            return true
        "remove_node":
            if data.size() != 1 or not data[0] is NodePath:
                printerr("Incorrect arguments for %s: %s" % [message, data])
                return true
            var path: NodePath = data[0]
            _remove_node(path)
        "remove_and_keep_node":
            if data.size() != 2 or not data[0] is NodePath or not data[1] is int:
                printerr("Incorrect arguments for %s: %s" % [message, data])
                return true
            var path: NodePath = data[0]
            var keep_id: int = data[1]
            _remove_and_keep_node(path, keep_id)
        "node_prop_res":
            if data.size() != 3 or not data[0] is int or not data[1] is StringName or not data[2] is String:
                printerr("Incorrect arguments for %s: %s" % [message, data])
                return true
            var path_id: int = data[0]
            var property_name: StringName = data[1]
            var value_resource_path: String = data[2]
            _node_prop_res(path_id, property_name, value_resource_path)
        "node_prop_node":
            if data.size() != 3 or not data[0] is int or not data[1] is StringName or not data[2] is int:
                printerr("Incorrect arguments for %s: %s" % [message, data])
                return true
            var path_id: int = data[0]
            var property_name: StringName = data[1]
            var value_path_id: int = data[2]
            _node_prop_node(path_id, property_name, value_path_id)
        "node_prop":
            if data.size() != 3 or not data[0] is int or not data[1] is StringName or not data[2] is Variant:
                printerr("Incorrect arguments for %s: %s" % [message, data])
                return true
            var path_id: int = data[0]
            var property_name: StringName = data[1]
            var value: Variant = data[2]
            _node_prop(path_id, property_name, value)
        "res_prop_res":
            if data.size() != 3 or not data[0] is int or not data[1] is StringName or not data[2] is String:
                printerr("Incorrect arguments for %s: %s" % [message, data])
                return true
            var path_id: int = data[0]
            var property_name: StringName = data[1]
            var value_resource_path: String = data[2]
            _res_prop_res(path_id, property_name, value_resource_path)
        "res_prop":
            if data.size() != 3 or not data[0] is int or not data[1] is StringName or not data[2] is Variant:
                printerr("Incorrect arguments for %s: %s" % [message, data])
                return true
            var path_id: int = data[0]
            var property_name: StringName = data[1]
            var value: Variant = data[2]
            _res_prop(path_id, property_name, value)

    return false

func _instantiate_node_3d(parent_node_path: NodePath, node_scene_file_path: String, node_name: String, node_transform: Transform3D) -> void:
    var packed_scene := load(node_scene_file_path) as PackedScene
    if not packed_scene:
        printerr("Could not load PackedScene at %s" % node_scene_file_path)
        return
    if not edited_scene_path in nodes_by_scene_file_path:
        printerr("No instances of edited scene %s" % edited_scene_path)
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

func _remove_node(path: NodePath) -> void:
    if not edited_scene_path in nodes_by_scene_file_path:
        printerr("No instances of edited scene %s" % edited_scene_path)
        return
    var scene_nodes := nodes_by_scene_file_path[edited_scene_path]
    for scene_node: Node in scene_nodes:
        print("Searching in %s" % scene_node)
        if not scene_node.has_node(path):
            printerr("Couldn't find node at %s in %s" % [path, scene_node])
            continue
        var node := scene_node.get_node(path)
        if not scene_node.is_ancestor_of(node):
            printerr("Node was not a descendant of %s" % scene_node)
            continue
        node.get_parent().remove_child(node)
        node.queue_free()

func _remove_and_keep_node(path: NodePath, keep_id: int) -> void:
    if not edited_scene_path in nodes_by_scene_file_path:
        printerr("No instances of edited scene %s" % edited_scene_path)
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
        printerr("No instances of edited scene %s" % edited_scene_path)
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
        printerr("No instances of edited scene %s" % edited_scene_path)
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
