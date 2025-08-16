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
        if not piece_save_state:
            printerr("Couldn't create PieceSaveState3D for: %s" % piece.name)
            continue
        # TODO Pieces that were created in the same scene as a parent piece should go in the changed pieces list
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

    # Recreate non-original pieces
    var new_pieces: Array[Piece3D] = []
    if not _recreate_pieces(board, new_pieces):
        print("BoardSaveState3D.apply_to_board(): Refusing to load, could not recreate all pieces")
        _free_pieces(new_pieces)
        return false
    
    # Dereference parents
    for state in changed_pieces:
        if state.parent:
            if not state.parent.dereference_from(board._pieces):
                printerr("BoardSaveState3D.apply_to_board() failed: couldn't dereference state.parent")
                _free_pieces(new_pieces)
                return false
        if state.checkpoint_parent:
            if not state.checkpoint_parent.dereference_from(board._pieces):
                printerr("BoardSaveState3D.apply_to_board() failed: couldn't dereference state.checkpoint_parent")
                _free_pieces(new_pieces)
                return false

    # Set piece top-level to avoid transform being changed by parent
    for piece in board._pieces:
        if not piece.history:
            continue
        piece._piece_state_cached_top_level = piece.top_level
        piece.top_level = true
    
    # Apply state to original pieces
    for piece_save_state in changed_pieces:
        piece_save_state.apply()

    # Restore top-level to previous value
    for piece in board._pieces:
        if not piece.history:
            continue
        piece.top_level = piece._piece_state_cached_top_level
    
    board.commit_changes()

    return true

func _recreate_pieces(board: Board3D, new_pieces: Array[Piece3D]) -> bool:
    var state_to_piece: Dictionary[PieceSaveState3D, Piece3D] = {}

    # Create pieces
    for state in created_pieces:
        if not state.piece_reference:
            printerr("BoardSaveState3D._recreate_pieces() failed: state.piece_reference is null")
            return false
        
        var packed_scene := ResourceLoader.load(state.piece_reference.scene_file_path) as PackedScene

        if not packed_scene:
            printerr("BoardSaveState3D._recreate_pieces() failed: couldn't load PackedScene at %s" % state.piece_reference.scene_file_path)
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
    
    # Dereference parents
    for state in created_pieces:
        if state.parent:
            if not state.parent.dereference_from(new_pieces) or not state.parent.dereference_from(board._pieces):
                printerr("BoardSaveState3D._recreate_pieces() failed: couldn't dereference state.parent")
                return false
        if state.checkpoint_parent:
            if not state.checkpoint_parent.dereference_from(new_pieces) or not state.checkpoint_parent.dereference_from(board._pieces):
                printerr("BoardSaveState3D._recreate_pieces() failed: couldn't dereference state.checkpoint_parent")
                return false

    # Set state and add pieces to board
    for state in created_pieces:
        var piece := state_to_piece[state]

        piece.active = false
        piece.parent = state.parent.piece if state.parent else null
        piece.transform = state.transform

        if piece.history:
            piece.history._in_checkpoint = state.in_checkpoint
            piece.history._checkpoint_active = state.checkpoint_active
            piece.history._checkpoint_parent = state.checkpoint_parent.piece if state.checkpoint_parent else null
            piece.history._checkpoint_transform = state.checkpoint_transform

        board.add_child(piece)
        piece.active = state.active

    return true

func _dereference_pieces_from(pieces: Array[Piece3D]) -> bool:
    var success: bool = true

    for piece_save_state in changed_pieces:
        success = success and piece_save_state.piece_reference and piece_save_state.piece_reference.dereference_from(pieces)
    
    return success

func _free_pieces(pieces: Array[Piece3D]) -> void:
    for piece in pieces:
        piece.queue_free()
