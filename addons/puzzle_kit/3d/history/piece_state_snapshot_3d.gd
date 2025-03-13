class_name PieceStateSnapshot3D

## When undoing, always stop after this step
var stop_after: bool = false
## When undoing, always stop before this step
var stop_before: bool = false
var states: Array[PieceState3D] = []

func apply() -> void:
    for state in states:
        state.apply()

func has_a_piece_in_group(group: String) -> bool:
    for state in states:
        if state.piece.is_in_group(group):
            return true
    # None of the states' pieces were in group
    return false
