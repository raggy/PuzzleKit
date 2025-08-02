extends Node3D

const GROUP_PHYSICAL := "physical"
const GROUP_PUSHABLE := "pushable"
const GROUP_ROLLS := "rolls"
const GROUP_SAND := "sand"
const GROUP_SHELL := "shell"
const GROUP_STANDABLE := "standable"

const MAX_PUSH_PIECES := 8

@export var shell: PackedScene

@onready var board := $Board3D as Board3D
@onready var animator := $Board3D/PieceAnimator3D as PieceAnimator3D
@onready var directions := $DirectionalInput as DirectionalInput
@onready var history := $Board3D/History3D as History3D
@onready var player := $Board3D/Player as Piece3D

func _ready() -> void:
    directions.input = _move
    history.undo_step_created.connect(func(step: PieceStateSnapshot3D) -> void: if step.has_a_piece_in_group(GROUP_PUSHABLE): step.stop_after = true; step.stop_before = true)

    # Create initial checkpoint
    history.checkpoint()

func _process(_delta: float) -> void:
    if Input.is_action_just_pressed("swap"):
        _swap()

func _move(direction_2d: Vector2i) -> bool:
    var direction := Vector3i(direction_2d.x, 0, direction_2d.y)
    var pushed := false

    # Nothing to walk onto
    if board.is_empty(player.grid_position + direction + Vector3i.DOWN, GROUP_STANDABLE):
        return false
    
    # Push
    if not board.is_empty(player.grid_position + direction, GROUP_PUSHABLE):
        # If there's multiple pushable pieces in a row, get the one furthest from us
        var pushable := _get_end_pushable(player.grid_position, direction)
        # There's something blocking it from being pushed so we won't move
        if not board.is_empty(pushable.grid_position + direction):
            return false

        pushed = true
        pushable.grid_position += direction

        # Piece should roll
        if pushable.is_in_group(GROUP_ROLLS):
            pushable.rotate(Vector3(direction).cross(Vector3.UP), -TAU/4)

        # Nothing below pushable after movement
        if board.is_empty(pushable.grid_position + Vector3i.DOWN):
            pushable.grid_position.y = 0
    
    var blocked := not board.is_empty(player.grid_position + direction, GROUP_PHYSICAL)

    # We're blocked from moving but didn't push anything
    if blocked and not pushed:
        return false
    
    # Face movement direction
    player.basis = Basis.looking_at(direction)
    # Move in direction
    if not blocked:
        player.grid_position = player.grid_position + direction

    animator.stop_for(player)

    board.commit_changes()

    if player.visual.animation:
        player.visual.animation.finished.connect(directions.repeat)

    return true

func _swap() -> void:
    # No sand below player
    if board.is_empty(player.grid_position + Vector3i.DOWN, GROUP_SAND):
        return

    var sand_below := board.get_piece_at(player.grid_position + Vector3i.DOWN, GROUP_SAND)
    var connected_sand := _get_touching(sand_below, GROUP_SAND)
    var shells_on_connected_sand := _get_pieces_on_top_of(connected_sand, GROUP_SHELL)

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

    # Move player to existing shell position
    player.global_transform = shell_to_swap_to.global_transform

    board.commit_changes()

func _get_end_pushable(start_position: Vector3i, direction: Vector3i) -> Piece3D:
    var search_position := start_position + direction
    var end_piece: Piece3D

    for i in range(MAX_PUSH_PIECES):
        # No pushable here, stop searching
        if board.is_empty(search_position, GROUP_PUSHABLE):
            break
        # Update end_piece and set next search position
        end_piece = board.get_piece_at(search_position, GROUP_PUSHABLE)
        search_position += direction
    
    return end_piece

func _get_touching(piece: Piece3D, group: String = "") -> Array[Piece3D]:
    const DIRECTIONS_ADJACENT: Array[Vector3i] = [Vector3i.LEFT, Vector3i.RIGHT, Vector3i.UP, Vector3i.DOWN, Vector3i.FORWARD, Vector3i.BACK]
    var pieces_touching: Array[Piece3D] = [piece]
    var search_index := 0

    while (search_index < pieces_touching.size()):
        var origin_piece := pieces_touching[search_index]

        for direction in DIRECTIONS_ADJACENT:
            var touching_pieces := board.get_pieces_at(origin_piece.grid_position + direction, group)
            # Add touching pieces to check (if not already in the list)
            for touching_piece in touching_pieces:
                if pieces_touching.has(touching_piece):
                    continue
                pieces_touching.append(touching_piece)
        
        search_index += 1
    
    return pieces_touching

func _get_pieces_on_top_of(pieces: Array[Piece3D], group: String = "") -> Array[Piece3D]:
    var pieces_on_top: Array[Piece3D] = []

    for piece_below in pieces:
        # Add pieces on top (if not already in the list)
        for piece_on_top in board.get_pieces_at(piece_below.grid_position + Vector3i.UP, group):
            if pieces_on_top.has(piece_on_top):
                continue
            pieces_on_top.append(piece_on_top)

    return pieces_on_top
