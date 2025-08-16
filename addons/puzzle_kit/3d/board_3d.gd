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

var _cells_by_position: Dictionary[Vector3i, Cell] = {}
var _cells_by_piece: Dictionary[Piece3D, Cell] = {}

#region Queries
func is_empty(grid_position: Vector3i, group_filter: GroupFilter = null) -> bool:
    _update_cells()

    # No cell here yet
    if not _cells_by_position.has(grid_position):
        return true
    var cell := _cells_by_position[grid_position]
    # Nothing in this cell
    if cell.is_empty():
        return true
    
    # No group filter and there is a non-empty cell
    if not group_filter:
        return false
    
    for piece in cell.pieces:
        if group_filter.matches_3d(piece):
            return false
    
    return true

func is_occupied(grid_position: Vector3i, group_filter: GroupFilter = null) -> bool:
    return not is_empty(grid_position, group_filter)

func get_piece_at(grid_position: Vector3i, group_filter: GroupFilter = null) -> Piece3D:
    _update_cells()

    # No cell here yet
    if not _cells_by_position.has(grid_position):
        return null
    var cell := _cells_by_position[grid_position]
    # Nothing in this cell
    if cell.is_empty():
        return null
    # No group filter, return first piece in cell
    if not group_filter:
        return cell.pieces[0]
    
    # Return first piece that matches group
    for piece in _cells_by_position[grid_position].pieces:
        if group_filter.matches_3d(piece):
            return piece
    
    return null

func get_pieces_at(grid_position: Vector3i, group_filter: GroupFilter = null) -> Array[Piece3D]:
    _update_cells()

    # No cell here yet
    if not _cells_by_position.has(grid_position):
        return []
    var cell := _cells_by_position[grid_position]
    # Nothing in this cell
    if cell.is_empty():
        return cell.pieces
    # No group filter, return all pieces in cell
    if not group_filter:
        return cell.pieces
    
    var result: Array[Piece3D] = []
    # Build an array of all pieces that match the group filter
    for piece in _cells_by_position[grid_position].pieces:
        if group_filter.matches_3d(piece):
            result.append(piece)
    
    return result

## Get the first piece registered (optionally filtered by group, optionally including inactive)
func get_piece(group_filter: GroupFilter = null, include_inactive: bool = false) -> Piece3D:
    var filtered_by_group := group_filter != null

    for piece in _pieces:
        if not include_inactive and not piece.active:
            # Not including inactive pieces
            continue
        if not filtered_by_group:
            # No group filter, piece matches
            return piece
        if group_filter.matches_3d(piece):
            # Piece matches the group filter
            return piece
    # Found nothing
    return null

## Get all pieces (optionally filtered by group, optionally including inactive)
func get_pieces(group_filter: GroupFilter = null, include_inactive: bool = false) -> Array[Piece3D]:
    var filtered_by_group := group_filter != null

    if not filtered_by_group:
        # We just want all pieces
        if include_inactive:
            return _pieces
        # We just want all active pieces
        return _active_pieces

    if include_inactive:
        # Filter all pieces by group
        return _pieces.filter(group_filter.matches_3d)
    # Filter active pieces by group
    return _active_pieces.filter(group_filter.matches_3d)

## Count all pieces (optionally filtered by group, optionally including inactive)
func count_pieces(group_filter: GroupFilter = null, include_inactive: bool = false) -> int:
    var filtered_by_group := group_filter != null

    if not filtered_by_group:
        # We just want all pieces
        if include_inactive:
            return _pieces.size()
        # We just want all active pieces
        return _active_pieces.size()
    
    # Filter pieces by what matches
    var pieces_to_search := _pieces if include_inactive else _active_pieces
    var piece_count := 0
    for piece in pieces_to_search:
        if not group_filter.matches_3d(piece):
            # Didn't match group filter
            continue
        piece_count += 1
    return piece_count

## Get all pieces adjacent to `pieces`, filtered by `group` and in specified `directions`. If `max_search_depth` is specified, returned pieces will be at most `max_search_depth` steps away
func get_pieces_touching(pieces: Array[Piece3D], group_filter: GroupFilter = null, directions: Array[Vector3i] = DIRECTIONS_ADJACENT, max_search_depth: int = -1) -> Array[Piece3D]:
    var filtered_by_group := group_filter != null
    var pieces_touching: Array[Piece3D] = []
    var pieces_size := pieces.size()
    var search_index := 0
    var current_search_depth := 0
    var piece_count_remaining_at_current_search_depth := pieces_size
    var piece_count_at_next_search_depth := 0

    while (search_index < pieces_size + pieces_touching.size()):
        # Finished checking pieces at current search depth
        if piece_count_remaining_at_current_search_depth == 0:
            current_search_depth += 1
            piece_count_remaining_at_current_search_depth = piece_count_at_next_search_depth
            piece_count_at_next_search_depth = 0
            # Reached max search depth, stop searching
            if max_search_depth > -1 and current_search_depth >= max_search_depth:
                break
        # Remove this piece from the current count
        piece_count_remaining_at_current_search_depth -= 1

        var piece := pieces[search_index] if search_index < pieces_size else pieces_touching[search_index - pieces_size]

        for direction in directions:
            # Gather the pieces adjacent (if not already in list)
            for piece_in_direction in get_pieces_at(piece.grid_position + direction):
                # Check if in group here rather than get_pieces_at() to prevent an extra array being created
                if filtered_by_group and not group_filter.matches_3d(piece_in_direction):
                    continue
                if pieces.has(piece_in_direction) or pieces_touching.has(piece_in_direction):
                    continue
                pieces_touching.append(piece_in_direction)
                piece_count_at_next_search_depth += 1
        
        search_index += 1
    
    return pieces_touching
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
    if piece.is_active_in_tree():
        piece._board_cached_active = true
        _active_pieces.append(piece)
    else:
        piece._board_cached_active = false
        _inactive_pieces.append(piece)
    _update_piece_cell(piece)
    piece_added.emit(piece)

func _deregister_piece(piece: Piece3D) -> void:
    _pieces.erase(piece)
    if piece._board_cached_active:
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

func _get_or_create_cell(grid_position: Vector3i) -> Cell:
    if not _cells_by_position.has(grid_position):
        _cells_by_position[grid_position] = Cell.new(grid_position)
    return _cells_by_position[grid_position]

func _activate_piece(piece: Piece3D) -> void:
    if piece._board_cached_active:
        return
    piece._board_cached_active = true
    _inactive_pieces.erase(piece)
    _active_pieces.append(piece)
    # Add piece to cell
    _update_piece_cell(piece)
    # Activate piece's children
    for child in piece.children:
        if child.active:
            _activate_piece(child)

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
    # Deactivate piece's children
    for child in piece.children:
        if child.active:
            _deactivate_piece(child)
#endregion

class Cell extends RefCounted:
    var grid_position: Vector3i
    var pieces: Array[Piece3D] = []

    func _init(_grid_position: Vector3i) -> void:
        grid_position = _grid_position
    
    func is_empty() -> bool:
        return pieces.size() == 0
