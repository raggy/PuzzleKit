class_name PieceState3D

var piece: Piece3D
var active: bool
var parent: Piece3D
var transform: Transform3D

func apply() -> void:
    piece.teleport(active, parent, transform)
