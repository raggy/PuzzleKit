class_name BoardSaveState3D
extends Resource

@export var changed_pieces: Array[PieceSaveState3D] = []
@export var created_pieces: Array[PieceSaveState3D] = []

static func from_board(board: Board3D, group_filter: String = "") -> BoardSaveState3D:
    var save_state := BoardSaveState3D.new()

    for piece in board._pieces:
        # Piece doesn't change
        if not piece.history:
            continue
        # Piece doesn't match group filter
        if group_filter != "" and not piece.is_in_group(group_filter):
            continue
        # Don't save non-original, inactive pieces
        if not piece.active and not piece._original_active:
            continue
        var piece_save_state := PieceSaveState3D.from_piece(piece)
        # Invalid PieceSaveState
        if not piece_save_state.piece_reference:
            printerr("Couldn't create PieceSaveState3D for: %s" % piece.name)
            continue
        # Save changes for original piece
        if piece._original_active:
            save_state.changed_pieces.append(piece_save_state)
        # Save created piece
        else:
            save_state.created_pieces.append(piece_save_state)

    return save_state

func apply_to_board(board: Board3D, group_filter: String = "") -> bool:
    if not _dereference_pieces_from(board._pieces):
        print("BoardSaveState3D.apply_to_board(): Refusing to load, cannot match all pieces in board")
        return false

    # Deactivate non-original pieces
    for piece in board._pieces:
        # Piece doesn't change
        if not piece.history:
            continue
        # Piece doesn't match group filter
        if group_filter != "" and not piece.is_in_group(group_filter):
            continue
        # Piece is original
        if piece._original_active:
            continue
        piece.active = false
    
    # Change original pieces states
    for piece_save_state in changed_pieces:
        piece_save_state.apply()
    
    # Recreate non-original pieces
    for piece_save_state in created_pieces:
        var piece := piece_save_state.recreate()
        var active := piece.active

        piece.active = false
        board.add_child(piece)
        piece.active = active
    
    board.commit_changes()

    return true

func _dereference_pieces_from(pieces: Array[Piece3D]) -> bool:
    var success: bool = true

    for piece_save_state in changed_pieces:
        success = success and piece_save_state.piece_reference and piece_save_state.piece_reference.dereference_from(pieces)
    
    return success
