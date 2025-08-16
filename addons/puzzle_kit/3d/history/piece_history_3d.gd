class_name PieceHistory3D
extends Node

var piece: Piece3D: set = _set_piece

var _in_checkpoint: bool = false
var _checkpoint_active: bool
var _checkpoint_parent: Piece3D
var _checkpoint_transform: Transform3D

func _enter_tree() -> void:
    piece = get_parent() as Piece3D

func _exit_tree() -> void:
    piece = null

## Get `PieceState3D` for current step
func get_current_state() -> PieceState3D:
    var state := PieceState3D.new()
    state.piece = piece
    state.active = piece.active
    state.parent = piece.parent
    state.transform = piece.global_transform
    return state

## Get `PieceState3D` for previous step
func get_previous_state() -> PieceState3D:
    var state := PieceState3D.new()
    state.piece = piece
    state.active = piece._previous_active
    state.parent = piece._previous_parent
    state.transform = piece._previous_transform
    return state

## Has this piece changed this step?
func has_changed() -> bool:
    return piece.active != piece._previous_active or piece.parent != piece._previous_parent or piece.global_transform != piece._previous_transform

func set_checkpoint() -> void:
    _in_checkpoint = true
    _checkpoint_active = piece.active
    _checkpoint_parent = piece.parent
    _checkpoint_transform = piece.global_transform

func reset_to_checkpoint() -> void:
    # Deactivate pieces that were created after the checkpoint
    if not _in_checkpoint:
        piece.teleport(false, piece.parent, piece.global_transform)
        return
    
    # Move piece to checkpoint state
    piece.teleport(_checkpoint_active, _checkpoint_parent, _checkpoint_transform)

func _set_piece(value: Piece3D) -> void:
    if piece:
        piece.history = null
    piece = value
    if value:
        value.history = self
