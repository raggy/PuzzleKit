@tool
@icon("res://addons/puzzle_kit/icons/3d/piece_3d.svg")
class_name Piece3D
extends Node3D

signal changes_committing()
signal changes_reverting()
signal teleported()

var active: bool = true: set = set_active
## `global_position`, rounded to snap to the grid
var grid_position: Vector3i: get = _get_grid_position, set = _set_grid_position
## `global_transform.basis.x`, rounded to snap to the grid
var grid_right: Vector3i: get = _get_grid_right
## `global_transform.basis.y`, rounded to snap to the grid
var grid_up: Vector3i: get = _get_grid_up
## `-global_transform.basis.z`, rounded to snap to the grid
var grid_forward: Vector3i: get = _get_grid_forward

var original_grid_position: Vector3i: get = _get_original_grid_position
var original_grid_forward: Vector3i: get = _get_original_grid_forward

var parent: Piece3D: set = _set_parent
var children: Array[Piece3D] = []

## Flags for filtering (auto-set from groups)
var flags: int

## `PieceHistory3D` child (auto-set)
var history: PieceHistory3D
## `PieceVisual3D` child (auto-set)
var visual: PieceVisual3D

var _board: Board3D: set = _set_board

var _original_active: bool
var _previous_active: bool

var _original_parent: Piece3D
var _previous_parent: Piece3D

var _original_transform: Transform3D
var _previous_transform: Transform3D

var _owner_piece: Piece3D
var _original_path_from_owner_piece: NodePath

@warning_ignore_start("unused_private_class_variable")
var _board_cached_active: bool
var _board_cached_transform: Transform3D
var _piece_state_cached_top_level: bool
@warning_ignore_restore("unused_private_class_variable")

func _enter_tree() -> void:
    parent = _find_parent()
    _board = _find_board()

func _notification(what: int) -> void:
    match what:
        NOTIFICATION_PREDELETE:
            parent = null
            _board = null

func _setup() -> void:
    flags = GroupFilter.groups_to_flags(get_groups())

    _original_active = active
    _previous_active = active

    _original_parent = parent
    _previous_parent = parent

    _original_transform = global_transform
    _previous_transform = global_transform
    
    if scene_file_path.is_empty() and owner is Piece3D:
        _owner_piece = owner
        _original_path_from_owner_piece = owner.get_path_to(self)

func commit_changes() -> void:
    changes_committing.emit()
    _previous_active = active
    _previous_parent = parent
    _previous_transform = global_transform

func revert_changes() -> void:
    changes_reverting.emit()
    active = _previous_active
    parent = _previous_parent
    global_transform = _previous_transform

func teleport(new_active: bool, new_parent: Piece3D, new_transform: Transform3D) -> void:
    active = new_active
    _previous_active = new_active
    parent = new_parent
    _previous_parent = new_parent
    global_transform = new_transform
    _previous_transform = new_transform
    teleported.emit()

## Returns true if Piece3D's `active` property is true and all its ancestor Piece3D are also `active`
func is_active_in_tree() -> bool:
    if not parent:
        return active
    return active and parent.is_active_in_tree()

func set_active(value: bool) -> void:
    if active == value:
        return
    
    active = value
    
    if _board:
        if value:
            _board._activate_piece(self)
        else:
            _board._deactivate_piece(self)

func _get_grid_position() -> Vector3i:
    return round(global_position)

func _set_grid_position(value: Vector3i) -> void:
    global_position = value

func _get_grid_right() -> Vector3i:
    return round(global_transform.basis.x)

func _get_grid_up() -> Vector3i:
    return round(global_transform.basis.y)

func _get_grid_forward() -> Vector3i:
    return round(-global_transform.basis.z)

func _get_original_grid_position() -> Vector3i:
    return round(_original_transform.origin)

func _get_original_grid_forward() -> Vector3i:
    return round(-_original_transform.basis.z)

func _set_board(value: Board3D) -> void:
    if _board == value:
        return
    if _board:
        _board._deregister_piece(self)
    _board = value
    if value:
        _setup()
        value._register_piece(self)

func _set_parent(value: Piece3D) -> void:
    if parent == value:
        return
    if parent:
        parent.children.erase(self)
    parent = value
    if value:
        value.children.append(self)
    # Update node parent in scene tree
    var current_parent_node := get_parent()
    # No parent set, parent ourselves to the board (if we have one)
    if not value and current_parent_node != _board:
        _change_parent_node(current_parent_node, _board)
    # Parent set, parent ourselves to it if we're not already an ancestor
    elif value and not is_ancestor_of(value):
        _change_parent_node(current_parent_node, value)

func _change_parent_node(current_parent_node: Node, new_parent_node: Node) -> void:
    if current_parent_node == new_parent_node:
        return
    var current_top_level := top_level
    # Set top_level to preserve our transform when changing parent
    top_level = true
    if current_parent_node:
        current_parent_node.remove_child(self)
    if new_parent_node:
        new_parent_node.add_child(self)
    top_level = current_top_level

func _find_board() -> Board3D:
    const MAX_SEARCH_DEPTH := 8
    var search_node: Node = self
    # Search our parent and parent of parent, etc
    for i in range(MAX_SEARCH_DEPTH):
        var search_parent := search_node.get_parent()
        # Reached the root without finding anything
        if not search_parent:
            return null
        # Found the Board
        if search_parent is Board3D:
            return search_parent
        # Update which node we're looking at for next iteration
        search_node = search_parent
    # Reached max search depth
    return null

func _find_parent() -> Piece3D:
    const MAX_SEARCH_DEPTH := 8
    var search_node: Node = self
    # Search our parent and parent of parent, etc
    for i in range(MAX_SEARCH_DEPTH):
        var search_parent := search_node.get_parent()
        # Reached the root without finding anything
        if not search_parent:
            return null
        # Found a piece
        if search_parent is Piece3D:
            return search_parent
        # Update which node we're looking at for next iteration
        search_node = search_parent
    # Reached max search depth
    return null
