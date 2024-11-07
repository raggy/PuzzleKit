@tool
@icon("res://addons/puzzle_kit/icons/3d/board_3d.svg")
class_name Board3D
extends Node3D

signal piece_added(piece: Piece3D)
signal piece_removed(piece: Piece3D)
signal changes_committing()
signal changes_reverting()

var _pieces: Array[Piece3D] = []
# var _cells_by_position: Dictionary[Vector3i, Cell3D] = {}
var _cells_by_position: Dictionary = {}
# var _cells_by_piece: Dictionary[Piece3D, Cell3D] = {}
var _cells_by_piece: Dictionary = {}

#region Queries
func is_empty(grid_position: Vector3i, group: String = "") -> bool:
    _update_cells()

    var cell := _cells_by_position.get(grid_position) as Cell3D
    # Nothing here
    if not cell or cell.is_empty():
        return true
    
    # No group filter and there is a non-empty cell
    if group == "":
        return false
    
    for piece in cell.pieces:
        if piece.is_in_group(group):
            return false
    
    return true

func get_piece_at(grid_position: Vector3i, group: String = "") -> Piece3D:
    _update_cells()

    var cell := _cells_by_position.get(grid_position) as Cell3D
    # Nothing here
    if not cell or cell.is_empty():
        return null
    # No group filter, return first piece in cell
    if group == "":
        return cell.pieces[0]
    
    var result: Array[Piece3D] = []
    # Return first piece that matches group
    for piece in _cells_by_position[grid_position].pieces:
        if piece.is_in_group(group):
            return piece
    
    return null

func get_pieces_at(grid_position: Vector3i, group: String = "") -> Array[Piece3D]:
    _update_cells()

    var cell := _cells_by_position.get(grid_position) as Cell3D
    # Nothing here
    if not cell or cell.is_empty():
        return []
    # No group filter, return all pieces in cell
    if group == "":
        return cell.pieces
    
    var result: Array[Piece3D] = []
    # Build an array of all pieces that match the group filter
    for piece in _cells_by_position[grid_position].pieces:
        if piece.is_in_group(group):
            result.append(piece)
    
    return result
#endregion

#region Commit/revert
func commit_changes():
    changes_committing.emit()
    
    for piece in _pieces:
        piece.commit_changes()

func revert_changes():
    changes_reverting.emit()
    
    for piece in _pieces:
        piece.revert_changes()
#endregion

#region Internal
func _register_piece(piece: Piece3D):
    _pieces.append(piece)
    _update_piece_cell(piece)
    piece_added.emit(piece)

func _deregister_piece(piece: Piece3D):
    _pieces.erase(piece)
    # Remove piece from cell if it was active
    if _cells_by_piece.has(piece):
        var cell := _cells_by_piece[piece] as Cell3D
        cell.pieces.erase(piece)
        _cells_by_piece.erase(piece)
    piece_removed.emit(piece)

func _update_cells():
    for piece in _pieces:
        # Piece hasn't changed since we last looked
        if piece.active == piece._board_cached_active and piece.global_transform == piece._board_cached_transform:
            continue
        _update_piece_cell(piece)

func _update_piece_cell(piece: Piece3D):
    # Note the state when we set the piece in cell
    piece._board_cached_active = piece.active
    piece._board_cached_transform = piece.global_transform
    # Update which cell the piece sits in
    var previous_cell := _cells_by_piece.get(piece) as Cell3D
    var new_cell := _get_or_create_cell(piece.grid_position) if piece.active else null
    # Piece didn't change cells
    if previous_cell == new_cell:
        return
    # Remove from old cell
    if previous_cell:
        previous_cell.pieces.erase(piece)
        _cells_by_piece.erase(piece)
    # Add to new cell
    if new_cell:
        new_cell.pieces.append(piece)
        _cells_by_piece[piece] = new_cell

func _get_or_create_cell(grid_position: Vector3i) -> Cell3D:
    if not _cells_by_position.has(grid_position):
        _cells_by_position[grid_position] = Cell3D.new(grid_position)
    return _cells_by_position[grid_position]
#endregion

class Cell3D:
    var grid_position: Vector3i
    var pieces: Array[Piece3D] = []

    func _init(_grid_position: Vector3i) -> void:
        grid_position = _grid_position
    
    func is_empty() -> bool:
        return pieces.size() == 0
