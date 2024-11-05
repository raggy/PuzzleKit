class_name PieceVisual3D
extends Node3D

@export var default_animation: PackedScene = preload("res://addons/puzzle_kit/3d/animation/tween_piece_animation_3d.tscn")

var animation: PieceAnimation3D
var animator: PieceAnimator3D
var piece: Piece3D: set = _set_piece

var _queued_animation: PieceAnimation3D

func _enter_tree() -> void:
    piece = get_parent() as Piece3D
    top_level = true

func _exit_tree() -> void:
    piece = null
    top_level = false

func _set_piece(value: Piece3D):
    if piece:
        piece.changes_committing.disconnect(_dequeue_animation)
        piece.teleported.disconnect(_snap_to_piece_transform)
        piece.visual = null
    piece = value
    if value:
        value.changes_committing.connect(_dequeue_animation)
        piece.teleported.connect(_snap_to_piece_transform)
        value.visual = self

func _dequeue_animation():
    # Piece didn't change state
    if piece._previous_transform == piece.transform:
        return
    # No animation queued, check if we can queue a default animation
    if not _queued_animation:
        if default_animation:
            _queued_animation = default_animation.instantiate()
            _queued_animation.setup(self)
        else:
            return
    animator.play(_queued_animation)
    _queued_animation = null

func _snap_to_piece_transform():
    if animation:
        animator.finish(animation)
    transform = piece.transform
