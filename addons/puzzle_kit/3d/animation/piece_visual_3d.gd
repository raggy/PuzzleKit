class_name PieceVisual3D
extends Node3D

@export var default_animation: PackedScene = preload("res://addons/puzzle_kit/3d/animation/tween_piece_animation_3d.tscn")

var animation: PieceAnimation3D
var piece: Piece3D: set = _set_piece

var _has_animation_this_step: bool

func _enter_tree() -> void:
    piece = get_parent() as Piece3D
    top_level = true

func _exit_tree() -> void:
    piece = null
    top_level = false

func create_default_animation() -> PieceAnimation3D:
    # Already have something playing for this step
    if _has_animation_this_step:
        return null
    
    # Piece didn't change state
    if piece._previous_active == piece.active and piece._previous_transform == piece.global_transform:
        return null
    
    # No default animation to play
    if not default_animation:
        return null
    
    var result := default_animation.instantiate()
    result.setup(self)
    return result

func _set_piece(value: Piece3D):
    if piece:
        piece.teleported.disconnect(_snap_to_piece_state)
        piece.visual = null
    piece = value
    if value:
        piece.teleported.connect(_snap_to_piece_state)
        value.visual = self

func _snap_to_piece_state():
    if animation:
        animation.finish()
    visible = piece.active
    global_transform = piece.global_transform
