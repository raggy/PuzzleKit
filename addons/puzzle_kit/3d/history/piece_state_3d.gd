class_name PieceState3D

var piece: Piece3D
var active: bool
var transform: Transform3D

func apply():
    piece.teleport(active, transform)
