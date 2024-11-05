class_name PieceAnimator3D
extends Node

var _board: Board3D: set = _set_board

var _animations_playing: Array[PieceAnimation3D] = []
var _animations_queued: Array[PieceAnimation3D] = []

func _enter_tree() -> void:
    for node in get_parent().get_children():
        if node is Board3D:
            _board = node as Board3D

func _exit_tree() -> void:
    _board = null

## Play animation now
func play(animation: PieceAnimation3D):
    # TODO: Queue up animation until board.commit_changes() is called, so we can tell if we need to make a default animation
    # Maybe store this animation on the PieceVisual3D?
    add_child(animation)
    _animations_playing.append(animation)
    animation.finished.connect(_on_animation_finished.bind(animation))
    animation.start()
    animation.visual._has_animation_this_step = true
    animation.visual.animation = animation

## Queue animation to play after a specific other animation
func queue_after(animation: PieceAnimation3D, after_animation: PieceAnimation3D):
    animation._queued_after = after_animation
    animation.visual._has_animation_this_step = true
    _animations_queued.append(animation)

## Queue animation to play after the piece's latest animation in the queue
func queue_for(animation: PieceAnimation3D, piece: Piece3D):
    var after_animation := _find_latest_animation_for_piece(piece)

    if not after_animation:
        play(animation)
        return
    
    queue_after(animation, after_animation)

func finish(animation: PieceAnimation3D):
    _finish_animations([animation])

func finish_all():
    _finish_animations(_animations_playing.duplicate())

func stop(animation: PieceAnimation3D):
    var animations_to_stop: Array[PieceAnimation3D] = [animation]

    # Keep removing queued animations until we're done
    while (animations_to_stop.size() > 0):
        var animation_to_stop := animations_to_stop.pop_back()
        
        if _animations_playing.has(animation_to_stop):
            animation_to_stop.stop()
            _animations_playing.erase(animation_to_stop)
        
        if _animations_queued.has(animation_to_stop):
            _animations_queued.erase(animation_to_stop)

        for queued_animation in _animations_queued:
            if queued_animation._queued_after == animation_to_stop:
                animations_to_stop.append(queued_animation)
        
        animation_to_stop.queue_free()
    
    # Clear queued animations just in case any were orphaned
    _animations_queued.clear()

## Stop animations for piece
func stop_for(piece: Piece3D):
    _stop_for_in_list(piece, _animations_playing)
    _stop_for_in_list(piece, _animations_queued)

func _set_board(value: Board3D):
    if _board:
        _board.piece_removed.disconnect(stop_for)
        _board.changes_committing.disconnect(_play_default_animations)
    _board = value
    if value:
        value.piece_removed.connect(stop_for)
        value.changes_committing.connect(_play_default_animations)

func _finish_animations(animations_to_finish: Array[PieceAnimation3D]):
    # Keep removing queued animations until we're done
    while (animations_to_finish.size() > 0):
        var animation_to_finish := animations_to_finish.pop_back()
        
        if _animations_playing.has(animation_to_finish):
            animation_to_finish.finish()
        
        if _animations_queued.has(animation_to_finish):
            animation_to_finish.finish()
            _animations_queued.erase(animation_to_finish)

        for queued_animation in _animations_queued:
            if queued_animation._queued_after == animation_to_finish:
                animations_to_finish.append(queued_animation)
        
        animation_to_finish.queue_free()
    
    # Clear queued animations just in case any were orphaned
    _animations_queued.clear()

func _stop_for_in_list(piece: Piece3D, animation_list: Array[PieceAnimation3D]):
    var animations_stopped := 0
    for i in range(animation_list.size()):
        var animation := animation_list[i - animations_stopped]
        if animation.visual.piece != piece:
            continue
        animation_list.remove_at(i - animations_stopped)
        animations_stopped += 1
        stop(animation)

func _on_animation_finished(animation: PieceAnimation3D):
    animation.visual.animation = null
    _animations_playing.erase(animation)
    animation.queue_free()

    var animations_played := 0
    for i in range(_animations_queued.size()):
        var queued_animation := _animations_queued[i - animations_played]
        if queued_animation._queued_after != animation:
            continue
        _animations_queued.remove_at(i - animations_played)
        animations_played += 1
        play(queued_animation)

func _find_latest_animation_for_piece(piece: Piece3D) -> PieceAnimation3D:
    # Search queued animations
    for i in range(_animations_queued.size() - 1, -1, -1):
        var animation := _animations_queued[i]

        if animation.visual.piece == piece:
            return animation
    
    # Search playing animations
    for i in range(_animations_playing.size() - 1, -1, -1):
        var animation := _animations_playing[i]

        if animation.visual.piece == piece:
            return animation
    
    return null

func _play_default_animations():
    for piece in _board._pieces:
        if not piece.visual:
            continue
        
        var animation := piece.visual.create_default_animation()
        # Reset for next step
        piece.visual._has_animation_this_step = false
        # Doesn't want to play an animation
        if not animation:
            continue
        play(animation)
        # Reset for next step
        piece.visual._has_animation_this_step = false
