class_name PieceAnimator3D
extends Node

var _board: Board3D: set = _set_board

var _animations_playing: Array[PieceAnimation3D] = []
var _animations_queued: Array[PieceAnimation3D] = []

func _enter_tree() -> void:
    _board = get_parent() as Board3D

func _exit_tree() -> void:
    _board = null

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

## Queue animation to play after a specific other animation
func queue_after(animation: PieceAnimation3D, after_animation: PieceAnimation3D) -> void:
    animation._queued_after = after_animation
    animation.visual._has_animation_this_step = true
    _animations_queued.append(animation)

## Queue animation to play after the piece's latest animation in the queue
func queue_for(animation: PieceAnimation3D, piece: Piece3D) -> void:
    var after_animation := _find_latest_animation_for_piece(piece)

    if not after_animation:
        play(animation)
        return
    
    queue_after(animation, after_animation)

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
            if queued_animation._queued_after == animation_to_unqueue:
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
    # Keep removing queued animations until we're done
    while (animations_to_finish.size() > 0):
        var animation_to_finish := animations_to_finish[0]
        animations_to_finish.remove_at(0)

        for queued_animation in _animations_queued:
            if queued_animation._queued_after == animation_to_finish:
                animations_to_finish.append(queued_animation)
        
        if _animations_playing.has(animation_to_finish):
            animation_to_finish.finish()
        
        if _animations_queued.has(animation_to_finish):
            animation_to_finish.finish()
            _animations_queued.erase(animation_to_finish)
        
        animation_to_finish.queue_free()

func _stop_animations(animations_to_stop: Array[PieceAnimation3D]) -> void:
    # Keep removing queued animations until we're done
    while (animations_to_stop.size() > 0):
        var animation_to_stop := animations_to_stop[0]
        animations_to_stop.remove_at(0)

        if _animations_playing.has(animation_to_stop):
            animation_to_stop.stop()
            _animations_playing.erase(animation_to_stop)
        
        if _animations_queued.has(animation_to_stop):
            _animations_queued.erase(animation_to_stop)
            animation_to_stop.queue_free()

        for queued_animation in _animations_queued:
            if queued_animation._queued_after == animation_to_stop:
                animations_to_stop.append(queued_animation)

func _on_animation_finished(animation: PieceAnimation3D) -> void:
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

func _on_animation_stopped(animation: PieceAnimation3D) -> void:
    animation.visual.animation = null
    _animations_playing.erase(animation)
    animation.queue_free()

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
