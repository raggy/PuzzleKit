class_name PieceReference3D
extends Resource

var piece: Piece3D
@export var original_active: bool
@export var original_transform: Transform3D
@export var original_descendant_path: String
@export var original_relative_node_path: String
@export var relative_board_path: NodePath
@export var scene_file_path: String

static func from_piece(_piece: Piece3D, board: Board3D, piece_to_reference: Dictionary[Piece3D, PieceReference3D]) -> PieceReference3D:
    # No piece
    if _piece == null:
        return null
    
    if piece_to_reference.has(_piece):
        return piece_to_reference[_piece]
    
    var ref_piece := _piece

    # Piece isn't from its own scene, will match against ancestor
    if _piece.scene_file_path.is_empty():
        if not _piece._original_ancestor:
            printerr("PieceReference3D.dereference_from(): Couldn't find owner piece")
            return null
        ref_piece = _piece._original_ancestor
    
    var ref := PieceReference3D.new()
    ref.piece = _piece
    ref.original_active = ref_piece._original_active
    ref.original_transform = ref_piece._original_transform
    ref.original_descendant_path = _piece._original_descendant_path
    var board_path := str(board.get_path())
    if _piece._original_node_path.begins_with(board_path):
        ref.original_relative_node_path = _piece._original_node_path.substr(board_path.length())
    else:
        printerr("Piece original node path wasn't descendant of board: %s" % _piece._original_node_path)
    ref.relative_board_path = board.get_path_to(_piece._board)
    ref.scene_file_path = ref_piece.scene_file_path
    piece_to_reference[_piece] = ref
    return ref

## Returns true if we found the piece (or we don't need to)
func dereference_from(cache: PieceReferenceCache3D) -> bool:
    # Already have our piece referenced
    if piece:
        return true

    # Check node path cache first
    if original_relative_node_path in cache.node_path_to_piece:
        var piece_at_node_path := cache.node_path_to_piece[original_relative_node_path]
        if _does_piece_match(piece_at_node_path):
            # Piece at node path matched
            piece = piece_at_node_path
            return true
    
    var piece_index := cache.pieces.rfind_custom(_does_piece_match)
    # No pieces matched
    if piece_index == -1:
        print("PieceReference3D.dereference_from(): Couldn't deference piece with original_active: %s, original_transform: %s, original_descendant_path: %s, scene_file_path: %s" % [original_active, original_transform, original_descendant_path, scene_file_path])
        return false
    
    piece = cache.pieces[piece_index]
    return true

func _does_piece_match(p: Piece3D) -> bool:
    # Looking for a piece at root of its scene
    if original_descendant_path.is_empty():
        return p._original_active == original_active and p._original_transform == original_transform and p.scene_file_path == scene_file_path
    # Looking for a descendant piece
    var ancestor := p._original_ancestor
    if not ancestor:
        return false
    return p._original_descendant_path == original_descendant_path and ancestor._original_active == original_active and ancestor._original_transform == original_transform and ancestor.scene_file_path == scene_file_path
