class_name PieceHistory3D
extends Node

var piece: Piece3D: set = _set_piece

func _enter_tree() -> void:
    piece = get_parent() as Piece3D

func _exit_tree() -> void:
    piece = null

## Get `PieceState3D` for current step
func get_current_state() -> PieceState3D:
    var state := PieceState3D.new()
    state.piece = piece
    state.transform = piece.transform
    return state

## Get `PieceState3D` for previous step
func get_previous_state() -> PieceState3D:
    var state := PieceState3D.new()
    state.piece = piece
    state.transform = piece._previous_transform
    return state

## Has this piece changed this step?
func has_changed() -> bool:
    return piece.transform != piece._previous_transform

func _set_piece(value: Piece3D):
    if piece:
        piece.history = null
    piece = value
    if value:
        value.history = self