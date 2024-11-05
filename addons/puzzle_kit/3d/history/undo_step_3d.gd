class_name UndoStep3D

var changes: Array[PieceChange3D] = []

func undo():
    for change in changes:
        change.undo()
