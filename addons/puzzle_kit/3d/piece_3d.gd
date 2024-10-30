@tool
@icon("res://addons/puzzle_kit/icons/3d/piece_3d.svg")
class_name Piece3D
extends Node3D

var grid_position: Vector3i: get = _get_grid_position, set = _set_grid_position
var tiles: Array[Tile3D] = []

var _board: Board3D: set = _set_board
var _board_cached_transform: Transform3D

func _ready() -> void:
    _board = _find_ancestor_board()

func _exit_tree() -> void:
    _board = null

func _get_grid_position() -> Vector3i:
    return round(global_position)

func _set_grid_position(value: Vector3i):
    global_position = value

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
