extends PieceAnimation3D

@export var animation_name: StringName

var animation_player: AnimationPlayer

func _setup() -> void:
    animation_player = visual.get_node("AnimationPlayer")

func _start() -> void:
    animation_player.play(animation_name)
    animation_player.animation_finished.connect(_on_animation_finished)

func _finish() -> void:
    animation_player.play(animation_name, -1, 1.0, true)
    done()

func _clean_up() -> void:
    if animation_player.animation_finished.is_connected(_on_animation_finished):
        animation_player.animation_finished.disconnect(_on_animation_finished)

func _on_animation_finished(finished_animation_name: String) -> void:
    if finished_animation_name == animation_name:
        done()
