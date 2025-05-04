class_name Progress3D
extends Node

signal loaded
signal saved

## Which group should we keep track of? (Or all if left blank)
@export var group_filter: String = ""
## Override the save file path, otherwise bases the save file on the owner scene's name
@export var file_path_override: String = ""
## Should we load automatically on start-up?
@export var auto_load: bool
## Should we save automatically?
@export var auto_save: bool
## Maximum auto-save frequency
@export var auto_save_frequency: float = 0.0

var _board: Board3D: set = _set_board
var _auto_save_timer: SceneTreeTimer

func _enter_tree() -> void:
    _board = get_parent() as Board3D

func _exit_tree() -> void:
    _board = null

func _ready() -> void:
    if auto_load:
        call_deferred("load")

func _notification(what: int) -> void:
    match what:
        NOTIFICATION_APPLICATION_FOCUS_OUT: _auto_save_now()
        NOTIFICATION_APPLICATION_PAUSED: _auto_save_now()
        NOTIFICATION_WM_CLOSE_REQUEST: _auto_save_now()
        NOTIFICATION_PREDELETE: _stop_auto_save()

func save() -> bool:
    var file_path := get_file_path()
    # Invalid file path
    if file_path.is_empty():
        return false

    var save_dir := file_path.get_base_dir()
    # Create the save path
    if not DirAccess.dir_exists_absolute(save_dir):
        DirAccess.make_dir_recursive_absolute(save_dir)

    var save_state := BoardSaveState3D.from_board(_board, group_filter)
    ResourceSaver.save(save_state, file_path)

    return false

func load() -> bool:
    var file_path := get_file_path()
    # Invalid file path
    if file_path.is_empty():
        return false

    # Nothing to load
    if not ResourceLoader.exists(file_path):
        return false

    var save_state := ResourceLoader.load(file_path) as BoardSaveState3D

    # Not a valid save state
    if not save_state:
        return false
    
    return save_state.apply_to_board(_board, group_filter)
    
func get_file_path() -> String:
    if not file_path_override.is_empty():
        return file_path_override
    
    if owner:
        return "user://progress/%s.tres" % owner.scene_file_path.get_file().get_basename()
    
    printerr("Progress3D.get_file_path(): No valid path")
    return ""

func _set_board(value: Board3D) -> void:
    if _board:
        _board.changes_committing.disconnect(_queue_auto_save)
    _board = value
    if value:
        value.changes_committing.connect(_queue_auto_save)

func _queue_auto_save() -> void:
    if not auto_save:
        return
    
    if _auto_save_timer:
        return
    
    _auto_save_timer = get_tree().create_timer(auto_save_frequency)
    _auto_save_timer.timeout.connect(_auto_save_now)

func _auto_save_now() -> void:
    if not auto_save:
        return
    
    _stop_auto_save()

    save()

func _stop_auto_save() -> void:
    if not _auto_save_timer:
        return

    _auto_save_timer.timeout.disconnect(_auto_save_now)
    _auto_save_timer = null
