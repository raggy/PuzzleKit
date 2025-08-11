extends Node3D

const MAX_PUSH_PIECES := 8

@export var shell: PackedScene

@onready var board := $Board3D as Board3D
@onready var animator := $Board3D/PieceAnimator3D as PieceAnimator3D
@onready var directions := $DirectionalInput as DirectionalInput
@onready var history := $Board3D/History3D as History3D
@onready var player := $Board3D/Player as Piece3D

@onready var group_checkpoint := board.group_filter_with("checkpoint")
@onready var group_blocking := board.group_filter_any(["coconut", "rock", "shell"])
@onready var group_pushable := board.group_filter_any(["coconut", "shell"])
@onready var group_rolls := board.group_filter_any(["coconut"])
@onready var group_sand := board.group_filter_with("sand")
@onready var group_shell := board.group_filter_with("shell")
@onready var group_standable := board.group_filter_any(["grass", "sand", "coconut"])

func _ready() -> void:
    directions.input = _move
    history.undo_step_created.connect(func(step: PieceStateSnapshot3D) -> void: if step.has_a_piece_that_matches(group_pushable): step.stop_after = true; step.stop_before = true)

    # Create initial checkpoint
    history.checkpoint()

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

    board.commit_changes()

    if player.visual.animation:
        player.visual.animation.finished.connect(directions.repeat)

    return true

func _push(pushable: Piece3D, direction: Vector3i, pushed_by: Piece3D = null) -> bool:
    var blocking_piece := board.get_piece_at(pushable.grid_position + direction, group_blocking)
    # There's something blocking it from being pushed so we won't move
    if blocking_piece:
        # If the blocking piece is pushable, push it instead
        if group_pushable.matches(blocking_piece):
            return _push(blocking_piece, direction, pushable if pushable.visual._has_animation_this_step else pushed_by)
        # Blocking piece wasn't pushable, nothing moves
        return false

    pushable.grid_position += direction

    var roll := group_rolls.matches(pushable)

    # Piece should roll
    if roll:
        pushable.rotate(Vector3(direction).cross(Vector3.UP), -TAU/4)
    
    # If we know which piece pushed this, animate after its latest animation, or else this piece's latest animation
    var animate_after := pushed_by if pushed_by else pushable
    # Animate movement
    animator.queue_for(pushable.visual.create_animation(pushable.visual.default_animation), animate_after)

    # Nothing below pushable after movement
    if board.is_empty(pushable.grid_position + Vector3i.DOWN, group_standable):
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
        return

    var connected_sand := board.get_pieces_touching([sand_below], group_sand)
    var shells_on_connected_sand := board.get_pieces_touching(connected_sand, group_shell, Board3D.DIRECTIONS_UP, 1)

    # No shell to swap to
    if shells_on_connected_sand.is_empty():
        return

    # Deactivate existing shell
    var shell_to_swap_to := shells_on_connected_sand[0]
    shell_to_swap_to.active = false

    # Create new shell at player's current position
    var shell_left_behind := shell.instantiate() as Piece3D
    shell_left_behind.global_transform = player.global_transform
    board.add_child(shell_left_behind)
    # Ensure the shell will be removed on undo
    shell_left_behind._previous_active = false
    shell_left_behind._original_active = false

    # Move player to existing shell position
    player.global_transform = shell_to_swap_to.global_transform

    board.commit_changes()
