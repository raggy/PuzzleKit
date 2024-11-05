class_name PieceState3D

var piece: Piece3D
var transform: Transform3D

func apply():
    piece.teleport(transform)
