class_name PieceStateSnapshot3D

## When undoing, always stop before and after an important step
var important: bool = false
var states: Array[PieceState3D] = []

func apply():
    for state in states:
        state.apply()

func has_a_piece_in_group(group: String) -> bool:
    for state in states:
        if state.piece.is_in_group(group):
            return true
    # None of the states' pieces were in group
    return false