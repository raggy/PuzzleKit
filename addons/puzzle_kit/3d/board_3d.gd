@tool
@icon("res://addons/puzzle_kit/icons/3d/board_3d.svg")
class_name Board3D
extends Node3D

signal piece_added(piece: Piece3D)
signal piece_removed(piece: Piece3D)
signal changes_committing()
signal changes_reverting()

const DIRECTIONS_ADJACENT: Array[Vector3i] = [Vector3i.LEFT, Vector3i.RIGHT, Vector3i.DOWN, Vector3i.UP, Vector3i.FORWARD, Vector3i.BACK]
const DIRECTIONS_CARDINAL: Array[Vector3i] = [Vector3i.LEFT, Vector3i.RIGHT, Vector3i.FORWARD, Vector3i.BACK]
const DIRECTIONS_X_AXIS: Array[Vector3i] = [Vector3i.LEFT, Vector3i.RIGHT]
const DIRECTIONS_Y_AXIS: Array[Vector3i] = [Vector3i.DOWN, Vector3i.UP]
const DIRECTIONS_Z_AXIS: Array[Vector3i] = [Vector3i.FORWARD, Vector3i.BACK]
const DIRECTIONS_LEFT: Array[Vector3i] = [Vector3i.LEFT]
const DIRECTIONS_RIGHT: Array[Vector3i] = [Vector3i.RIGHT]
const DIRECTIONS_DOWN: Array[Vector3i] = [Vector3i.DOWN]
const DIRECTIONS_UP: Array[Vector3i] = [Vector3i.UP]
const DIRECTIONS_FORWARD: Array[Vector3i] = [Vector3i.FORWARD]
const DIRECTIONS_BACK: Array[Vector3i] = [Vector3i.BACK]

var _pieces: Array[Piece3D] = []
var _active_pieces: Array[Piece3D] = []
var _inactive_pieces: Array[Piece3D] = []
var _cells_by_position: Dictionary[Vector3i, Cell3D] = {}
var _cells_by_piece: Dictionary[Piece3D, Cell3D] = {}

#region Queries
func is_empty(grid_position: Vector3i, group: String = "") -> bool:
    _update_cells()

    # No cell here yet
    if not _cells_by_position.has(grid_position):
        return true
    var cell := _cells_by_position[grid_position]
    # Nothing in this cell
    if cell.is_empty():
        return true
    
    # No group filter and there is a non-empty cell
    if group == "":
        return false
    
    for piece in cell.pieces:
        if piece.is_in_group(group):
            return false
    
    return true

func is_occupied(grid_position: Vector3i, group: String = "") -> bool:
    return not is_empty(grid_position, group)

func get_piece_at(grid_position: Vector3i, group: String = "") -> Piece3D:
    _update_cells()

    # No cell here yet
    if not _cells_by_position.has(grid_position):
        return null
    var cell := _cells_by_position[grid_position]
    # Nothing in this cell
    if cell.is_empty():
        return null
    # No group filter, return first piece in cell
    if group == "":
        return cell.pieces[0]
    
    # Return first piece that matches group
    for piece in _cells_by_position[grid_position].pieces:
        if piece.is_in_group(group):
            return piece
    
    return null

func get_pieces_at(grid_position: Vector3i, group: String = "") -> Array[Piece3D]:
    _update_cells()

    # No cell here yet
    if not _cells_by_position.has(grid_position):
        return []
    var cell := _cells_by_position[grid_position]
    # Nothing in this cell
    if cell.is_empty():
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

## Get the first piece registered (optionally filtered by group, optionally including inactive)
func get_piece(group: String = "", include_inactive: bool = false) -> Piece3D:
    for piece in _pieces:
        # Piece matches filter
        if _piece_filter(piece, group, include_inactive):
            return piece
    # Found nothing
    return null

## Get all pieces (optionally filtered by group, optionally including inactive)
func get_pieces(group: String = "", include_inactive: bool = false) -> Array[Piece3D]:
    var filtered_by_group: bool = not group.is_empty()
    # We just want all pieces
    if not filtered_by_group and include_inactive:
        return _pieces
    # Filter pieces by what matches 
    return _pieces.filter(_piece_filter.bind(group, include_inactive))

## Count all pieces (optionally filtered by group, optionally including inactive)
func count_pieces(group: String = "", include_inactive: bool = false) -> int:
    var filtered_by_group: bool = not group.is_empty()
    # We just want all pieces
    if not filtered_by_group and include_inactive:
        return _pieces.size()
    # Filter pieces by what matches
    var piece_count := 0
    for piece in _pieces:
        if _piece_filter(piece, group, include_inactive):
            piece_count += 1
    return piece_count

## Get all pieces adjacent to `pieces` in specified directions (and all pieces adjacent to those, and so on)
func get_pieces_touching(pieces: Array[Piece3D], directions: Array[Vector3i], group: String = "") -> Array[Piece3D]:
    var pieces_touching: Array[Piece3D] = pieces.duplicate()
    var search_index := 0

    while (search_index < pieces_touching.size()):
        var origin_piece := pieces_touching[search_index]

        for direction in directions:
            var pieces_in_direction := get_pieces_at(origin_piece.grid_position + direction)
            # Gather the pieces adjacent (if not already in list)
            for piece_in_direction in pieces_in_direction:
                # Check if in group here rather than get_pieces_at() to prevent an extra array being created
                if not piece_in_direction.is_in_group(group):
                    continue
                if pieces_touching.has(piece_in_direction):
                    continue
                pieces_touching.append(piece_in_direction)
        
        search_index += 1
    
    return pieces_touching

## Get all pieces adjacent to `pieces` in specified directions
func get_pieces_in_directions(pieces: Array[Piece3D], directions: Array[Vector3i], group: String = "") -> Array[Piece3D]:
    var pieces_in_direction: Array[Piece3D] = []

    for piece in pieces:
        for direction in directions:
            # Gather the pieces adjacent (if not already in list)
            for piece_in_direction in get_pieces_at(piece.grid_position + direction):
                # Check if in group here rather than get_pieces_at() to prevent an extra array being created
                if not piece_in_direction.is_in_group(group):
                    continue
                if pieces_in_direction.has(piece_in_direction):
                    continue
                pieces_in_direction.append(piece_in_direction)

    return pieces_in_direction
#endregion

#region Commit/revert
func commit_changes() -> void:
    changes_committing.emit()
    
    for piece in _pieces:
        piece.commit_changes()

func revert_changes() -> void:
    changes_reverting.emit()
    
    for piece in _pieces:
        piece.revert_changes()
#endregion

#region Internal
func _register_piece(piece: Piece3D) -> void:
    _pieces.append(piece)
    if piece.active:
        piece._board_cached_active = true
        _active_pieces.append(piece)
    else:
        piece._board_cached_active = false
        _inactive_pieces.append(piece)
    _update_piece_cell(piece)
    piece_added.emit(piece)

func _deregister_piece(piece: Piece3D) -> void:
    _pieces.erase(piece)
    if piece.active:
        _active_pieces.erase(piece)
    else:
        _inactive_pieces.erase(piece)
    # Remove piece from cell if it was active
    if _cells_by_piece.has(piece):
        var cell := _cells_by_piece[piece]
        cell.pieces.erase(piece)
        _cells_by_piece.erase(piece)
    piece_removed.emit(piece)

func _update_cells() -> void:
    for piece in _active_pieces:
        # Piece hasn't changed since we last looked
        if piece.global_transform == piece._board_cached_transform:
            continue
        _update_piece_cell(piece)

func _update_piece_cell(piece: Piece3D) -> void:
    # Note the state when we set the piece in cell
    piece._board_cached_transform = piece.global_transform
    # Update which cell the piece sits in
    var previous_cell := _cells_by_piece[piece] if _cells_by_piece.has(piece) else null
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

func _piece_filter(piece: Piece3D, group: String, include_inactive: bool) -> bool:
    # We don't want inactive pieces and piece is inactive
    if not include_inactive and not piece.active:
        return false
    var filtered_by_group: bool = not group.is_empty()
    # Piece doesn't match the group filter
    if filtered_by_group and not piece.is_in_group(group):
        return false
    # Piece satisfies filter
    return true

func _activate_piece(piece: Piece3D) -> void:
    if piece._board_cached_active:
        return
    piece._board_cached_active = true
    _inactive_pieces.erase(piece)
    _active_pieces.append(piece)
    # Add piece to cell
    _update_piece_cell(piece)

func _deactivate_piece(piece: Piece3D) -> void:
    if not piece._board_cached_active:
        return
    piece._board_cached_active = false
    _active_pieces.erase(piece)
    _inactive_pieces.append(piece)
    # Remove piece from cell
    if _cells_by_piece.has(piece):
        var cell := _cells_by_piece[piece]
        cell.pieces.erase(piece)
        _cells_by_piece.erase(piece)
#endregion

class Cell3D:
    var grid_position: Vector3i
    var pieces: Array[Piece3D] = []

    func _init(_grid_position: Vector3i) -> void:
        grid_position = _grid_position
    
    func is_empty() -> bool:
        return pieces.size() == 0
