extends Node3D

const GROUP_PHYSICAL := "physical"
const GROUP_PUSHABLE := "pushable"
const GROUP_ROLLS := "rolls"
const GROUP_STANDABLE := "standable"

const MAX_PUSH_PIECES := 8

@onready var board := $Board3D as Board3D
@onready var animator := $PieceAnimator3D as PieceAnimator3D
@onready var directions := $DirectionalInput as DirectionalInput
@onready var player := $Board3D/Player as Piece3D

func _ready() -> void:
    directions.input = _move

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

func _get_end_pushable(start_position: Vector3i, direction: Vector3i) -> Piece3D:
    var search_position := start_position + direction
    var end_piece: Piece3D

    for i in range(MAX_PUSH_PIECES):
        # No pushable here, stop searching
        if board.is_empty(search_position, GROUP_PUSHABLE):
            break
        # Update end_piece and set next search position
        var tiles := board.get_tiles_at(search_position, GROUP_PUSHABLE)
        end_piece = tiles[0].piece
        search_position += direction
    
    return end_piece
