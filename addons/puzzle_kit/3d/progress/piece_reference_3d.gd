class_name PieceReference3D
extends Resource

var piece: Piece3D
@export var original_active: bool
@export var original_transform: Transform3D
@export var original_descendant_path: String
@export var scene_file_path: String

static func from_piece(_piece: Piece3D, piece_to_reference: Dictionary[Piece3D, PieceReference3D]) -> PieceReference3D:
    # No piece
    if _piece == null:
        return null
    
    # Piece has no history
    if _piece.history == null:
        return null
    
    if piece_to_reference.has(_piece):
        return piece_to_reference[_piece]
    
    var ref_piece := _piece

    # Piece isn't from its own scene, will match against ancestor
    if _piece.scene_file_path.is_empty():
        if not _piece.history._original_ancestor:
            printerr("PieceReference3D.dereference_from(): Couldn't find owner piece")
            return null
        ref_piece = _piece.history._original_ancestor
    
    var ref := PieceReference3D.new()
    ref.piece = _piece
    ref.original_active = ref_piece.history._original_active
    ref.original_transform = ref_piece.history._original_transform
    ref.original_descendant_path = _piece.history._original_descendant_path
    ref.scene_file_path = ref_piece.scene_file_path
    piece_to_reference[_piece] = ref
    return ref

## Returns true if we found the piece (or we don't need to)
func dereference_from(pieces: Array[Piece3D]) -> bool:
    # Already have our piece referenced
    if piece:
        return true
    
    var piece_index := pieces.rfind_custom(_does_piece_match)
    # No pieces matched
    if piece_index == -1:
        print("PieceReference3D.dereference_from(): Couldn't deference piece with original_active: %s, original_transform: %s, original_descendant_path: %s, scene_file_path: %s" % [original_active, original_transform, original_descendant_path, scene_file_path])
        return false
    
    piece = pieces[piece_index]
    return true

func _does_piece_match(p: Piece3D) -> bool:
    if not p.history:
        return false
    # Looking for a piece at root of its scene
    if original_descendant_path.is_empty():
        return p.history._original_active == original_active and p.history._original_transform == original_transform and p.scene_file_path == scene_file_path
    # Looking for a descendant piece
    var ancestor := p.history._original_ancestor
    if not ancestor or not ancestor.history:
        return false
    return p.history._original_descendant_path == original_descendant_path and ancestor.history._original_active == original_active and ancestor.history._original_transform == original_transform and ancestor.scene_file_path == scene_file_path
