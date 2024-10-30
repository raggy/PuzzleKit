@tool
@icon("res://addons/puzzle_kit/icons/3d/board_3d.svg")
class_name Board3D
extends Node3D

var _pieces: Array[Piece3D] = []
var _cells_by_position: Dictionary[Vector3i, Cell3D] = {}
var _cells_by_tile: Dictionary[Tile3D, Cell3D] = {}

func is_empty(grid_position: Vector3i) -> bool:
    _update_piece_cells()

    var cell := _cells_by_position.get(grid_position)

    return not cell or cell.tiles.size() == 0

func get_tiles_at(grid_position: Vector3i) -> Array[Tile3D]:
    _update_piece_cells()

    if _cells_by_position.has(grid_position):
        return _cells_by_position[grid_position].tiles
    
    return []

func _register_piece(piece: Piece3D):
    _pieces.append(piece)
    _update_piece_tile_cells(piece)

func _deregister_piece(piece: Piece3D):
    _pieces.erase(piece)
    # Remove tiles from cells
    for tile in piece.tiles:
        var cell := _cells_by_tile.get(tile)
        # Tile wasn't registered to a cell?
        if not cell:
            continue
        cell.tiles.erase(tile)
        _cells_by_tile.erase(tile)

func _update_piece_cells():
    for piece in _pieces:
        # Piece hasn't changed transform since we last looked
        if piece.transform == piece._board_cached_transform:
            continue
        _update_piece_tile_cells(piece)

func _update_piece_tile_cells(piece: Piece3D):
    # Note the transform state when we set the tiles in cells
    piece._board_cached_transform = piece.transform
    # Update which cells the tiles sit in
    for tile in piece.tiles:
        var previous_cell := _cells_by_tile.get(tile)
        var new_cell := _get_or_create_cell(tile.grid_position)
        # Tile didn't change cells
        if previous_cell == new_cell:
            continue
        # Remove from old cell
        if previous_cell:
            previous_cell.tiles.erase(tile)
            _cells_by_tile.erase(tile)
        # Add to new cell
        new_cell.tiles.append(tile)
        _cells_by_tile[tile] = new_cell

func _get_or_create_cell(grid_position: Vector3i) -> Cell3D:
    if not _cells_by_position.has(grid_position):
        _cells_by_position[grid_position] = Cell3D.new(grid_position)
    return _cells_by_position[grid_position]

class Cell3D:
    var grid_position: Vector3i
    var tiles: Array[Tile3D] = []

    func _init(_grid_position: Vector3i) -> void:
        grid_position = _grid_position
