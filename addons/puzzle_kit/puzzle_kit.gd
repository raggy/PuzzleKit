@tool
extends EditorPlugin

const subplugins: Array[String] = [
    "puzzle_kit/3d/editor",
]

func _enable_plugin() -> void:
    for plugin_path in subplugins:
        EditorInterface.set_plugin_enabled(plugin_path, true)

func _disable_plugin() -> void:
    for plugin_path in subplugins:
        EditorInterface.set_plugin_enabled(plugin_path, false)
