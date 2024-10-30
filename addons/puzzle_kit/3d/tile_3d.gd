@tool
class_name Tile3D
extends Node3D

var grid_position: Vector3i: get = _get_grid_position
var piece: Piece3D: set = _set_piece

func _enter_tree() -> void:
    piece = get_parent() as Piece3D

func _exit_tree() -> void:
    piece = null

func _get_grid_position() -> Vector3i:
    return round(global_position)

func _set_piece(value: Piece3D):
    if piece:
        piece.tiles.erase(self)
    piece = value
    if value:
        value.tiles.append(self)

func _to_string() -> String:
    if piece:
        return "%s %s" % [piece.name, grid_position]
    
    return "Invalid Tile3D"
