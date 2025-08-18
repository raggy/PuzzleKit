class_name PieceSaveState3D
extends Resource

@export var piece_ref: PieceReference3D

@export var active: bool
@export var parent_piece_ref: PieceReference3D
@export var transform: Transform3D

@export var in_checkpoint: bool
@export var checkpoint_active: bool
@export var checkpoint_parent_piece_ref: PieceReference3D
@export var checkpoint_transform: Transform3D

static func from_piece(piece: Piece3D, piece_to_reference: Dictionary[Piece3D, PieceReference3D]) -> PieceSaveState3D:
    var piece_save_state := PieceSaveState3D.new()

    piece_save_state.piece_ref = PieceReference3D.from_piece(piece, piece_to_reference)
    
    # Can't reference piece
    if not piece_save_state.piece_ref:
        printerr("Can't create a PieceReference3D for: %s" % piece.name)
        return null
    
    piece_save_state.active = piece.active
    piece_save_state.parent_piece_ref = PieceReference3D.from_piece(piece.parent_piece, piece_to_reference)
    piece_save_state.transform = piece.global_transform
    
    if piece.history:
        piece_save_state.in_checkpoint = piece.history._in_checkpoint
        piece_save_state.checkpoint_active = piece.history._checkpoint_active
        piece_save_state.checkpoint_parent_piece_ref = PieceReference3D.from_piece(piece.history._checkpoint_parent_piece, piece_to_reference)
        piece_save_state.checkpoint_transform = piece.history._checkpoint_transform

    return piece_save_state

## Apply state to referenced piece
func apply() -> void:
    if not piece_ref.piece:
        printerr("PieceSaveState3D.apply() failed: piece_ref.piece is null")
        return
    
    piece_ref.piece._teleport(active, parent_piece_ref.piece if parent_piece_ref else null, transform)

    if piece_ref.piece.history:
        piece_ref.piece.history._in_checkpoint = in_checkpoint
        piece_ref.piece.history._checkpoint_active = checkpoint_active
        piece_ref.piece.history._checkpoint_parent_piece = checkpoint_parent_piece_ref.piece if checkpoint_parent_piece_ref else null
        piece_ref.piece.history._checkpoint_transform = checkpoint_transform
