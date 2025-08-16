class_name PieceSaveState3D
extends Resource

@export var piece_reference: PieceReference3D

@export var active: bool
@export var parent: PieceReference3D
@export var transform: Transform3D

@export var in_checkpoint: bool
@export var checkpoint_active: bool
@export var checkpoint_parent: PieceReference3D
@export var checkpoint_transform: Transform3D

# TODO Store changes to descendant pieces here to make recreation easier?

# TODO Move from_piece into board_save_state_3d and reuse PieceReference3Ds for same pieces

static func from_piece(piece: Piece3D) -> PieceSaveState3D:
    var piece_save_state := PieceSaveState3D.new()

    piece_save_state.piece_reference = PieceReference3D.from_piece(piece)
    
    # Can't reference piece
    if not piece_save_state.piece_reference:
        printerr("Can't create a PieceReference3D for: %s" % piece.name)
        return null
    
    piece_save_state.active = piece.active
    piece_save_state.parent = PieceReference3D.from_piece(piece.parent)
    piece_save_state.transform = piece.global_transform
    
    if piece.history:
        piece_save_state.in_checkpoint = piece.history._in_checkpoint
        piece_save_state.checkpoint_active = piece.history._checkpoint_active
        piece_save_state.checkpoint_parent = PieceReference3D.from_piece(piece.history._checkpoint_parent)
        piece_save_state.checkpoint_transform = piece.history._checkpoint_transform

    return piece_save_state

## Apply state to referenced piece
func apply() -> void:
    if not piece_reference.piece:
        printerr("PieceSaveState3D.apply() failed: piece_reference.piece is null")
        return
    
    piece_reference.piece.teleport(active, parent.piece if parent else null, transform)

    if piece_reference.piece.history:
        piece_reference.piece.history._in_checkpoint = in_checkpoint
        piece_reference.piece.history._checkpoint_active = checkpoint_active
        piece_reference.piece.history._checkpoint_parent = checkpoint_parent.piece if checkpoint_parent else null
        piece_reference.piece.history._checkpoint_transform = checkpoint_transform
