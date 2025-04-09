class_name PieceAnimator3D
extends Node

signal animation_started(animation: PieceAnimation3D)
signal animation_finished(animation: PieceAnimation3D)
signal animation_stopped(animation: PieceAnimation3D)

var _board: Board3D: set = _set_board

var _animations_playing: Array[PieceAnimation3D] = []
var _animations_queued: Array[PieceAnimation3D] = []

func _enter_tree() -> void:
    _board = get_parent() as Board3D

func _exit_tree() -> void:
    _board = null

func _notification(what: int) -> void:
    if what == NOTIFICATION_PREDELETE:
        _queue_free_animations(_animations_playing)
        _queue_free_animations(_animations_queued)

## Play animation now
func play(animation: PieceAnimation3D) -> void:
    # TODO: Queue up animation until board.commit_changes() is called, so we can tell if we need to make a default animation
    # Maybe store this animation on the PieceVisual3D?
    add_child(animation, true)
    _animations_playing.append(animation)
    animation.finished.connect(_on_animation_finished.bind(animation))
    animation.stopped.connect(_on_animation_stopped.bind(animation))
    animation.visual._has_animation_this_step = true
    animation.visual.animation = animation
    animation.start()

    animation_started.emit(animation)

## Queue animation to play after one or more specific animations
func queue_after(animation: PieceAnimation3D, after_animations: Array[PieceAnimation3D]) -> void:
    animation._queued_after = after_animations.duplicate()
    animation.visual._has_animation_this_step = true
    _animations_queued.append(animation)

## Queue animation to play after the piece's latest animation in the queue
func queue_for(animation: PieceAnimation3D, piece: Piece3D) -> void:
    var after_animation := _find_latest_animation_for_piece(piece)

    if not after_animation:
        play(animation)
        return
    
    animation._queued_after = [after_animation]
    animation.visual._has_animation_this_step = true
    _animations_queued.append(animation)

## Remove animation from the queue (and all animations queued after it)
func unqueue(animation: PieceAnimation3D) -> void:
    if not animation or not _animations_queued.has(animation):
        return

    var animations_to_unqueue: Array[PieceAnimation3D] = [animation]
    
    # Keep removing queued animations until we're done
    while (animations_to_unqueue.size() > 0):
        var animation_to_unqueue := animations_to_unqueue[0]
        animations_to_unqueue.remove_at(0)

        if _animations_queued.has(animation_to_unqueue):
            _animations_queued.erase(animation_to_unqueue)
            animation_to_unqueue.queue_free()

        for queued_animation in _animations_queued:
            if queued_animation._queued_after.has(animation_to_unqueue):
                animations_to_unqueue.append(queued_animation)

func finish(animation: PieceAnimation3D) -> void:
    _finish_animations([animation])

func finish_all(group: String = "") -> void:
    # No group filter, finish all playing animations
    if group.is_empty():
        _finish_animations(_animations_playing.duplicate())
    else:
    # Finish all playing animations for pieces in group
        _finish_animations(_animations_playing.filter(_is_animation_piece_in_group.bind(group)))

## Finish animations for piece
func finish_for(piece: Piece3D) -> void:
    _finish_animations(_animations_playing.filter(_does_animation_belong_to_piece.bind(piece)))
    _finish_animations(_animations_queued.filter(_does_animation_belong_to_piece.bind(piece)))

func stop(animation: PieceAnimation3D) -> void:
    _stop_animations([animation])

func stop_all(group: String = "") -> void:
    # No group filter, stop all playing animations
    if group.is_empty():
        _stop_animations(_animations_playing.duplicate())
    else:
    # Stop all playing animations for pieces in group
        _stop_animations(_animations_playing.filter(_is_animation_piece_in_group.bind(group)))

## Stop animations for piece
func stop_for(piece: Piece3D) -> void:
    _stop_animations(_animations_playing.filter(_does_animation_belong_to_piece.bind(piece)))
    _stop_animations(_animations_queued.filter(_does_animation_belong_to_piece.bind(piece)))

## Return a count of all animations queued for a piece
func count_queued_animations_for(piece: Piece3D) -> int:
    var count := 0
    for queued_animation in _animations_queued:
        if queued_animation.visual.piece == piece:
            count += 1
    return count

## Return an array of all animations queued for a piece
func get_queued_animations_for(piece: Piece3D) -> Array[PieceAnimation3D]:
    return _animations_queued.filter(func(animation: PieceAnimation3D) -> bool: return animation.visual.piece == piece)

func get_latest_queued_animation_for(piece: Piece3D) -> PieceAnimation3D:
    # Search queued animations
    for i in range(_animations_queued.size() - 1, -1, -1):
        var animation := _animations_queued[i]

        if animation.visual.piece == piece:
            return animation
    
    return null

func _set_board(value: Board3D) -> void:
    if _board:
        _board.piece_removed.disconnect(stop_for)
        _board.changes_committing.disconnect(_play_default_animations)
    _board = value
    if value:
        value.piece_removed.connect(stop_for)
        value.changes_committing.connect(_play_default_animations)

func _finish_animations(animations_to_finish: Array[PieceAnimation3D]) -> void:
    # Keep finishing animations until we're done
    while (animations_to_finish.size() > 0):
        var animation_to_finish := animations_to_finish[0]
        animations_to_finish.remove_at(0)

        # Any animations queued to play after this one should also be finished
        for queued_animation in _animations_queued:
            if queued_animation._queued_after.has(animation_to_finish):
                animations_to_finish.append(queued_animation)
        
        # If animation was playing, finish it
        if _animations_playing.has(animation_to_finish):
            animation_to_finish.finish()
        
        # If animation was queued, finish it
        if _animations_queued.has(animation_to_finish):
            animation_to_finish.finish()
            _animations_queued.erase(animation_to_finish)
        
        animation_to_finish.queue_free()

func _stop_animations(animations_to_stop: Array[PieceAnimation3D]) -> void:
    # Keep stopping animations until we're done
    while (animations_to_stop.size() > 0):
        var animation_to_stop := animations_to_stop[0]
        animations_to_stop.remove_at(0)

        # If animation was playing, stop it
        if _animations_playing.has(animation_to_stop):
            animation_to_stop.stop()
            _animations_playing.erase(animation_to_stop)
        
        # If animation was still queued, no need to stop it
        if _animations_queued.has(animation_to_stop):
            _animations_queued.erase(animation_to_stop)
            animation_to_stop.queue_free()

        # Any animations queued to play after this one should also be stopped
        for queued_animation in _animations_queued:
            if queued_animation._queued_after.has(animation_to_stop):
                animations_to_stop.append(queued_animation)

func _on_animation_finished(animation: PieceAnimation3D) -> void:
    animation.visual.animation = null
    _animations_playing.erase(animation)
    animation.queue_free()

    var animations_played := 0
    for i in range(_animations_queued.size()):
        var queued_animation := _animations_queued[i - animations_played]
        queued_animation._queued_after.erase(animation)
        # Queued animation is still waiting on other animations to finish
        if queued_animation._queued_after.size() > 0:
            continue
        _animations_queued.remove_at(i - animations_played)
        animations_played += 1
        play(queued_animation)
    
    animation_finished.emit(animation)

func _on_animation_stopped(animation: PieceAnimation3D) -> void:
    animation.visual.animation = null
    _animations_playing.erase(animation)
    animation.queue_free()
    
    animation_stopped.emit(animation)

func _does_animation_belong_to_piece(animation: PieceAnimation3D, piece: Piece3D) -> bool:
    return animation.visual.piece == piece

func _play_default_animations() -> void:
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

func _queue_free_animations(animations: Array[PieceAnimation3D]) -> void:
    for animation in animations:
        # Animation already freed
        if not animation or animation.is_queued_for_deletion():
            continue
        animation.queue_free()
    
    animations.clear()

#region Filters
func _is_animation_piece_in_group(animation: PieceAnimation3D, group: String) -> bool:
    return animation.visual.piece.is_in_group(group)

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
#endregion
