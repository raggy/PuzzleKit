class_name History3D
extends Node

signal resetted()
signal undid()
signal undo_step_created(step: PieceStateSnapshot3D)

enum UndoBehavior {
    ## Each `undo()` call will undo exactly one step
    STEP_BY_STEP,
    ## `undo()` will stop before and after steps marked as `important`
    STOP_AT_IMPORTANT_STEPS,
}

@export_group("Action Bindings")
@export var action_undo: StringName = "undo"
@export var action_reset: StringName = "reset"

@export_group("Behavior")
@export var undo_behavior: UndoBehavior = UndoBehavior.STEP_BY_STEP
## Which group should we keep track of? (Or all if left blank)
@export var group_filter: String = ""
## Should we free inactive pieces that aren't referenced in our history?
@export var auto_free_inactive_orphaned_pieces: bool = true

var _board: Board3D: set = _set_board
var _undo_steps: Array[PieceStateSnapshot3D] = []

var _recently_deactivated_pieces: Array[Piece3D] = []

func _enter_tree() -> void:
    _board = get_parent() as Board3D

func _exit_tree() -> void:
    _board = null

func checkpoint() -> void:
    for piece in _board._pieces:
        # We don't track this piece
        if not piece.history:
            continue
        # Piece doesn't match the group filter
        if group_filter and not piece.is_in_group(group_filter):
            continue
        
        piece.history.set_checkpoint()

func reset() -> void:
    # Create undo step with all the pieces that have changed
    var undo_step := PieceStateSnapshot3D.new()
    undo_step.important = true
    _undo_steps.append(undo_step)

    for piece in _board._pieces:
        # We don't track this piece
        if not piece.history:
            continue
        # Piece doesn't match the group filter
        if group_filter and not piece.is_in_group(group_filter):
            continue
        
        undo_step.states.append(piece.history.get_current_state())
        piece.history.reset_to_checkpoint()
    
    resetted.emit()

func undo() -> bool:
    var result := false

    match undo_behavior:
        UndoBehavior.STEP_BY_STEP: result = _undo_step_by_step()
        UndoBehavior.STOP_AT_IMPORTANT_STEPS: result = _undo_stop_at_important_steps()
        _: printerr("History3D: Invalid UndoBehavior")
    
    if result and auto_free_inactive_orphaned_pieces:
        _free_inactive_orphaned_pieces()

    _recently_deactivated_pieces.clear()

    if result:
        undid.emit()
    
    return result

func clear_undo_history() -> void:
    _undo_steps.clear()

func _process(_delta: float) -> void:
    if InputMap.has_action(action_undo) and Input.is_action_just_pressed(action_undo):
        undo()
    
    if InputMap.has_action(action_reset) and Input.is_action_just_pressed(action_reset):
        reset()

func _set_board(value: Board3D) -> void:
    if _board:
        _board.changes_committing.disconnect(_create_undo_step)
    _board = value
    if value:
        value.changes_committing.connect(_create_undo_step)

func _create_undo_step() -> void:
    var undo_step := PieceStateSnapshot3D.new()

    for piece in _board._pieces:
        # We don't track this piece
        if not piece.history:
            continue
        # Piece doesn't match the group filter
        if group_filter and not piece.is_in_group(group_filter):
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

    # print("%s Created undo step" % name)

func _free_inactive_orphaned_pieces() -> void:
    _remove_pieces_that_will_reactivate(_recently_deactivated_pieces)

    for piece in _recently_deactivated_pieces:
        # print("%s Auto-freeing %s" % [name, piece])
        if piece.get_parent():
            piece.get_parent().remove_child(piece)
        piece.queue_free()

func _remove_pieces_that_will_reactivate(pieces: Array[Piece3D]) -> void:
    for step in _undo_steps:
        for state in step.states:
            if state.active:
                pieces.erase(state.piece)

func _undo_step_by_step() -> bool:
    if _undo_steps.size() == 0:
        return false
    
    var step := _undo_steps[-1]
    _undo_steps.pop_back()
    _apply_undo_step(step)

    return true

func _undo_stop_at_important_steps() -> bool:
    if _undo_steps.size() == 0:
        return false
    
    var important_step_index := _find_most_recent_important_step()
    
    # Most recent step is important, undo once
    if important_step_index == _undo_steps.size() - 1:
        var step := _undo_steps[-1]
        _undo_steps.pop_back()
        _apply_undo_step(step)
        return true
    
    # Undo all the steps that were created after most recent important step
    for i in range(_undo_steps.size() - important_step_index - 1):
        var head := _undo_steps[-1]
        _undo_steps.pop_back()
        _apply_undo_step(head)
    
    return true

func _find_most_recent_important_step() -> int:
    for step_index in range(_undo_steps.size() - 1, -1, -1):
        if _undo_steps[step_index].important:
            return step_index
    # Couldn't find an important step
    return -1

func _apply_undo_step(step: PieceStateSnapshot3D) -> void:
    # Keep track of recently deactivated pieces
    if auto_free_inactive_orphaned_pieces:
        for state in step.states:
            if state.piece.active and not state.active and not state.piece.history._in_checkpoint:
                _recently_deactivated_pieces.append(state.piece)
    
    step.apply()
