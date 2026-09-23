class_name BoardSaveState3D
extends Resource

@export var changed_pieces: Array[PieceSaveState3D] = []
@export var created_pieces: Array[PieceSaveState3D] = []

static func from_board(board: Board3D, group_filter: String = "") -> BoardSaveState3D:
    var save_state := BoardSaveState3D.new()
    var piece_to_reference: Dictionary[Piece3D, PieceReference3D] = {}

    for piece in board._pieces:
        # Piece doesn't change
        if not piece.history:
            continue
        # Piece doesn't match group filter
        if group_filter != "" and not piece.is_in_group(group_filter):
            continue
        # Don't save non-original, inactive pieces that also aren't active in the checkpoint
        if not piece.active and not piece._original_active and not piece.history._checkpoint_active:
            continue
        # Don't save state for a piece that hasn't changed
        if not piece.history.has_changes_to_save():
            continue
        var piece_save_state := PieceSaveState3D.from_piece(piece, board, piece_to_reference)
        # Invalid PieceSaveState
        if not piece_save_state:
            printerr("Couldn't create PieceSaveState3D for: %s" % piece.name)
            continue
        # Save changes for original piece
        if piece._original_active:
            save_state.changed_pieces.append(piece_save_state)
        # Save changes for descendent of created piece
        elif piece._original_ancestor:
            save_state.changed_pieces.append(piece_save_state)
        # Save created piece
        else:
            save_state.created_pieces.append(piece_save_state)

    return save_state

func apply_to_board(board: Board3D, group_filter: String = "") -> bool:
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

    var board_pieces_cache := PieceReferenceCache3D.generate_from(board._pieces, board)

    # Recreate non-original pieces
    var new_pieces: Array[Piece3D] = []
    if not _recreate_pieces(board, new_pieces, board_pieces_cache):
        print("BoardSaveState3D.apply_to_board(): Refusing to load, could not recreate all pieces")
        board.revert_changes()
        _free_pieces(new_pieces)
        return false

    # We need a Piece3D for each PieceReference3D in changed_pieces
    if not _dereference_states_from_pieces(changed_pieces, board_pieces_cache):
        print("BoardSaveState3D.apply_to_board(): Refusing to load, cannot match all changed pieces in board")
        board.revert_changes()
        _free_pieces(new_pieces)
        return false
    
    var pieces_to_reset: Array[Piece3D] = []

    # Set piece top-level to avoid transform being changed by parent piece
    for piece in board._pieces:
        if not piece.history:
            continue
        piece._piece_state_cached_top_level = piece.top_level
        piece.top_level = true
        if piece._original_active:
            pieces_to_reset.append(piece)
    
    # Apply state to original pieces
    for piece_save_state in changed_pieces:
        piece_save_state.apply()
        pieces_to_reset.erase(piece_save_state.piece_ref.piece)
    
    # Reset original pieces that had no saved changes
    for piece in pieces_to_reset:
        piece._teleport(piece._original_active, piece._original_parent_piece, piece._original_transform)

    # Restore top-level to previous value
    for piece in board._pieces:
        if not piece.history:
            continue
        piece.top_level = piece._piece_state_cached_top_level
    
    board.commit_changes()

    return true

func _recreate_pieces(board: Board3D, new_pieces: Array[Piece3D], board_pieces_cache: PieceReferenceCache3D) -> bool:
    var state_to_piece: Dictionary[PieceSaveState3D, Piece3D] = {}

    # Create pieces
    for state in created_pieces:
        if not state.piece_ref:
            printerr("BoardSaveState3D._recreate_pieces() failed: state.piece_reference is null")
            return false
        
        var packed_scene := ResourceLoader.load(state.piece_ref.scene_file_path) as PackedScene

        if not packed_scene:
            printerr("BoardSaveState3D._recreate_pieces() failed: couldn't load PackedScene at %s" % state.piece_ref.scene_file_path)
            return false
        
        var node := packed_scene.instantiate()
        var piece := node as Piece3D

        if not piece:
            printerr("BoardSaveState3D._recreate_pieces() failed: PackedScene didn't create a Piece3D")
            if node:
                node.queue_free()
            return false
        
        state_to_piece[state] = piece
        new_pieces.append(piece)
    
    var new_pieces_cache := PieceReferenceCache3D.generate_from(new_pieces, board)

    # Dereference parent pieces
    for state in created_pieces:
        if state.parent_piece_ref:
            if not state.parent_piece_ref.dereference_from(new_pieces_cache) or not state.parent_piece_ref.dereference_from(board_pieces_cache):
                printerr("BoardSaveState3D._recreate_pieces() failed: couldn't dereference state.parent_piece_ref")
                return false
        if state.checkpoint_parent_piece_ref:
            if not state.checkpoint_parent_piece_ref.dereference_from(new_pieces_cache) or not state.checkpoint_parent_piece_ref.dereference_from(board_pieces_cache):
                printerr("BoardSaveState3D._recreate_pieces() failed: couldn't dereference state.checkpoint_parent_piece_ref")
                return false

    # Set state and add pieces to board
    for state in created_pieces:
        var piece := state_to_piece[state]
        
        var piece_board := board.get_node(state.piece_ref.relative_board_path) as Board3D
        if not piece_board:
            printerr("Could not find board at %s, defaulting to root board" % state.piece_ref.relative_board_path)
            piece_board = board

        piece.active = state.active
        piece.parent_piece = state.parent_piece_ref.piece if state.parent_piece_ref else null
        piece.transform = piece_board.global_transform.affine_inverse() * state.transform

        if piece.history:
            piece.history._checkpoint_active = state.checkpoint_active
            piece.history._checkpoint_parent_piece = state.checkpoint_parent_piece_ref.piece if state.checkpoint_parent_piece_ref else null
            piece.history._checkpoint_transform = state.checkpoint_transform

        piece_board.add_child(piece, true)
        # Override _previous_active so we don't create unnecessary undo history
        piece._previous_active = state.active

    return true

func _dereference_states_from_pieces(states: Array[PieceSaveState3D], pieces_cache: PieceReferenceCache3D) -> bool:
    var success: bool = true

    for piece_save_state in states:
        success = success and piece_save_state.piece_ref and piece_save_state.piece_ref.dereference_from(pieces_cache)
        if piece_save_state.parent_piece_ref:
            success = success and piece_save_state.parent_piece_ref.dereference_from(pieces_cache)
        if piece_save_state.checkpoint_parent_piece_ref:
            success = success and piece_save_state.checkpoint_parent_piece_ref and piece_save_state.checkpoint_parent_piece_ref.dereference_from(pieces_cache)
    
    return success

func _free_pieces(pieces: Array[Piece3D]) -> void:
    for piece in pieces:
        piece.queue_free()
