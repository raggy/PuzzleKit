class_name PieceAnimation3D
extends Node

enum State {
    PRE_SETUP,
    SETUP,
    STARTING,
    PLAYING,
    FINISHED,
    STOPPED,
}

signal started()
signal finished()
signal stopped()

var state: State = State.PRE_SETUP
var visual: PieceVisual3D
var piece_was_active: bool
var piece_will_be_active: bool
var piece_transform_start: Transform3D
var piece_transform_end: Transform3D

var _done_immediately: bool
var _queued_after: Array[PieceAnimation3D] = []

func setup(_visual: PieceVisual3D) -> void:
    if state != State.PRE_SETUP:
        return
    
    state = State.SETUP
    visual = _visual
    piece_was_active = visual.piece._previous_active
    piece_will_be_active = visual.piece.active
    piece_transform_start = visual.piece._previous_transform
    piece_transform_end = visual.piece.global_transform

    _setup()

func start() -> void:
    if state != State.SETUP:
        return
    
    state = State.STARTING
    _start()
    
    if state == State.STOPPED:
        return

    state = State.PLAYING
    started.emit()

    if _done_immediately:
        _do_done()

func done() -> void:
    if state == State.STARTING:
        _done_immediately = true
        return
    
    if state != State.SETUP and state != State.PLAYING:
        return
        
    _do_done()

func finish() -> void:
    if state != State.SETUP and state != State.PLAYING:
        return
    
    _clean_up()
    _finish()

    state = State.FINISHED
    finished.emit()

func stop() -> void:
    if state != State.PLAYING:
        return
    
    _clean_up()
    _stop()
    
    state = State.STOPPED
    stopped.emit()

func _do_done() -> void:
    _clean_up()
    _done()

    state = State.FINISHED
    finished.emit()

func _setup() -> void:
    pass

func _start() -> void:
    pass

func _done() -> void:
    pass

func _finish() -> void:
    pass

func _stop() -> void:
    pass

func _clean_up() -> void:
    pass
