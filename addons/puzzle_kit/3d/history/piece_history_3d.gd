class_name PieceHistory3D
extends Node

var piece: Piece3D: set = _set_piece

## `_original_transform.origin`, rounded to snap to the grid
var original_grid_position: Vector3i: get = _get_original_grid_position
## `_original_transform.basis.x`, rounded to snap to the grid
var original_grid_right: Vector3i: get = _get_original_grid_right
## `_original_transform.basis.y`, rounded to snap to the grid
var original_grid_up: Vector3i: get = _get_original_grid_up
## `-_original_transform.basis.z`, rounded to snap to the grid
var original_grid_forward: Vector3i: get = _get_original_grid_forward

var _original_active: bool
var _original_transform: Transform3D

var _original_ancestor: Piece3D
var _original_descendant_path: String

var _in_checkpoint: bool = false
var _checkpoint_active: bool
var _checkpoint_parent_piece: Piece3D
var _checkpoint_transform: Transform3D

func _enter_tree() -> void:
    piece = get_parent() as Piece3D

func _exit_tree() -> void:
    piece = null

func _ready() -> void:
    # _original_active should be true if we exist during the initial scene
    _original_active = not piece._board.is_node_ready()
    _original_transform = piece.global_transform

    if piece.scene_file_path.is_empty() and piece.owner is Piece3D:
        _original_ancestor = piece.owner
        _original_descendant_path = piece.owner.get_path_to(piece)

## Get `PieceState3D` for current step
func get_current_state() -> PieceState3D:
    var state := PieceState3D.new()
    state.piece = piece
    state.active = piece.active
    state.parent_piece = piece.parent_piece
    state.transform = piece.global_transform
    return state

## Get `PieceState3D` for previous step
func get_previous_state() -> PieceState3D:
    var state := PieceState3D.new()
    state.piece = piece
    state.active = piece._previous_active
    state.parent_piece = piece._previous_parent_piece
    state.transform = piece._previous_transform
    return state

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

func _get_original_grid_position() -> Vector3i:
    return round(_original_transform.origin)

func _get_original_grid_right() -> Vector3i:
    return round(_original_transform.basis.x)

func _get_original_grid_up() -> Vector3i:
    return round(_original_transform.basis.y)

func _get_original_grid_forward() -> Vector3i:
    return round(-_original_transform.basis.z)
