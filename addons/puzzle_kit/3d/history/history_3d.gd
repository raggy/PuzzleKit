class_name History3D
extends Node

signal undo_step_created(step: UndoStep3D)

@export_group("Action Bindings")
@export var action_undo: StringName = "undo"

var _board: Board3D: set = _set_board
var _undo_steps: Array[UndoStep3D] = []

func _enter_tree():
    for node in get_parent().get_children():
        if node is Board3D:
            _board = node as Board3D

func _exit_tree() -> void:
    _board = null

func undo() -> bool:
    if _undo_steps.size() == 0:
        return false
    
    var step := _undo_steps.pop_back()
    step.undo()

    return true

func undo_until(step: UndoStep3D) -> bool:
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
        head.undo()
    
    return true

func _process(_delta: float) -> void:
    if InputMap.has_action(action_undo) and Input.is_action_just_pressed(action_undo):
        undo()

func _set_board(value: Board3D):
    if _board:
        _board.changes_committing.disconnect(_create_undo_step)
    _board = value
    if value:
        value.changes_committing.connect(_create_undo_step)

func _create_undo_step():
    var undo_step := UndoStep3D.new()

    for piece in _board._pieces:
        var change := _get_piece_change(piece)
        # Piece didn't change
        if not change:
            continue
        undo_step.changes.append(change)
    
    # No pieces changed
    if undo_step.changes.size() == 0:
        return
    
    _undo_steps.push_back(undo_step)
    undo_step_created.emit(undo_step)

func _get_piece_change(piece: Piece3D) -> PieceChange3D:
    if not piece.has_changes():
        return null
    
    var change := PieceChange3D.new()
    change.piece = piece
    change.previous_transform = piece._previous_transform
    change.new_transform = piece.transform
    return change
