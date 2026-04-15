class_name BoxSelectionPreview
extends Control

var rect: Rect2: set = set_rect

func clear() -> void:
    rect = Rect2()

func set_rect(value: Rect2) -> void:
    if rect == value:
        return

    rect = value
    queue_redraw()

func _draw() -> void:
    if not rect.has_area():
        return
    var editor_theme := EditorInterface.get_editor_theme()
    draw_rect(rect, editor_theme.get_color("box_selection_fill_color", "Editor"))
    draw_rect(rect, editor_theme.get_color("box_selection_stroke_color", "Editor"), false, roundf(editor_theme.get_constant("scale", "Editor")))
