@tool
class_name PieceVisual3D
extends Node3D

signal event(event_id: String)

@export var default_animation: PackedScene = preload("res://addons/puzzle_kit/3d/animation/tween_piece_animation_3d.tscn")
@export var uses_default_animation: bool = true
@export var ignore_piece_rotation: bool = false

var animation: PieceAnimation3D
var piece: Piece3D: set = _set_piece

var cached_transform: Transform3D
var cached_active: bool

var current_piece_transform: Transform3D: get = get_current_piece_transform
var previous_piece_transform: Transform3D: get = get_previous_piece_transform

func _enter_tree() -> void:
    piece = get_parent() as Piece3D
    if not Engine.is_editor_hint():
        top_level = true

func _exit_tree() -> void:
    piece = null
    if not Engine.is_editor_hint():
        top_level = false

func _ready() -> void:
    if Engine.is_editor_hint():
        set_notify_transform(true)

func _notification(what: int) -> void:
    match what:
        NOTIFICATION_TRANSFORM_CHANGED:
            if Engine.is_editor_hint(): global_transform = current_piece_transform

func create_default_animation() -> PieceAnimation3D:
    # Default animation toggled off
    if not uses_default_animation:
        return null
    
    # No default animation to play
    if not default_animation:
        return null
    
    # Already displaying current piece state
    if cached_active == piece.active and cached_transform == current_piece_transform:
        return null
    
    return create_animation(default_animation)

func create_animation(animation_scene: PackedScene) -> PieceAnimation3D:
    var result := animation_scene.instantiate() as PieceAnimation3D
    # PackedScene `animation_scene` was not a PieceAnimation3D
    if not result:
        return null

    result.setup(self)
    return result

func get_current_piece_transform() -> Transform3D:
    if ignore_piece_rotation:
        var value := piece.global_transform
        value.basis = Basis.IDENTITY
        return value

    return piece.global_transform

func get_previous_piece_transform() -> Transform3D:
    if ignore_piece_rotation:
        var value := piece._previous_transform
        value.basis = Basis.IDENTITY
        return value

    return piece._previous_transform

func _set_piece(value: Piece3D) -> void:
    if piece:
        piece.changes_committing.disconnect(_reset_cached_state_to_current)
        piece.changes_reverting.disconnect(_reset_cached_state_to_previous)
        piece.teleported.disconnect(_reset_cached_state_to_current)
        piece.teleported.disconnect(_snap_to_piece_state)
        piece.visual = null
    piece = value
    if value:
        value.changes_committing.connect(_reset_cached_state_to_current)
        value.changes_reverting.connect(_reset_cached_state_to_previous)
        value.teleported.connect(_reset_cached_state_to_current)
        value.teleported.connect(_snap_to_piece_state)
        value.visual = self
        _reset_cached_state_to_current()
        _snap_to_piece_state()

func _reset_cached_state_to_current() -> void:
    cached_active = piece.active
    cached_transform = current_piece_transform

func _reset_cached_state_to_previous() -> void:
    cached_active = piece._previous_active
    cached_transform = previous_piece_transform

func _snap_to_piece_state() -> void:
    if animation:
        animation.finish()
    visible = piece.active
    global_transform = current_piece_transform
