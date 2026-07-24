@tool
@icon("res://addons/puzzle_kit/icons/3d/piece_3d.svg")
class_name Piece3D
extends Node3D

signal changes_committing()
signal changes_reverting()
signal teleported()

@export_group("Editor")
## The layers this piece will be considered overlapping with when painting with the PuzzleKit editor.
## When no flags are selected, this piece is considered to overlap with every other piece.
@export_flags_3d_physics var editor_paint_layer: int = 1
## When painting this piece, erase other copies of it on the same board
@export var editor_paint_unique: bool = false

## Inactive pieces aren't included in positional queries and (by-default) ignored in other queries
var active: bool = true: set = set_active
## `global_position`, rounded to snap to the grid
var grid_position: Vector3i: get = _get_grid_position, set = _set_grid_position
## `global_transform.basis.x`, rounded to snap to the grid
var grid_right: Vector3i: get = _get_grid_right
## `global_transform.basis.y`, rounded to snap to the grid
var grid_up: Vector3i: get = _get_grid_up
## `-global_transform.basis.z`, rounded to snap to the grid
var grid_forward: Vector3i: get = _get_grid_forward

## The closest ancestor `Piece3D` in the scene tree
var parent_piece: Piece3D: get = get_parent_piece, set = set_parent_piece
## Array of the closest descendant `Piece3D` in the scene tree.
## Editing this manually will probably break things!
var _child_pieces: Array[Piece3D] = []

## Flags for filtering (auto-set from groups)
var flags: int

## `PieceHistory3D` child (auto-set)
var history: PieceHistory3D
## `PieceVisual3D` child (auto-set)
var visual: PieceVisual3D

var _board: Board3D: set = _set_board
var _parent_piece: Piece3D

var _has_init_previous: bool = false
var _previous_active: bool
var _previous_parent_piece: Piece3D
var _previous_transform: Transform3D

@warning_ignore_start("unused_private_class_variable")
var _board_cached_active: bool
var _piece_state_cached_top_level: bool
@warning_ignore_restore("unused_private_class_variable")

func _enter_tree() -> void:
    _set_parent_piece_no_scene_tree_changes(_find_piece_ancestor())

    if not _has_init_previous:
        _has_init_previous = true
        # _previous_active should be true if we exist during the initial scene
        _previous_active = not get_parent().is_node_ready()
        _previous_parent_piece = parent_piece
        _previous_transform = global_transform

    _board = _find_board()

func _exit_tree() -> void:
    _set_parent_piece_no_scene_tree_changes(null)
    _board = null

func _ready() -> void:
    flags = GroupFilter.groups_to_flags(get_groups())
    set_notify_transform(true)

func _notification(what: int) -> void:
    match what:
        NOTIFICATION_TRANSFORM_CHANGED:
            if _board and _board_cached_active: _board._update_piece_cell(self)
        NOTIFICATION_PREDELETE:
            parent_piece = null
            _board = null

## Fetches closest descendant `Piece3D` at `index`
func get_child_piece(index: int) -> Piece3D:
    return _child_pieces[index]

## Returns the number of closest-descendant `Piece3D` in the scene tree
func get_child_piece_count() -> int:
    return _child_pieces.size()

## Returns a new Array of the closest descendant `Piece3D` in the scene tree
func get_child_pieces() -> Array[Piece3D]:
    return _child_pieces.duplicate()

## Returns the closest ancestor `Piece3D` in the scene tree
func get_parent_piece() -> Piece3D:
    return _parent_piece

## Reparents this piece to `value`, if not already a descendant. Preserves `global_transform`.
## Alternatively, you may use Godot's `add_child` and `remove_child` functions and `parent_piece` will be updated automatically
func set_parent_piece(value: Piece3D) -> void:
    if _parent_piece == value:
        return
    _set_parent_piece_no_scene_tree_changes(value)
    # Update node parent_piece in scene tree
    var current_parent_node := get_parent()
    # No parent_piece set, parent ourselves to the board (if we have one)
    if not value and current_parent_node != _board:
        _change_parent_node(current_parent_node, _board)
    # parent_piece set, parent ourselves to it if we're not already a descendant
    elif value and not is_ancestor_of(value):
        _change_parent_node(current_parent_node, value)

## Returns true if this piece matches `group_filter`
func matches(group_filter: GroupFilter) -> bool:
    return group_filter.matches_3d(self)

## Returns the first descendant `Piece3D` matching `group_filter`
func get_first_child_piece_matching(group_filter: GroupFilter) -> Piece3D:
    var child_piece_index := _child_pieces.find_custom(group_filter.matches_3d)
    if child_piece_index != -1:
        return _child_pieces[child_piece_index]
    return null

## Returns an Array of all descendant `Piece3D` matching `group_filter`
func get_child_pieces_matching(group_filter: GroupFilter) -> Array[Piece3D]:
    return _child_pieces.filter(group_filter.matches_3d)

## Returns true if Piece3D's `active` property is true, all its ancestor Piece3D are also `active` and `is_inside_tree()` is true
func is_active_in_tree() -> bool:
    if not is_inside_tree():
        return false
    if not parent_piece:
        return active
    return active and parent_piece.is_active_in_tree()

## See `active`
func set_active(value: bool) -> void:
    if active == value:
        return
    
    active = value
    
    _update_board_state(true)

func _get_grid_position() -> Vector3i:
    return round(global_position)

func _set_grid_position(value: Vector3i) -> void:
    if not is_inside_tree():
        position = value
        return
    global_position = value

func _get_grid_right() -> Vector3i:
    return round(global_transform.basis.x)

func _get_grid_up() -> Vector3i:
    return round(global_transform.basis.y)

func _get_grid_forward() -> Vector3i:
    return round(-global_transform.basis.z)

func _set_board(value: Board3D) -> void:
    if _board == value:
        return
    if _board:
        _board._deregister_piece(self)
    _board = value
    if value:
        value._register_piece(self)

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
    if not is_inside_tree():
        return null
    var search_parent := get_parent()
    # Search our parent and parent of parent, etc
    while search_parent:
        # Found a piece
        if search_parent is Board3D:
            return search_parent
        # Update which node we're looking at for next iteration
        search_parent = search_parent.get_parent()
    # Reached the root without finding anything
    return null

func _find_piece_ancestor() -> Piece3D:
    if not is_inside_tree():
        return null
    var search_parent := get_parent()
    # Search our parent and parent of parent, etc
    while search_parent:
        # Found a piece
        if search_parent is Piece3D:
            return search_parent
        # Update which node we're looking at for next iteration
        search_parent = search_parent.get_parent()
    # Reached the root without finding anything
    return null

func _update_board_state(including_descendants: bool) -> void:
    if not _board:
        return
    
    if is_active_in_tree():
        _board._activate_piece(self)
    else:
        _board._deactivate_piece(self)
    
    if including_descendants:
        for child_piece in _child_pieces:
            child_piece._update_board_state(true)

func _set_parent_piece_no_scene_tree_changes(value: Piece3D) -> void:
    if _parent_piece:
        _parent_piece._child_pieces.erase(self)
    _parent_piece = value
    if value:
        value._child_pieces.append(self)

func _commit_changes() -> void:
    changes_committing.emit()
    _previous_active = active
    _previous_parent_piece = parent_piece
    _previous_transform = global_transform

func _revert_changes() -> void:
    changes_reverting.emit()
    active = _previous_active
    parent_piece = _previous_parent_piece
    global_transform = _previous_transform

func _teleport(new_active: bool, new_parent_piece: Piece3D, new_transform: Transform3D) -> void:
    active = new_active
    _previous_active = new_active
    parent_piece = new_parent_piece
    _previous_parent_piece = new_parent_piece
    global_transform = new_transform
    _previous_transform = new_transform
    teleported.emit()

static func find_descendant_pieces(node: Node, pieces: Array[Piece3D], group_filter: GroupFilter = null) -> void:
    var piece := node as Piece3D
    if piece and (not group_filter or group_filter.matches_3d(piece)):
        # Found a matching piece
        pieces.append(piece)
    for i in range(node.get_child_count()):
        # Search child
        find_descendant_pieces(node.get_child(i), pieces)
