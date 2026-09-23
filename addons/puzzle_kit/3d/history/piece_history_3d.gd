class_name PieceHistory3D
extends Node

var piece: Piece3D: set = _set_piece

var _has_entered_tree: bool = false

var _checkpoint_active: bool
var _checkpoint_parent_piece: Piece3D
var _checkpoint_transform: Transform3D

func _enter_tree() -> void:
    piece = get_parent() as Piece3D

    if piece and not _has_entered_tree:
        _has_entered_tree = true
        _checkpoint_active = piece._original_active
        _checkpoint_parent_piece = piece._original_parent_piece
        _checkpoint_transform = piece._original_transform

func _exit_tree() -> void:
    piece = null

## Save current state for checkpoint
func set_checkpoint() -> void:
    _checkpoint_active = piece.active
    _checkpoint_parent_piece = piece.parent_piece
    _checkpoint_transform = piece.global_transform

## Reset to checkpoint state
func reset_to_checkpoint() -> void:
    piece._teleport(_checkpoint_active, _checkpoint_parent_piece, _checkpoint_transform)

## Returns true if either piece's current state, or the checkpoint state, differ from the original state
func has_changes_to_save() -> bool:
    if piece.active != piece._original_active:
        return true
    if piece.parent_piece != piece._original_parent_piece:
        return true
    if piece.global_transform != piece._original_transform:
        return true
    if _checkpoint_active != piece._original_active:
        return true
    if _checkpoint_parent_piece != piece._original_parent_piece:
        return true
    if _checkpoint_transform != piece._original_transform:
        return true
    
    return false

func _set_piece(value: Piece3D) -> void:
    if piece:
        piece.history = null
    piece = value
    if value:
        value.history = self
