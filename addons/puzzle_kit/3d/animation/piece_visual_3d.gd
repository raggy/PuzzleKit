class_name PieceVisual3D
extends Node3D

signal event(event_id: String)

@export var default_animation: PackedScene = preload("res://addons/puzzle_kit/3d/animation/tween_piece_animation_3d.tscn")
@export var uses_default_animation: bool = true

var animation: PieceAnimation3D
var piece: Piece3D: set = _set_piece

var cached_transform: Transform3D
var cached_active: bool

var _has_animation_this_step: bool

func _enter_tree() -> void:
    piece = get_parent() as Piece3D
    top_level = true

func _exit_tree() -> void:
    piece = null
    top_level = false

func create_default_animation() -> PieceAnimation3D:
    # Default animation toggled off
    if not uses_default_animation:
        return null
    
    # Already have something playing for this step
    if _has_animation_this_step:
        return null
    
    # Piece didn't change state
    if piece._previous_active == piece.active and piece._previous_transform == piece.global_transform:
        return null
    
    # No default animation to play
    if not default_animation:
        return null
    
    var result := default_animation.instantiate() as PieceAnimation3D
    result.setup(self)
    return result

func _set_piece(value: Piece3D) -> void:
    if piece:
        value.changes_committing.disconnect(_reset_cached_state_to_current)
        value.changes_reverting.disconnect(_reset_cached_state_to_previous)
        value.teleported.disconnect(_reset_cached_state_to_current)
        piece.teleported.disconnect(_snap_to_piece_state)
        piece.visual = null
    piece = value
    if value:
        value.changes_committing.connect(_reset_cached_state_to_current)
        value.changes_reverting.connect(_reset_cached_state_to_previous)
        value.teleported.connect(_reset_cached_state_to_current)
        value.teleported.connect(_snap_to_piece_state)
        value.visual = self

func _reset_cached_state_to_current() -> void:
    cached_active = piece.active
    cached_transform = piece.global_transform

func _reset_cached_state_to_previous() -> void:
    cached_active = piece._previous_active
    cached_transform = piece._previous_transform

func _snap_to_piece_state() -> void:
    if animation:
        animation.finish()
    visible = piece.active
    global_transform = piece.global_transform
