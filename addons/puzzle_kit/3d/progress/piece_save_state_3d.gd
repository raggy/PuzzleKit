class_name PieceSaveState3D
extends Resource

@export var piece_ref: PieceReference3D

@export var active: bool
@export var parent_piece_ref: PieceReference3D
@export var transform: Transform3D
@export var extra_properties: Dictionary[NodePath, Variant]

var dereferenced_extra_properties: Dictionary[NodePath, Variant]

@export var checkpoint_active: bool
@export var checkpoint_parent_piece_ref: PieceReference3D
@export var checkpoint_transform: Transform3D
@export var checkpoint_properties: Dictionary[NodePath, Variant]

var dereferenced_checkpoint_properties: Dictionary[NodePath, Variant]

static func from_piece(piece: Piece3D, board: Board3D, piece_to_reference: Dictionary[Piece3D, PieceReference3D]) -> PieceSaveState3D:
    var piece_save_state := PieceSaveState3D.new()

    piece_save_state.piece_ref = PieceReference3D.from_piece(piece, board, piece_to_reference)
    
    # Can't reference piece
    if not piece_save_state.piece_ref:
        printerr("Can't create a PieceReference3D for: %s" % piece.name)
        return null
    
    piece_save_state.active = piece.active
    piece_save_state.parent_piece_ref = PieceReference3D.from_piece(piece.parent_piece, board, piece_to_reference)
    piece_save_state.transform = piece.global_transform
    piece_save_state.extra_properties = _pieces_to_references_in_properties_dictionary(piece.get_property_values(), board, piece_to_reference)
    
    if piece.history:
        piece_save_state.checkpoint_active = piece.history._checkpoint_active
        piece_save_state.checkpoint_parent_piece_ref = PieceReference3D.from_piece(piece.history._checkpoint_parent_piece, board, piece_to_reference)
        piece_save_state.checkpoint_transform = piece.history._checkpoint_transform
        piece_save_state.checkpoint_properties = _pieces_to_references_in_properties_dictionary(piece.history._checkpoint_properties.duplicate(), board, piece_to_reference)

    return piece_save_state

static func _pieces_to_references_in_properties_dictionary(property_values: Dictionary[NodePath, Variant], board: Board3D, piece_to_reference: Dictionary[Piece3D, PieceReference3D]) -> Dictionary[NodePath, Variant]:
    for property_path: NodePath in property_values.keys():
        var value: Variant = property_values[property_path]
        if value is Piece3D:
            var piece_value: Piece3D = value
            # Store PieceReference instead so we can deference it later
            property_values[property_path] = PieceReference3D.from_piece(piece_value, board, piece_to_reference)
    return property_values

## Apply state to referenced piece
func apply() -> void:
    if not piece_ref.piece:
        printerr("PieceSaveState3D.apply() failed: piece_ref.piece is null")
        return
    
    piece_ref.piece._teleport(active, parent_piece_ref.piece if parent_piece_ref else null, transform, dereferenced_extra_properties)

    if piece_ref.piece.history:
        piece_ref.piece.history._checkpoint_active = checkpoint_active
        piece_ref.piece.history._checkpoint_parent_piece = checkpoint_parent_piece_ref.piece if checkpoint_parent_piece_ref else null
        piece_ref.piece.history._checkpoint_transform = checkpoint_transform
        piece_ref.piece.history._checkpoint_properties = dereferenced_checkpoint_properties

func dereference_properties(pieces_cache: PieceReferenceCache3D) -> bool:
    dereferenced_extra_properties = {}
    dereferenced_checkpoint_properties = {}
    return _dereference_properties_dictionary(extra_properties, dereferenced_extra_properties, pieces_cache) and _dereference_properties_dictionary(checkpoint_properties, dereferenced_checkpoint_properties, pieces_cache)

static func _dereference_properties_dictionary(properties: Dictionary[NodePath, Variant], dereferenced_properties: Dictionary[NodePath, Variant], pieces_cache: PieceReferenceCache3D) -> bool:
    var success := true
    for property_path: NodePath in properties.keys():
        var value: Variant = properties[property_path]
        if value is PieceReference3D:
            var piece_ref_value: PieceReference3D = value
            success = success and piece_ref_value.dereference_from(pieces_cache)
            # Store Piece3D instead
            dereferenced_properties[property_path] = piece_ref_value.piece
            continue
        dereferenced_properties[property_path] = value
    return success
