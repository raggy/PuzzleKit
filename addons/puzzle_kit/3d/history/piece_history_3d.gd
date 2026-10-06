class_name PieceHistory3D
extends Node

var piece: Piece3D: set = _set_piece

var _has_entered_tree: bool = false

var _checkpoint_active: bool
var _checkpoint_parent_piece: Piece3D
var _checkpoint_transform: Transform3D
var _checkpoint_properties: Dictionary[NodePath, Variant] = {}

func _enter_tree() -> void:
    piece = get_parent() as Piece3D

    if piece and not _has_entered_tree:
        _has_entered_tree = true
        _checkpoint_active = piece._original_active
        _checkpoint_parent_piece = piece._original_parent_piece
        _checkpoint_transform = piece._original_transform

func _exit_tree() -> void:
    piece = null

## Get checkpoint value for a tracked property registered with `Piece3D.register_property`
func get_checkpoint_value(property_path: NodePath) -> Variant:
    return _checkpoint_properties.get(property_path)

## Set checkpoint value for a tracked property registered with `Piece3D.register_property`
func set_checkpoint_value(property_path: NodePath, value: Variant) -> void:
    _checkpoint_properties.set(property_path, value)

## Save current state for checkpoint
func set_checkpoint() -> void:
    _checkpoint_active = piece.active
    _checkpoint_parent_piece = piece.parent_piece
    _checkpoint_transform = piece.global_transform
    _checkpoint_properties = piece.get_property_values()

## Reset to checkpoint state
func reset_to_checkpoint() -> void:
    piece._teleport(_checkpoint_active, _checkpoint_parent_piece, _checkpoint_transform, _checkpoint_properties)

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
    for property_path in piece._extra_property_paths:
        var original_value: Variant = piece.get_original_value(property_path)
        if piece.get_value(property_path) != original_value:
            return true
        if get_checkpoint_value(property_path) != original_value:
            return true
    
    return false

func _set_piece(value: Piece3D) -> void:
    if piece:
        piece.history = null
        piece.property_registered.disconnect(_on_property_registered)
    piece = value
    if value:
        value.history = self
        piece.property_registered.connect(_on_property_registered)

func _on_property_registered(property_path: NodePath) -> void:
    set_checkpoint_value(property_path, piece.get_value(property_path))
