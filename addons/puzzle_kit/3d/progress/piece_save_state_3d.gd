class_name PieceSaveState3D
extends Resource

@export var piece_reference: PieceReference3D

@export var active: bool
@export var transform: Transform3D

@export var in_checkpoint: bool
@export var checkpoint_active: bool
@export var checkpoint_transform: Transform3D

static func from_piece(piece: Piece3D) -> PieceSaveState3D:
    var piece_save_state := PieceSaveState3D.new()

    piece_save_state.piece_reference = PieceReference3D.from_piece(piece)
    
    # Can't reference piece
    if not piece_save_state.piece_reference:
        printerr("Can't create a PieceReference3D for: %s" % piece.name)
        return null

    piece_save_state.active = piece.active
    piece_save_state.transform = piece.global_transform
    
    if piece.history:
        piece_save_state.in_checkpoint = piece.history._in_checkpoint
        piece_save_state.checkpoint_active = piece.history._checkpoint_active
        piece_save_state.checkpoint_transform = piece.history._checkpoint_transform

    return piece_save_state

## Apply state to referenced piece
func apply() -> void:
    if not piece_reference.piece:
        printerr("PieceSaveState3D.apply() failed: piece_reference.piece is null")
        return
    
    piece_reference.piece.teleport(active, transform)

    if piece_reference.piece.history:
        piece_reference.piece.history._in_checkpoint = in_checkpoint
        piece_reference.piece.history._checkpoint_active = checkpoint_active
        piece_reference.piece.history._checkpoint_transform = checkpoint_transform

## Create and return a Piece3D from state
func recreate() -> Piece3D:
    if not piece_reference:
        printerr("PieceSaveState3D.recreate() failed: piece_reference is null")
        return null
    
    var packed_scene := ResourceLoader.load(piece_reference.scene_file_path) as PackedScene

    if not packed_scene:
        printerr("PieceSaveState3D.recreate() failed: couldn't load PackedScene")
        return null
    
    var piece := packed_scene.instantiate() as Piece3D

    if not piece:
        printerr("PieceSaveState3D.recreate() failed: PackedScene didn't create a Piece3D")
        return null
    
    piece.active = active
    piece.transform = transform

    if piece.history:
        piece.history._in_checkpoint = in_checkpoint
        piece.history._checkpoint_active = checkpoint_active
        piece.history._checkpoint_transform = checkpoint_transform
    
    return piece
