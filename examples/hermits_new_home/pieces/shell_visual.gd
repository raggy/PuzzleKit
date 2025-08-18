class_name ShellVisual
extends PieceVisual3D

@export var animation_player: AnimationPlayer

@export var entered_animation: PackedScene
@export var exited_animation: PackedScene
@export var fail_to_exit_animation: PackedScene

func _snap_to_piece_state() -> void:
    super._snap_to_piece_state()

    animation_player.play("player_entering" if piece.parent_piece else "player_exiting", -1, 1.0, true)
    animation_player.advance(0)
