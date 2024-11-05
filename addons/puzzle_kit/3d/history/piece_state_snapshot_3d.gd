class_name PieceStateSnapshot3D

var states: Array[PieceState3D] = []

func apply():
    for state in states:
        state.apply()
