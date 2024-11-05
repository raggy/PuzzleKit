class_name PieceChange3D

var piece: Piece3D
var previous_transform: Transform3D
var new_transform: Transform3D

func undo():
    piece.teleport(previous_transform)
