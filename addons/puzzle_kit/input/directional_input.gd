@icon("res://addons/puzzle_kit/icons/directional_input.svg")
class_name DirectionalInput
extends Node

@export_group("Action Bindings")
@export var action_up: StringName = "up"
@export var action_down: StringName = "down"
@export var action_left: StringName = "left"
@export var action_right: StringName = "right"

@export_group("Behavior")
## If true, will alternate between diagonals when held. Else, will repeat the most recent direction
@export var alternate_diagonals: bool = true

var enabled: bool = true: set = set_enabled
var input: Callable

var _last_accepted_direction := Vector2i.ZERO
var _repeat_direction_h := Vector2i.ZERO
var _repeat_direction_v := Vector2i.ZERO

func _process(_delta: float) -> void:
    # Handle newly-pressed input directions
    if Input.is_action_just_pressed(action_up):
        _input_immediately(Vector2i.UP)
        # Repeat if action is held
        if Input.is_action_pressed(action_up):
            _repeat_direction_v = Vector2i.UP
    elif Input.is_action_just_pressed(action_down):
        _input_immediately(Vector2i.DOWN)
        # Repeat if action is held
        if Input.is_action_pressed(action_down):
            _repeat_direction_v = Vector2i.DOWN
    elif Input.is_action_just_pressed(action_left):
        _input_immediately(Vector2i.LEFT)
        # Repeat if action is held
        if Input.is_action_pressed(action_left):
            _repeat_direction_h = Vector2i.LEFT
    elif Input.is_action_just_pressed(action_right):
        _input_immediately(Vector2i.RIGHT)
        # Repeat if action is held
        if Input.is_action_pressed(action_right):
            _repeat_direction_h = Vector2i.RIGHT
    
    # Clear repeat directions upon input release
    if Input.is_action_just_released(action_up) and _repeat_direction_v == Vector2i.UP:
        _repeat_direction_v = Vector2i.ZERO
    if Input.is_action_just_released(action_down) and _repeat_direction_v == Vector2i.DOWN:
        _repeat_direction_v = Vector2i.ZERO
    if Input.is_action_just_released(action_left) and _repeat_direction_h == Vector2i.LEFT:
        _repeat_direction_h = Vector2i.ZERO
    if Input.is_action_just_released(action_right) and _repeat_direction_h == Vector2i.RIGHT:
        _repeat_direction_h = Vector2i.ZERO

func _input_immediately(direction: Vector2i) -> bool:
    if not input:
        return false
    
    if not input.call(direction):
        return false

    _last_accepted_direction = direction
    
    return true

func _stop_movement():
    _last_accepted_direction = Vector2i.ZERO

func repeat():
    if alternate_diagonals:
        _repeat_alternate_diagonals()
    else:
        _repeat_latest_direction()

func _repeat_alternate_diagonals():
    # Last direction was horizontal and there's a vertical direction held
    if _repeat_direction_v != Vector2i.ZERO and (_last_accepted_direction == Vector2i.LEFT or _last_accepted_direction == Vector2i.RIGHT) and _input_immediately(_repeat_direction_v):
        return
    # Last direction was vertical and there's a horizontal direction held
    if _repeat_direction_h != Vector2i.ZERO and (_last_accepted_direction == Vector2i.UP or _last_accepted_direction == Vector2i.DOWN) and _input_immediately(_repeat_direction_h):
        return
    # There's a vertical direction held
    if _repeat_direction_v != Vector2i.ZERO and _input_immediately(_repeat_direction_v):
        return
    # There's a horizontal direction held
    if _repeat_direction_h != Vector2i.ZERO and _input_immediately(_repeat_direction_h):
        return
    # No directions held, so stop
    _stop_movement()

func _repeat_latest_direction():
    # Last direction was horizontal and it's still held
    if _last_accepted_direction == _repeat_direction_h and _input_immediately(_repeat_direction_h):
        return
    # Last direction was vertical and it's still held
    if _last_accepted_direction == _repeat_direction_v and _input_immediately(_repeat_direction_v):
        return
    # There's a vertical direction held
    if _repeat_direction_v != Vector2i.ZERO and _input_immediately(_repeat_direction_v):
        return
    # There's a horizontal direction held
    if _repeat_direction_h != Vector2i.ZERO and _input_immediately(_repeat_direction_h):
        return
    # No directions held, so stop
    _stop_movement()

func set_enabled(value: bool):
    if enabled == value:
        return
    
    enabled = value

    if enabled:
        enable()
    else:
        disable()

func enable():
    pass

func disable():
    _last_accepted_direction = Vector2i.ZERO
    _repeat_direction_h = Vector2i.ZERO
    _repeat_direction_v = Vector2i.ZERO
