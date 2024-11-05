class_name History3D
extends Node

signal undo_step_created(step: PieceStateSnapshot3D)

@export_group("Action Bindings")
@export var action_undo: StringName = "undo"
@export var action_reset: StringName = "reset"

var _board: Board3D: set = _set_board
var _checkpoint: PieceStateSnapshot3D
var _undo_steps: Array[PieceStateSnapshot3D] = []

func _enter_tree():
    for node in get_parent().get_children():
        if node is Board3D:
            _board = node as Board3D

func _exit_tree() -> void:
    _board = null

func checkpoint():
    _checkpoint = PieceStateSnapshot3D.new()

    for piece in _board._pieces:
        if not piece.history:
            continue
        
        _checkpoint.states.append(piece.history.get_current_state())

func reset():
    if not _checkpoint:
        return
        
    var undo_step := PieceStateSnapshot3D.new()
    # Create undo step with all the pieces that have changed
    for state in _checkpoint.states:
        undo_step.states.append(state.piece.history.get_current_state())
    _undo_steps.append(undo_step)
    # TODO Mark this step as "important"
    
    _checkpoint.apply()

func undo() -> bool:
    if _undo_steps.size() == 0:
        return false
    
    var step := _undo_steps.pop_back()
    step.apply()

    return true

func undo_until(step: PieceStateSnapshot3D) -> bool:
    var step_index := _undo_steps.find(step)
    # Not a valid step
    if step_index == -1:
        return false
    
    # step is the most recent
    if step_index == _undo_steps.size() - 1:
        return false
    
    # Undo all the steps that were created after `saved_step`
    for i in range(_undo_steps.size() - step_index - 1):
        var head := _undo_steps.pop_back()
        head.apply()
    
    return true

func _process(_delta: float) -> void:
    if InputMap.has_action(action_undo) and Input.is_action_just_pressed(action_undo):
        undo()
    
    if InputMap.has_action(action_reset) and Input.is_action_just_pressed(action_reset):
        reset()

func _set_board(value: Board3D):
    if _board:
        _board.changes_committing.disconnect(_create_undo_step)
    _board = value
    if value:
        value.changes_committing.connect(_create_undo_step)

func _create_undo_step():
    var undo_step := PieceStateSnapshot3D.new()

    for piece in _board._pieces:
        # We don't track this piece
        if not piece.history:
            continue
        # Piece didn't change
        if not piece.history.has_changed():
            continue
        undo_step.states.append(piece.history.get_previous_state())
 
    # No pieces changed
    if undo_step.states.size() == 0:
        return
    
    _undo_steps.push_back(undo_step)
    undo_step_created.emit(undo_step)
    
    _undo_steps.push_back(undo_step)
    undo_step_created.emit(undo_step)
