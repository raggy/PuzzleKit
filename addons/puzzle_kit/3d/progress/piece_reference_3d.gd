class_name PieceReference3D
extends Resource

var piece: Piece3D
@export var original_active: bool
@export var original_transform: Transform3D
@export var original_path_from_owner: NodePath
@export var scene_file_path: String

static func from_piece(_piece: Piece3D) -> PieceReference3D:
    # No piece
    if _piece == null:
        return null
    
    var ref_piece := _piece

    # Piece isn't from its own scene, get owner's details
    if _piece.scene_file_path.is_empty():
        if not _piece._owner_piece:
            printerr("PieceReference3D.dereference_from(): Couldn't find owner piece")
            return null
        ref_piece = _piece._owner_piece
    
    var ref := PieceReference3D.new()
    ref.piece = _piece
    ref.original_active = ref_piece._original_active
    ref.original_transform = ref_piece._original_transform
    ref.original_path_from_owner = _piece._original_path_from_owner_piece
    ref.scene_file_path = ref_piece.scene_file_path
    return ref

## Returns true if we found the piece (or we don't need to)
func dereference_from(pieces: Array[Piece3D]) -> bool:
    # Already have our piece referenced
    if piece:
        return true
    
    var piece_index := pieces.find_custom(_does_piece_match)
    # No pieces matched
    if piece_index == -1:
        print("PieceReference3D.dereference_from(): Couldn't deference piece with original_active: %s, original_transform: %s, scene_file_path: %s" % [original_active, original_transform, scene_file_path])
        return false
    
    piece = pieces[piece_index]
    return true

func _does_piece_match(p: Piece3D) -> bool:
    if original_path_from_owner == NodePath():
        return p._original_active == original_active and p._original_transform == original_transform and p.scene_file_path == scene_file_path
    return p._owner_piece and p._original_path_from_owner_piece == original_path_from_owner and p._owner_piece._original_active == original_active and p._owner_piece._original_transform == original_transform and p._owner_piece.scene_file_path == scene_file_path
