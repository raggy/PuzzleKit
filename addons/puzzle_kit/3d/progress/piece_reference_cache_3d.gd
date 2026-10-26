class_name PieceReferenceCache3D
extends RefCounted

var pieces: Array[Piece3D]
var node_path_to_piece: Dictionary[String, Piece3D]

static func generate_from(p: Array[Piece3D], ancestor: Node) -> PieceReferenceCache3D:
    var cache := PieceReferenceCache3D.new()
    cache.pieces = p
    cache.node_path_to_piece = {}

    var ancestor_path := str(ancestor.get_path())

    for piece in p:
        if not piece._original_node_path.begins_with(ancestor_path):
            # printerr("Piece (%s) original node path (%s) was not a descendant of ancestor path (%s)" % [piece, piece._original_node_path, ancestor_path])
            # print(piece._board)
            continue
        var relative_node_path := piece._original_node_path.substr(ancestor_path.length())
        if relative_node_path in cache.node_path_to_piece:
            printerr("Piece's relative node path was already in cache: %s" % relative_node_path)
            continue
        cache.node_path_to_piece[relative_node_path] = piece
    
    return cache
