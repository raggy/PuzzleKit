extends Node3D

const MAX_PUSH_PIECES := 8

@onready var board := $Board3D as Board3D
@onready var animator := $Board3D/PieceAnimator3D as PieceAnimator3D
@onready var directions := $DirectionalInput as DirectionalInput
@onready var history := $Board3D/History3D as History3D
@onready var player := $Board3D/Player as Piece3D

var group_checkpoint := GroupFilter.new().with("checkpoint")
var group_blocking := GroupFilter.new().with_any(["pushable", "rock"])
var group_pushable := GroupFilter.new().with("pushable")
var group_rolls := GroupFilter.new().with("coconut")
var group_sand := GroupFilter.new().with("sand")
var group_shell := GroupFilter.new().with("shell")
var group_standable := GroupFilter.new().with_any(["grass", "sand", "coconut"])

func _ready() -> void:
    directions.input = _move
    history.undo_step_created.connect(func(step: PieceStateSnapshot3D) -> void: if step.has_a_piece_that_matches(group_pushable): step.stop_after = true; step.stop_before = true)

    # Create initial checkpoint
    history.checkpoint()

    var player_shell := player.get_first_child_piece_matching(group_shell)
    # Teleport player's shell on-the-spot to set correct visual state on first play
    if player_shell:
        player_shell._teleport(player_shell.active, player_shell.parent_piece, player_shell.global_transform)

func _process(_delta: float) -> void:
    if Input.is_action_just_pressed("swap"):
        _swap()

func _move(direction_2d: Vector2i) -> bool:
    var direction := Vector3i(direction_2d.x, 0, direction_2d.y)

    # Nothing to walk onto
    if board.is_empty(player.grid_position + direction + Vector3i.DOWN, group_standable):
        return false
    
    # Push
    var pushable := board.get_piece_at(player.grid_position + direction, group_pushable)
    var pushed := pushable and _push(pushable, direction)
    # Tried to push but it was blocked
    if pushable and not pushed:
        return false
    
    var blocked := board.is_occupied(player.grid_position + direction, group_blocking)
    # We're blocked from moving but didn't push anything
    if blocked and not pushed:
        return false
    
    # Face movement direction
    player.basis = Basis.looking_at(direction)
    # Move in direction
    if not blocked:
        player.grid_position = player.grid_position + direction

    var checkpoint := board.get_piece_at(player.grid_position, group_checkpoint)
    # Reached a checkpoint
    if checkpoint:
        checkpoint.active = false
        history.checkpoint()

    animator.stop_for(player)
    
    var player_shell := player.get_first_child_piece_matching(group_shell)
    if player_shell:
        animator.stop_for(player_shell)
        animator.play(player_shell.visual.create_animation(player_shell.visual.default_animation))

    board.commit_changes()

    if player.visual.animation:
        player.visual.animation.finished.connect(directions.repeat)

    return true

func _push(pushable: Piece3D, direction: Vector3i, pushed_by: Piece3D = null) -> bool:
    var pushable_pieces: Array[Piece3D] = [pushable]
    # If we're trying to push a piece that's contained within another piece, push that instead
    if pushable.parent_piece:
        pushable_pieces = pushable.parent_piece.get_child_pieces()
        pushable = pushable.parent_piece

    var blocking_pieces := board.get_pieces_touching(pushable_pieces, group_blocking, [direction], 1)
    # There's multiple things blocking it, too heavy to chain push
    if blocking_pieces.size() > 1:
        return false
    # There's one thing blocking it from being pushed so we won't move
    if blocking_pieces.size() == 1:
        var blocking_piece := blocking_pieces[0]
        # If the blocking piece is pushable, push it instead
        if blocking_piece.matches(group_pushable):
            return _push(blocking_piece, direction, pushable if pushable.visual and pushable.visual._has_animation_this_step else pushed_by)
        # Blocking piece wasn't pushable, nothing moves
        return false
    
    pushable.grid_position += direction

    var roll := pushable.matches(group_rolls)

    # Piece should roll
    if roll:
        pushable.rotate(Vector3(direction).cross(Vector3.UP), -TAU/4)
    
    # If we know which piece pushed this, animate after its latest animation, or else this piece's latest animation
    var animate_after := pushed_by if pushed_by else pushable
    # Animate movement
    animator.queue_for(pushable.visual.create_animation(pushable.visual.default_animation), animate_after)

    # Nothing below pushable after movement
    var standable_pieces := board.get_pieces_touching(pushable_pieces, group_standable, Board3D.DIRECTIONS_DOWN, 1)
    if standable_pieces.is_empty():
        pushable.grid_position += Vector3i.DOWN
        animator.queue_for(pushable.visual.create_animation(pushable.visual.default_animation), pushable)
    # Keep moving if we rolled and there's something below where we moved
    elif roll:
        _push(pushable, direction)
    
    return true

func _swap() -> void:
    var sand_below := board.get_piece_at(player.grid_position + Vector3i.DOWN, group_sand)

    # No sand below player
    if not sand_below:
        _swap_fail()
        return

    var connected_sand := board.get_pieces_touching([sand_below], group_sand)
    var shells_on_connected_sand := board.get_pieces_touching(connected_sand, group_shell, Board3D.DIRECTIONS_UP, 1)

    # No shell to swap to
    if shells_on_connected_sand.is_empty():
        _swap_fail()
        return

    var current_shell := player.get_first_child_piece_matching(group_shell)
    # Leave current shell behind
    if current_shell:
        current_shell.parent_piece = null
        var current_shell_visual := current_shell.visual as ShellVisual
        animator.play(current_shell_visual.create_animation(current_shell_visual.exited_animation))

    var new_shell := shells_on_connected_sand[0]

    # Move player to existing shell position
    player.global_transform = new_shell.global_transform

    # Grab new shell into player
    new_shell.parent_piece = player
    var new_shell_visual := new_shell.visual as ShellVisual
    animator.play(new_shell_visual.create_animation(new_shell_visual.entered_animation))

    board.commit_changes()

    animator.finish_for(player)

func _swap_fail() -> void:
    var player_shell := player.get_first_child_piece_matching(group_shell)
    # Animate trying to leave shell and re-entering
    if player_shell:
        var player_shell_visual := player_shell.visual as ShellVisual
        animator.play(player_shell_visual.create_animation(player_shell_visual.fail_to_exit_animation))
