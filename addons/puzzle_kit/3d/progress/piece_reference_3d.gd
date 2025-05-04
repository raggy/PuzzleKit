class_name PieceReference3D
extends Resource

var piece: Piece3D
@export var original_active: bool
@export var original_transform: Transform3D
@export var scene_file_path: String

static func from_piece(_piece: Piece3D) -> PieceReference3D:
    # No piece
    if _piece == null or _piece.scene_file_path.is_empty():
        return null

    var ref := PieceReference3D.new()
    ref.piece = _piece
    ref.original_active = _piece._original_active
    ref.original_transform = _piece._original_transform
    ref.scene_file_path = _piece.scene_file_path
    return ref

## Returns true if we found the piece (or we don't need to)
func dereference_from(pieces: Array[Piece3D]) -> bool:
    # Already have our piece referenced
    if piece:
        return true
    
    var piece_index := pieces.find_custom(_does_piece_match)
    # No pieces matched
    if piece_index == -1:
        return false
    
    piece = pieces[piece_index]
    return true

func _does_piece_match(p: Piece3D) -> bool:
    return p._original_active == original_active and p._original_transform == original_transform and p.scene_file_path == scene_file_path
