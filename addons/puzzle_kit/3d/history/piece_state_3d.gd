class_name PieceState3D

var piece: Piece3D
var active: bool
var parent_piece: Piece3D
var transform: Transform3D

func apply() -> void:
    piece._teleport(active, parent_piece, transform)
