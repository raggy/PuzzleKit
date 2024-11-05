@tool
@icon("res://addons/puzzle_kit/icons/3d/piece_3d.svg")
class_name Piece3D
extends Node3D

signal changes_committing()
signal changes_reverting()
signal teleported()

## `position`, rounded to snap to the grid
var grid_position: Vector3i: get = _get_grid_position, set = _set_grid_position
## `transform.basis.x`, rounded to snap to the grid
var grid_right: Vector3i: get = _get_grid_right
## `transform.basis.y`, rounded to snap to the grid
var grid_up: Vector3i: get = _get_grid_up
## `-transform.basis.z`, rounded to snap to the grid
var grid_forward: Vector3i: get = _get_grid_forward

## `PieceHistory3D` child (auto-set)
var history: PieceHistory3D
## List of `Tile3D`, representing the 3D shape of this piece
var tiles: Array[Tile3D] = []
## `PieceVisual3D` child (auto-set)
var visual: PieceVisual3D

var _board: Board3D: set = _set_board
var _board_cached_transform: Transform3D
var _original_transform: Transform3D
var _previous_transform: Transform3D

func _enter_tree() -> void:
    _original_transform = transform
    _previous_transform = transform

    # Find tiles
    for i in range(get_child_count()):
        var child := get_child(i)
        var tile := child as Tile3D
        if not tile:
            continue
        tile.piece = self
    
    _board = _find_ancestor_board()

func _exit_tree() -> void:
    _board = null

func commit_changes():
    changes_committing.emit()
    _previous_transform = transform

func revert_changes():
    changes_reverting.emit()
    transform = _previous_transform

func teleport(new_transform: Transform3D):
    transform = new_transform
    _previous_transform = new_transform
    teleported.emit()

func _get_grid_position() -> Vector3i:
    return round(position)

func _set_grid_position(value: Vector3i):
    position = value

func _get_grid_right() -> Vector3i:
    return round(transform.basis.x)

func _get_grid_up() -> Vector3i:
    return round(transform.basis.y)

func _get_grid_forward() -> Vector3i:
    return round(-transform.basis.z)

func _set_board(value: Board3D):
    if _board:
        _board._deregister_piece(self)
    _board = value
    if value:
        value._register_piece(self)

func _find_ancestor_board() -> Board3D:
    const MAX_SEARCH_DEPTH := 8
    var search_node: Node = self
    # Search our parent and parent of parent, etc
    for i in range(MAX_SEARCH_DEPTH):
        var search_parent := search_node.get_parent()
        # Reached the root without finding it
        if not search_parent:
            return null
        # Found the Board
        if search_parent is Board3D:
            return search_parent as Board3D
    # Reached max search depth
    return null
