class_name PieceHistory3D
extends Node

var piece: Piece3D: set = _set_piece

var _in_checkpoint: bool = false
var _checkpoint_active: bool
var _checkpoint_parent_piece: Piece3D
var _checkpoint_transform: Transform3D

func _enter_tree() -> void:
    piece = get_parent() as Piece3D

func _exit_tree() -> void:
    piece = null

## Save current state for checkpoint
func set_checkpoint() -> void:
    _in_checkpoint = true
    _checkpoint_active = piece.active
    _checkpoint_parent_piece = piece.parent_piece
    _checkpoint_transform = piece.global_transform

## Reset to checkpoint state
func reset_to_checkpoint() -> void:
    # Deactivate pieces that were created after the checkpoint
    if not _in_checkpoint:
        piece._teleport(false, piece.parent_piece, piece.global_transform)
        return
    
    # Move piece to checkpoint state
    piece._teleport(_checkpoint_active, _checkpoint_parent_piece, _checkpoint_transform)

func _set_piece(value: Piece3D) -> void:
    if piece:
        piece.history = null
    piece = value
    if value:
        value.history = self
