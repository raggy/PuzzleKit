class_name TweenPieceAnimation3D
extends PieceAnimation3D

@export var position_tween_duration: float
@export var position_tween_ease: Tween.EaseType
@export var position_tween_trans: Tween.TransitionType
@export var position_catchup_duration: float
@export var position_catchup_ease: Tween.EaseType
@export var position_catchup_trans: Tween.TransitionType
@export var rotation_tween_duration: float
@export var rotation_tween_ease: Tween.EaseType
@export var rotation_tween_trans: Tween.TransitionType

var tween: Tween
var position_base: Vector3: set = _set_position_base
var position_offset: Vector3: set = _set_position_offset

func _start() -> void:
    tween = create_tween()

    if piece_visual_cached_transform != piece_transform_end:
        tween.tween_property(self, "position_base", piece_transform_end.origin, position_tween_duration).from(piece_visual_cached_transform.origin).set_ease(position_tween_ease).set_trans(position_tween_trans)
        tween.parallel().tween_property(self, "position_offset", Vector3.ZERO, position_catchup_duration).from(visual.position - piece_visual_cached_transform.origin).set_ease(position_catchup_ease).set_trans(position_catchup_trans)
        tween.parallel().tween_property(visual, "quaternion", piece_transform_end.basis.get_rotation_quaternion(), rotation_tween_duration).set_ease(rotation_tween_ease).set_trans(rotation_tween_trans)
    
    if piece_visual_cached_active != piece_will_be_active:
        tween.tween_callback(func() -> void: visual.visible = piece_will_be_active)

    tween.tween_callback(_tween_done)

func _tween_done() -> void:
    done()

func _finish() -> void:
    visual.position = piece_transform_end.origin
    visual.quaternion = piece_transform_end.basis.get_rotation_quaternion()
    visual.visible = piece_will_be_active

func _clean_up() -> void:
    if tween:
        tween.kill()
        tween = null

func _set_position_base(value: Vector3) -> void:
    position_base = value
    visual.position = position_base + position_offset

func _set_position_offset(value: Vector3) -> void:
    position_offset = value
    visual.position = position_base + position_offset
