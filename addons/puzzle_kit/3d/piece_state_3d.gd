class_name PieceState3D

var piece: Piece3D
var active: bool
var parent_piece: Piece3D
var transform: Transform3D
var extra_properties: Dictionary[NodePath, Variant]

func apply() -> void:
    piece._teleport(active, parent_piece, transform, extra_properties)
