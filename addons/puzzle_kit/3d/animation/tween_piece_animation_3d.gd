extends PieceAnimation3D

@export var position_tween_duration: float
@export var position_catchup_duration: float
@export var rotation_tween_duration: float

var tween: Tween
var position_base: Vector3: set = _set_position_base
var position_offset: Vector3: set = _set_position_offset

func start() -> void:
    tween = create_tween()

    if piece_transform_start != piece_transform_end:
        tween.tween_property(self, "position_base", piece_transform_end.origin, position_tween_duration).from(piece_transform_start.origin)
        tween.parallel().tween_property(self, "position_offset", Vector3.ZERO, position_catchup_duration).from(visual.position - piece_transform_start.origin)
        tween.parallel().tween_property(visual, "quaternion", piece_transform_end.basis.get_rotation_quaternion(), rotation_tween_duration)
    
    if piece_was_active != piece_will_be_active:
        tween.tween_callback(func(): visual.visible = piece_will_be_active)

    tween.tween_callback(finish)

    super.start()

func finish() -> void:
    _clean_up()
    
    visual.position = piece_transform_end.origin
    visual.quaternion = piece_transform_end.basis.get_rotation_quaternion()
    visual.visible = piece_will_be_active

    super.finish()

func stop() -> void:
    _clean_up()

    super.stop()

func _clean_up():
    if tween:
        tween.kill()
        tween = null

func _set_position_base(value: Vector3):
    position_base = value
    visual.position = position_base + position_offset

func _set_position_offset(value: Vector3):
    position_offset = value
    visual.position = position_base + position_offset
