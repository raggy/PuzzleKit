class_name PieceStateSnapshot3D

## When undoing, always stop after this step
var stop_after: bool = false
## When undoing, always stop before this step
var stop_before: bool = false
var states: Array[PieceState3D] = []

func apply(board: Board3D) -> void:
    # Set piece top-level to avoid transform being changed by parent
    for piece in board._pieces:
        if not piece.history:
            continue
        piece._piece_state_cached_top_level = piece.top_level
        piece.top_level = true

    for state in states:
        state.apply()

    # Restore top-level to previous value
    for piece in board._pieces:
        if not piece.history:
            continue
        piece.top_level = piece._piece_state_cached_top_level

func has_a_piece_in_group(group: String) -> bool:
    for state in states:
        if state.piece.is_in_group(group):
            return true
    # None of the states' pieces were in group
    return false

func has_a_piece_that_matches(group_filter: GroupFilter) -> bool:
    for state in states:
        if group_filter.matches_3d(state.piece):
            return true
    # None of the states' pieces matched group filter
    return false
