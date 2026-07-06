@tool
class_name PuzzleKitEditor3D
extends VBoxContainer

# Written heavily referencing the GridMap editor plugin
# With thanks to Godot contributors
# https://github.com/godotengine/godot/blob/master/modules/gridmap/editor/grid_map_editor_plugin.cpp

signal board_edit_requested(board: Board3D)

const SETTING_PIECE_DIRECTORY := "puzzle_kit/editor/piece_directory"
const SETTING_PAINT_OVERWRITES := "puzzle_kit/editor/paint_overwrites"
const SETTING_PICK_COPIES_ROTATION := "puzzle_kit/editor/pick_copies_rotation"
const SETTING_PICK_COPIES_OFFSET := "puzzle_kit/editor/pick_copies_offset"
const SETTING_PICK_COPIES_GROUPS := "puzzle_kit/editor/pick_copies_groups"

const GRID_CURSOR_SIZE := 50

const GIZMO_BASE_LAYER := 27
const GIZMO_EDIT_LAYER := 26
const GIZMO_GRID_LAYER := 25
const MISC_TOOL_LAYER := 24

const CUBE_CORNERS: Array[Vector3] = [
    Vector3(-0.5, -0.5, -0.5),
    Vector3( 0.5, -0.5, -0.5),
    Vector3(-0.5,  0.5, -0.5),
    Vector3( 0.5,  0.5, -0.5),
    Vector3(-0.5, -0.5,  0.5),
    Vector3( 0.5, -0.5,  0.5),
    Vector3(-0.5,  0.5,  0.5),
    Vector3( 0.5,  0.5,  0.5),
]

@export var transform_mode_button: Button
@export var paint_mode_button: Button
@export var attach_mode_button: Button
@export var erase_mode_button: Button
@export var pick_mode_button: Button
@export var select_mode_button: Button

@export var rotate_x_button: Button
@export var rotate_y_button: Button
@export var rotate_z_button: Button

@export var group_button: Button
@export var ungroup_button: Button

@export var viewport_shortcut_buttons: Array[BaseButton]

@export var draw_offset_spin_box: SpinBox

@export var piece_directory_input: TextEdit
@export var piece_directory_pick_button: Button
@export var piece_directory_pick_dialog: FileDialog

@export var path_to_board: Container

@export var palette: ItemList

@export var group_name_filter: LineEdit
@export var groups_clear_button: Button
@export var groups_container: Container
var group_checkboxes: Array[CheckBox] = []

@export var options_button: MenuButton

@export var container_board: Container
@export var info_no_board: Control

enum InputAction {
    INPUT_NONE,
    INPUT_PAINT,
    INPUT_ATTACH,
    INPUT_ERASE,
    INPUT_PICK,
    INPUT_SELECT,
}

enum Menu {
    MENU_OPTION_X_AXIS,
    MENU_OPTION_Y_AXIS,
    MENU_OPTION_Z_AXIS,
    MENU_OPTION_PAINT_OVERWRITE,
    MENU_OPTION_PICK_COPY_ROTATION,
    MENU_OPTION_PICK_COPY_OFFSET,
    MENU_OPTION_PICK_COPY_GROUPS,
    MENU_OPTION_CURSOR_ROTATE_X,
    MENU_OPTION_CURSOR_ROTATE_Y,
    MENU_OPTION_CURSOR_ROTATE_Z,
    MENU_OPTION_CURSOR_BACK_ROTATE_X,
    MENU_OPTION_CURSOR_BACK_ROTATE_Y,
    MENU_OPTION_CURSOR_BACK_ROTATE_Z,
    MENU_OPTION_GROUP,
    MENU_OPTION_UNGROUP,
}

enum SelectionMode {
    SELECTION_MODE_REPLACE,
    SELECTION_MODE_ADD,
    SELECTION_MODE_REMOVE,
}

var options_axis_ids: Array[Menu] = [Menu.MENU_OPTION_X_AXIS, Menu.MENU_OPTION_Y_AXIS, Menu.MENU_OPTION_Z_AXIS]

var mode_buttons_group: ButtonGroup
var last_selected_mode_button: BaseButton

var edit_axis: Vector3.Axis
var draw_offset: int
var _accumulated_draw_offset_delta: float = 0.0

var input_action: InputAction = InputAction.INPUT_NONE
var input_mouse_button: MouseButton = MOUSE_BUTTON_NONE

var undo_redo: EditorUndoRedoManager

var valid_draw_outline_material: Material
var valid_draw_fill_material: Material
var invalid_draw_outline_material: Material
var invalid_draw_fill_material: Material
var erase_draw_outline_material: Material
var erase_draw_fill_material: Material
var grid_material: Material

var _palette_index_to_path: Dictionary[int, String] = {}
var _draw_preview: Node3D
var _draw_preview_pieces: Array[Piece3D]
var _draw_scene: PackedScene
var _preview_blank: ImageTexture

var _board: Board3D

var _cursor: Node3D
var _cursor_piece_container: Node3D
var _cursor_piece_outline: PieceOutline3D
var _cursor_tile_outline: TileOutline3D
var _cursor_grid_position: Vector3i
var _cursor_grid_direction: Vector3i
var _cursor_plane_position: Vector3
var _cursor_piece: WeakRef
var _cursor_root_node: WeakRef

var _paint_overwrite: bool
var _paint_changes: Array[AddRemoveChange]
var _paint_plane_position: Vector3

var _pick_copy_rotation: bool
var _pick_copy_offset: bool
var _pick_copy_groups: bool

var _box_selection_preview_by_viewport: Dictionary[Viewport, BoxSelectionPreview]
var _selection_mode: SelectionMode
var _selection_movement_threshold_passed: bool
var _selection_original_mouse_position: Vector2
var _selection_root_nodes: Array[Node3D] = []
var _selection_root_node_bounding_boxes: Dictionary[Node3D, Rect2] = {}
var _selection_bounding_boxes_cached_camera_global_transform: Transform3D
var _selection_bounding_boxes_cached_camera_size: float
var _selection_debug: Control
var _selection_piece_outlines: Dictionary[Node3D, PieceOutline3D] = {}
var _selection_first_click_time: int = 0
var _initial_selection: Array[Node] = []

var _grid: Array[ArrayMesh]
var _grid_instances: Array[MeshInstance3D]

func _enter_tree() -> void:
    if is_part_of_edited_scene():
        return
    
    _update_theme()

    ProjectSettings.settings_changed.connect(_on_settings_changed)
    EditorInterface.get_selection().selection_changed.connect(_on_editor_selection_changed)
    undo_redo.history_changed.connect(_update_selection_outlines)
    undo_redo.version_changed.connect(_update_selection_outlines)
    
    _box_selection_preview_by_viewport = {}
    for i in range(4):
        var viewport := EditorInterface.get_editor_viewport_3d(i)
        var box_selection_preview := BoxSelectionPreview.new()
        viewport.add_child(box_selection_preview)
        _box_selection_preview_by_viewport[viewport] = box_selection_preview

func _exit_tree() -> void:
    if is_part_of_edited_scene():
        return

    ProjectSettings.settings_changed.disconnect(_on_settings_changed)
    EditorInterface.get_selection().selection_changed.disconnect(_on_editor_selection_changed)
    undo_redo.history_changed.disconnect(_update_selection_outlines)
    undo_redo.version_changed.disconnect(_update_selection_outlines)

    # Make sure we leave editor viewport camera culling masks as we found them
    _set_editor_layer_visible(GIZMO_BASE_LAYER, true)
    _set_editor_layer_visible(GIZMO_EDIT_LAYER, true)
    _set_editor_layer_visible(GIZMO_GRID_LAYER, true)

    for viewport: Viewport in _box_selection_preview_by_viewport.keys():
        var box_selection_preview := _box_selection_preview_by_viewport[viewport]
        viewport.remove_child(box_selection_preview)
        box_selection_preview.queue_free()
    _box_selection_preview_by_viewport.clear()

func _ready() -> void:
    if is_part_of_edited_scene():
        return

    valid_draw_outline_material = create_tool_material(Color(1, 1, 1, 1))
    valid_draw_fill_material = create_tool_material(Color(1, 1, 1, 0.25))
    invalid_draw_outline_material = create_tool_material(Color(0.7, 0.7, 0.7, 1))
    invalid_draw_fill_material = create_tool_material(Color(0.7, 0.7, 0.7, 0.25))
    erase_draw_outline_material = create_tool_material(Color(1, 0, 0, 1))
    erase_draw_fill_material = create_tool_material(Color(1, 0, 0, 0.25))
    grid_material = create_tool_material(Color(0.5, 0.5, 0.5, 1))
    
    _cursor = Node3D.new()
    add_child(_cursor)

    _cursor_piece_container = Node3D.new()
    _cursor.add_child(_cursor_piece_container)

    _cursor_piece_outline = PieceOutline3D.new()
    _cursor_piece_outline.outline_material = invalid_draw_outline_material
    _cursor_piece_outline.fill_material = invalid_draw_fill_material
    _cursor_piece_container.add_child(_cursor_piece_outline)

    _cursor_tile_outline = TileOutline3D.new()
    _cursor_tile_outline.outline_material = erase_draw_outline_material
    _cursor_tile_outline.fill_material = erase_draw_fill_material
    _cursor.add_child(_cursor_tile_outline)

    _grid = []
    _grid_instances = []
    for i in range(3):
        var grid_mesh := ArrayMesh.new()
        var grid_instance := MeshInstance3D.new()
        grid_instance.mesh = grid_mesh
        grid_instance.layers = 1 << MISC_TOOL_LAYER
        add_child(grid_instance)
        _grid.append(grid_mesh)
        _grid_instances.append(grid_instance)
    _draw_grids(Vector3.ONE)
    _hide_all_grids()

    var preview_blank_image := Image.create_empty(64, 64, false, Image.FORMAT_RGBA8)
    preview_blank_image.fill(Color(0, 0, 0, 0))
    _preview_blank = ImageTexture.create_from_image(preview_blank_image)

    _add_shortcuts_to_editor_settings()

    transform_mode_button.shortcut = EditorInterface.get_editor_settings().get_shortcut("puzzle_kit/transform_mode")
    paint_mode_button.shortcut = EditorInterface.get_editor_settings().get_shortcut("puzzle_kit/paint_mode")
    attach_mode_button.shortcut = EditorInterface.get_editor_settings().get_shortcut("puzzle_kit/attach_mode")
    erase_mode_button.shortcut = EditorInterface.get_editor_settings().get_shortcut("puzzle_kit/erase_mode")
    pick_mode_button.shortcut = EditorInterface.get_editor_settings().get_shortcut("puzzle_kit/pick_mode")
    select_mode_button.shortcut = EditorInterface.get_editor_settings().get_shortcut("puzzle_kit/select_mode")
    rotate_x_button.shortcut = EditorInterface.get_editor_settings().get_shortcut("puzzle_kit/cursor_rotate_x")
    rotate_y_button.shortcut = EditorInterface.get_editor_settings().get_shortcut("puzzle_kit/cursor_rotate_y")
    rotate_z_button.shortcut = EditorInterface.get_editor_settings().get_shortcut("puzzle_kit/cursor_rotate_z")
    group_button.shortcut = EditorInterface.get_editor_settings().get_shortcut("puzzle_kit/group")
    ungroup_button.shortcut = EditorInterface.get_editor_settings().get_shortcut("puzzle_kit/ungroup")
    piece_directory_pick_button.shortcut = EditorInterface.get_editor_settings().get_shortcut("puzzle_kit/pick_piece_directory")

    mode_buttons_group = ButtonGroup.new()
    transform_mode_button.button_group = mode_buttons_group
    paint_mode_button.button_group = mode_buttons_group
    attach_mode_button.button_group = mode_buttons_group
    erase_mode_button.button_group = mode_buttons_group
    pick_mode_button.button_group = mode_buttons_group
    select_mode_button.button_group = mode_buttons_group

    last_selected_mode_button = select_mode_button

    transform_mode_button.pressed.connect(_on_tool_mode_changed)
    paint_mode_button.pressed.connect(_on_tool_mode_changed)
    attach_mode_button.pressed.connect(_on_tool_mode_changed)
    erase_mode_button.pressed.connect(_on_tool_mode_changed)
    pick_mode_button.pressed.connect(_on_tool_mode_changed)
    select_mode_button.pressed.connect(_on_tool_mode_changed)

    rotate_x_button.pressed.connect(_menu_option.bind(Menu.MENU_OPTION_CURSOR_ROTATE_X))
    rotate_y_button.pressed.connect(_menu_option.bind(Menu.MENU_OPTION_CURSOR_ROTATE_Y))
    rotate_z_button.pressed.connect(_menu_option.bind(Menu.MENU_OPTION_CURSOR_ROTATE_Z))
    
    group_button.pressed.connect(_menu_option.bind(Menu.MENU_OPTION_GROUP))
    ungroup_button.pressed.connect(_menu_option.bind(Menu.MENU_OPTION_UNGROUP))

    visibility_changed.connect(_on_visibility_changed)

    draw_offset_spin_box.value_changed.connect(_set_draw_offset)

    piece_directory_pick_button.pressed.connect(_on_piece_directory_pick_button_pressed)
    piece_directory_pick_dialog.dir_selected.connect(_on_piece_directory_pick_dialog_dir_selected)
    
    palette.item_selected.connect(_on_palette_item_selected)

    group_name_filter.text_changed.connect(_on_group_name_filter_text_changed)
    groups_clear_button.pressed.connect(_on_clear_groups_pressed)
    _update_groups_list()

    edit_axis = Vector3.AXIS_Y
    draw_offset = 0

    options_button.get_popup().add_radio_check_shortcut(EditorInterface.get_editor_settings().get_shortcut("puzzle_kit/edit_x_axis"), Menu.MENU_OPTION_X_AXIS)
    options_button.get_popup().add_radio_check_shortcut(EditorInterface.get_editor_settings().get_shortcut("puzzle_kit/edit_y_axis"), Menu.MENU_OPTION_Y_AXIS)
    options_button.get_popup().add_radio_check_shortcut(EditorInterface.get_editor_settings().get_shortcut("puzzle_kit/edit_z_axis"), Menu.MENU_OPTION_Z_AXIS)
    options_button.get_popup().set_item_checked(options_button.get_popup().get_item_index(Menu.MENU_OPTION_Y_AXIS), true);
    options_button.get_popup().add_separator("Paint")
    options_button.get_popup().add_check_shortcut(EditorInterface.get_editor_settings().get_shortcut("puzzle_kit/paint_overwrites"), Menu.MENU_OPTION_PAINT_OVERWRITE)
    options_button.get_popup().add_separator("Pick")
    options_button.get_popup().add_check_shortcut(EditorInterface.get_editor_settings().get_shortcut("puzzle_kit/pick_copies_rotation"), Menu.MENU_OPTION_PICK_COPY_ROTATION)
    options_button.get_popup().add_check_shortcut(EditorInterface.get_editor_settings().get_shortcut("puzzle_kit/pick_copies_offset"), Menu.MENU_OPTION_PICK_COPY_OFFSET)
    options_button.get_popup().add_check_shortcut(EditorInterface.get_editor_settings().get_shortcut("puzzle_kit/pick_copies_groups"), Menu.MENU_OPTION_PICK_COPY_GROUPS)
    options_button.get_popup().id_pressed.connect(_menu_option)

    _load_project_settings()
    _on_editor_selection_changed()

func _add_shortcuts_to_editor_settings() -> void:
    # Toolbar
    var shortcut_transform_mode := Shortcut.new()
    shortcut_transform_mode.resource_name = "Transform"
    var input_event_transform_mode := InputEventKey.new()
    input_event_transform_mode.physical_keycode = KEY_T
    shortcut_transform_mode.events.append(input_event_transform_mode)
    EditorInterface.get_editor_settings().add_shortcut("puzzle_kit/transform_mode", shortcut_transform_mode)
    var shortcut_paint_mode := Shortcut.new()
    shortcut_paint_mode.resource_name = "Paint"
    var input_event_paint_mode := InputEventKey.new()
    input_event_paint_mode.physical_keycode = KEY_Q
    shortcut_paint_mode.events.append(input_event_paint_mode)
    EditorInterface.get_editor_settings().add_shortcut("puzzle_kit/paint_mode", shortcut_paint_mode)
    var shortcut_attach_mode := Shortcut.new()
    shortcut_attach_mode.resource_name = "Attach"
    var input_event_attach_mode := InputEventKey.new()
    input_event_attach_mode.physical_keycode = KEY_W
    shortcut_attach_mode.events.append(input_event_attach_mode)
    EditorInterface.get_editor_settings().add_shortcut("puzzle_kit/attach_mode", shortcut_attach_mode)
    var shortcut_erase_mode := Shortcut.new()
    shortcut_erase_mode.resource_name = "Erase"
    var input_event_erase_mode := InputEventKey.new()
    input_event_erase_mode.physical_keycode = KEY_E
    shortcut_erase_mode.events.append(input_event_erase_mode)
    EditorInterface.get_editor_settings().add_shortcut("puzzle_kit/erase_mode", shortcut_erase_mode)
    var shortcut_pick_mode := Shortcut.new()
    shortcut_pick_mode.resource_name = "Pick"
    var input_event_pick_mode := InputEventKey.new()
    input_event_pick_mode.physical_keycode = KEY_R
    shortcut_pick_mode.events.append(input_event_pick_mode)
    EditorInterface.get_editor_settings().add_shortcut("puzzle_kit/pick_mode", shortcut_pick_mode)
    var shortcut_select_mode := Shortcut.new()
    shortcut_select_mode.resource_name = "Select"
    var input_event_select_mode := InputEventKey.new()
    input_event_select_mode.physical_keycode = KEY_V
    shortcut_select_mode.events.append(input_event_select_mode)
    EditorInterface.get_editor_settings().add_shortcut("puzzle_kit/select_mode", shortcut_select_mode)
    var shortcut_cursor_rotate_x := Shortcut.new()
    shortcut_cursor_rotate_x.resource_name = "Cursor Rotate X"
    var input_event_cursor_rotate_x := InputEventKey.new()
    input_event_cursor_rotate_x.physical_keycode = KEY_A
    shortcut_cursor_rotate_x.events.append(input_event_cursor_rotate_x)
    EditorInterface.get_editor_settings().add_shortcut("puzzle_kit/cursor_rotate_x", shortcut_cursor_rotate_x)
    var shortcut_cursor_rotate_y := Shortcut.new()
    shortcut_cursor_rotate_y.resource_name = "Cursor Rotate Y"
    var input_event_cursor_rotate_y := InputEventKey.new()
    input_event_cursor_rotate_y.physical_keycode = KEY_S
    shortcut_cursor_rotate_y.events.append(input_event_cursor_rotate_y)
    EditorInterface.get_editor_settings().add_shortcut("puzzle_kit/cursor_rotate_y", shortcut_cursor_rotate_y)
    var shortcut_cursor_rotate_z := Shortcut.new()
    shortcut_cursor_rotate_z.resource_name = "Cursor Rotate Z"
    var input_event_cursor_rotate_z := InputEventKey.new()
    input_event_cursor_rotate_z.physical_keycode = KEY_D
    shortcut_cursor_rotate_z.events.append(input_event_cursor_rotate_z)
    EditorInterface.get_editor_settings().add_shortcut("puzzle_kit/cursor_rotate_z", shortcut_cursor_rotate_z)
    var shortcut_group := Shortcut.new()
    shortcut_group.resource_name = "Group"
    var input_event_group := InputEventKey.new()
    input_event_group.physical_keycode = KEY_G
    input_event_group.ctrl_pressed = true
    shortcut_group.events.append(input_event_group)
    EditorInterface.get_editor_settings().add_shortcut("puzzle_kit/group", shortcut_group)
    var shortcut_ungroup := Shortcut.new()
    shortcut_ungroup.resource_name = "Ungroup"
    var input_event_ungroup := InputEventKey.new()
    input_event_ungroup.physical_keycode = KEY_G
    input_event_ungroup.ctrl_pressed = true
    input_event_ungroup.shift_pressed = true
    shortcut_ungroup.events.append(input_event_ungroup)
    EditorInterface.get_editor_settings().add_shortcut("puzzle_kit/ungroup", shortcut_ungroup)
    var shortcut_piece_directory_pick := Shortcut.new()
    shortcut_piece_directory_pick.resource_name = "Pick Piece Directory"
    EditorInterface.get_editor_settings().add_shortcut("puzzle_kit/pick_piece_directory", shortcut_piece_directory_pick)
    # Options menu
    var shortcut_edit_x_axis := Shortcut.new()
    shortcut_edit_x_axis.resource_name = "Edit X Axis"
    var input_event_edit_x_axis := InputEventKey.new()
    input_event_edit_x_axis.physical_keycode = KEY_Z
    input_event_edit_x_axis.shift_pressed = true
    shortcut_edit_x_axis.events.append(input_event_edit_x_axis)
    EditorInterface.get_editor_settings().add_shortcut("puzzle_kit/edit_x_axis", shortcut_edit_x_axis)
    var shortcut_edit_y_axis := Shortcut.new()
    shortcut_edit_y_axis.resource_name = "Edit Y Axis"
    var input_event_edit_y_axis := InputEventKey.new()
    input_event_edit_y_axis.physical_keycode = KEY_X
    input_event_edit_y_axis.shift_pressed = true
    shortcut_edit_y_axis.events.append(input_event_edit_y_axis)
    EditorInterface.get_editor_settings().add_shortcut("puzzle_kit/edit_y_axis", shortcut_edit_y_axis)
    var shortcut_edit_z_axis := Shortcut.new()
    shortcut_edit_z_axis.resource_name = "Edit Z Axis"
    var input_event_edit_z_axis := InputEventKey.new()
    input_event_edit_z_axis.physical_keycode = KEY_C
    input_event_edit_z_axis.shift_pressed = true
    shortcut_edit_z_axis.events.append(input_event_edit_z_axis)
    EditorInterface.get_editor_settings().add_shortcut("puzzle_kit/edit_z_axis", shortcut_edit_z_axis)
    var shortcut_paint_overwrite := Shortcut.new()
    shortcut_paint_overwrite.resource_name = "Overwrite"
    # var input_event_paint_overwrite := InputEventKey.new()
    # shortcut_paint_overwrite.events.append(input_event_paint_overwrite)
    EditorInterface.get_editor_settings().add_shortcut("puzzle_kit/paint_overwrites", shortcut_paint_overwrite)
    var shortcut_pick_copy_rotation := Shortcut.new()
    shortcut_pick_copy_rotation.resource_name = "Copy Rotation"
    # var input_event_pick_copy_rotation := InputEventKey.new()
    # shortcut_pick_copy_rotation.events.append(input_event_pick_copy_rotation)
    EditorInterface.get_editor_settings().add_shortcut("puzzle_kit/pick_copies_rotation", shortcut_pick_copy_rotation)
    var shortcut_pick_copy_offset := Shortcut.new()
    shortcut_pick_copy_offset.resource_name = "Copy Offset"
    # var input_event_pick_copy_offset := InputEventKey.new()
    # shortcut_pick_copy_offset.events.append(input_event_pick_copy_offset)
    EditorInterface.get_editor_settings().add_shortcut("puzzle_kit/pick_copies_offset", shortcut_pick_copy_offset)
    var shortcut_pick_copy_groups := Shortcut.new()
    shortcut_pick_copy_groups.resource_name = "Copy Groups"
    # var input_event_pick_copy_groups := InputEventKey.new()
    # shortcut_pick_copy_groups.events.append(input_event_pick_copy_groups)
    EditorInterface.get_editor_settings().add_shortcut("puzzle_kit/pick_copies_groups", shortcut_pick_copy_groups)

func _process(_delta: float) -> void:
    if is_part_of_edited_scene():
        return
    
    var viewport := EditorInterface.get_editor_viewport_3d()

    update_cursor_state(viewport.get_camera_3d(), viewport.get_mouse_position())

func _notification(what: int) -> void:
    if is_part_of_edited_scene():
        return
    
    match what:
        NOTIFICATION_THEME_CHANGED:
            _update_theme()
        NOTIFICATION_APPLICATION_FOCUS_OUT:
            emulate_release_input()

func _update_theme() -> void:
    var editor_theme := EditorInterface.get_editor_theme()

    transform_mode_button.icon = editor_theme.get_icon("ToolMove", "EditorIcons")
    paint_mode_button.icon = editor_theme.get_icon("Paint", "EditorIcons")
    attach_mode_button.icon = editor_theme.get_icon("Pin", "EditorIcons")
    erase_mode_button.icon = editor_theme.get_icon("Eraser", "EditorIcons")
    pick_mode_button.icon = editor_theme.get_icon("ColorPick", "EditorIcons")
    select_mode_button.icon = editor_theme.get_icon("ToolSelect", "EditorIcons")
    rotate_x_button.icon = editor_theme.get_icon("RotateLeft", "EditorIcons")
    rotate_y_button.icon = editor_theme.get_icon("ToolRotate", "EditorIcons")
    rotate_z_button.icon = editor_theme.get_icon("RotateRight", "EditorIcons")
    group_button.icon = editor_theme.get_icon("Group", "EditorIcons")
    ungroup_button.icon = editor_theme.get_icon("Ungroup", "EditorIcons")
    piece_directory_pick_button.icon = editor_theme.get_icon("Folder", "EditorIcons")
    options_button.icon = editor_theme.get_icon("Tools", "EditorIcons")
    group_name_filter.right_icon = editor_theme.get_icon("Search", "EditorIcons")
    groups_clear_button.icon = editor_theme.get_icon("Clear", "EditorIcons")

func edit(board: Board3D) -> void:
    if board and _board == board:
        return
    
    if _board:
        emulate_release_input()
        transform_mode_button.button_pressed = true
        _on_tool_mode_changed()

    _board = board

    if _board:
        if not mode_buttons_group.get_pressed_button():
            transform_mode_button.button_pressed = true
        _on_tool_mode_changed()
        set_process(true)
        _set_interactable(true)
        container_board.visible = true
        info_no_board.visible = false
    else:
        set_process(false)
        _set_interactable(false)
        transform_mode_button.disabled = true
        container_board.visible = false
        info_no_board.visible = true
        _cursor_piece_outline.visible = false
        _cursor_tile_outline.visible = false
        _hide_all_grids()
    
    _update_path_to_board()

func _set_interactable(interactable: bool) -> void:
    transform_mode_button.disabled = not interactable
    paint_mode_button.disabled = not interactable
    attach_mode_button.disabled = not interactable
    erase_mode_button.disabled = not interactable
    pick_mode_button.disabled = not interactable
    select_mode_button.disabled = not interactable
    rotate_x_button.disabled = not interactable
    rotate_y_button.disabled = not interactable
    rotate_z_button.disabled = not interactable
    draw_offset_spin_box.editable = interactable
    piece_directory_pick_button.disabled = not interactable
    options_button.disabled = not interactable

func _on_visibility_changed() -> void:
    if is_part_of_edited_scene():
        return

    if is_visible_in_tree():
        _update_palette()

func _on_settings_changed() -> void:
    if is_part_of_edited_scene():
        return

    _load_project_settings()
    if is_visible_in_tree():
        _update_palette()
    
    if ProjectSettings.check_changed_settings_in_group("global_group"):
        ProjectSettings.save()
        _update_groups_list()

func _load_project_settings() -> void:
    piece_directory_input.text = ProjectSettings.get_setting(SETTING_PIECE_DIRECTORY, "")
    _paint_overwrite = ProjectSettings.get_setting(SETTING_PAINT_OVERWRITES, false)
    options_button.get_popup().set_item_checked(options_button.get_popup().get_item_index(Menu.MENU_OPTION_PAINT_OVERWRITE), _paint_overwrite)
    _pick_copy_rotation = ProjectSettings.get_setting(SETTING_PICK_COPIES_ROTATION, false)
    options_button.get_popup().set_item_checked(options_button.get_popup().get_item_index(Menu.MENU_OPTION_PICK_COPY_ROTATION), _pick_copy_rotation)
    _pick_copy_offset = ProjectSettings.get_setting(SETTING_PICK_COPIES_OFFSET, false)
    options_button.get_popup().set_item_checked(options_button.get_popup().get_item_index(Menu.MENU_OPTION_PICK_COPY_OFFSET), _pick_copy_offset)
    _pick_copy_groups = ProjectSettings.get_setting(SETTING_PICK_COPIES_GROUPS, false)
    options_button.get_popup().set_item_checked(options_button.get_popup().get_item_index(Menu.MENU_OPTION_PICK_COPY_GROUPS), _pick_copy_groups)

func _on_editor_selection_changed() -> void:
    edit(_get_board_to_edit_from_scene())
    _update_selection_outlines()
    _auto_enable_group_buttons()

func _get_board_to_edit_from_scene() -> Board3D:
    var edited_scene_root := EditorInterface.get_edited_scene_root()

    if not edited_scene_root:
        return null
    
    # Keep editing same board if edited_scene_root hasn't changed
    if _board and (_board == edited_scene_root or edited_scene_root.is_ancestor_of(_board)):
        return _board

    # Allow editing where scene root is a Board3D
    if edited_scene_root is Board3D:
        return edited_scene_root
    
    var nodes := edited_scene_root.get_children()
    
    # Search through nodes, first Board3D found, at most shallow depth possible
    while not nodes.is_empty():
        for node in nodes:
            if node is Board3D and (node.scene_file_path.is_empty() or edited_scene_root.is_editable_instance(node)):
                # Found a Board3D
                return node
        
        var children: Array[Node] = []
        for node in nodes:
            children.append_array(node.get_children())
        # Search next depth
        nodes = children

    return null

func _update_path_to_board() -> void:
    # Clear existing buttons
    for node in path_to_board.get_children():
        node.queue_free()
    
    if _board:
        var edited_scene_root := EditorInterface.get_edited_scene_root()
        var board_node_path := edited_scene_root.get_path_to(_board)
        var node_count := board_node_path.get_name_count()
        # Add a button for the root node
        var root_button := Button.new()
        root_button.text = edited_scene_root.name
        root_button.disabled = not edited_scene_root is Board3D
        root_button.z_index = node_count
        root_button.pressed.connect(edit.bind(edited_scene_root as Board3D))
        path_to_board.add_child(root_button)
        # Add buttons for each descendent node in the path to the board
        for i in range(node_count):
            var node_name := board_node_path.get_name(i)
            # If node name is "." then this is the scene root and we already have a button for it
            if node_name == ".":
                continue
            var node_path := board_node_path.slice(0, i + 1)
            var node := edited_scene_root.get_node(node_path)
            var node_button := Button.new()
            node_button.text = node_name
            node_button.disabled = not node is Board3D
            node_button.z_index = node_count - i - 1
            node_button.pressed.connect(edit.bind(node as Board3D))
            path_to_board.add_child(node_button)

static func _find_nearest_ancestor_board(node: Node) -> Board3D:
    if not node.is_inside_tree():
        return null
    var search_parent := node.get_parent()
    # Search our parent and parent of parent, etc
    while search_parent:
        # Found a board
        if search_parent is Board3D:
            return search_parent
        # Update which node we're looking at for next iteration
        search_parent = search_parent.get_parent()
    # Reached the root without finding anything
    return null

func _on_tool_mode_changed() -> void:
    if mode_buttons_group.get_pressed_button() != transform_mode_button:
        last_selected_mode_button = mode_buttons_group.get_pressed_button()
    auto_setup_draw_preview()
    # Hide by default
    _cursor_piece_outline.visible = false
    _cursor_tile_outline.visible = false
    _hide_all_grids()
    # Hide some editor stuff when we don't need it
    _set_editor_layer_visible(GIZMO_BASE_LAYER, mode_buttons_group.get_pressed_button() == transform_mode_button)
    _set_editor_layer_visible(GIZMO_EDIT_LAYER, mode_buttons_group.get_pressed_button() == transform_mode_button)
    _set_editor_layer_visible(GIZMO_GRID_LAYER, mode_buttons_group.get_pressed_button() == transform_mode_button || mode_buttons_group.get_pressed_button() == pick_mode_button || mode_buttons_group.get_pressed_button() == select_mode_button)

func _set_draw_offset(value: float) -> void:
    draw_offset = roundi(value)

func _menu_option(id: Menu) -> void:
    match id:
        Menu.MENU_OPTION_X_AXIS, Menu.MENU_OPTION_Y_AXIS, Menu.MENU_OPTION_Z_AXIS:
            for axis_id in options_axis_ids:
                var index := options_button.get_popup().get_item_index(axis_id)
                options_button.get_popup().set_item_checked(index, axis_id == id)
                edit_axis = (id - Menu.MENU_OPTION_X_AXIS) as Vector3.Axis
        Menu.MENU_OPTION_PAINT_OVERWRITE:
            _paint_overwrite = not _paint_overwrite
            options_button.get_popup().set_item_checked(options_button.get_popup().get_item_index(id), _paint_overwrite)
            ProjectSettings.set_setting(SETTING_PAINT_OVERWRITES, _paint_overwrite)
            ProjectSettings.save()
        Menu.MENU_OPTION_PICK_COPY_ROTATION:
            _pick_copy_rotation = not _pick_copy_rotation
            options_button.get_popup().set_item_checked(options_button.get_popup().get_item_index(id), _pick_copy_rotation)
            ProjectSettings.set_setting(SETTING_PICK_COPIES_ROTATION, _pick_copy_rotation)
            ProjectSettings.save()
        Menu.MENU_OPTION_PICK_COPY_OFFSET:
            _pick_copy_offset = not _pick_copy_offset
            options_button.get_popup().set_item_checked(options_button.get_popup().get_item_index(id), _pick_copy_offset)
            ProjectSettings.set_setting(SETTING_PICK_COPIES_OFFSET, _pick_copy_offset)
            ProjectSettings.save()
        Menu.MENU_OPTION_PICK_COPY_GROUPS:
            _pick_copy_groups = not _pick_copy_groups
            options_button.get_popup().set_item_checked(options_button.get_popup().get_item_index(id), _pick_copy_groups)
            ProjectSettings.set_setting(SETTING_PICK_COPIES_GROUPS, _pick_copy_groups)
            ProjectSettings.save()
        Menu.MENU_OPTION_CURSOR_ROTATE_X, Menu.MENU_OPTION_CURSOR_ROTATE_Y, Menu.MENU_OPTION_CURSOR_ROTATE_Z, \
        Menu.MENU_OPTION_CURSOR_BACK_ROTATE_X, Menu.MENU_OPTION_CURSOR_BACK_ROTATE_Y, Menu.MENU_OPTION_CURSOR_BACK_ROTATE_Z:
            var rotation_axis := Vector3()
            if id == Menu.MENU_OPTION_CURSOR_ROTATE_X or id == Menu.MENU_OPTION_CURSOR_BACK_ROTATE_X:
                rotation_axis.x = 1 if id == Menu.MENU_OPTION_CURSOR_ROTATE_X else -1
            elif id == Menu.MENU_OPTION_CURSOR_ROTATE_Y or id == Menu.MENU_OPTION_CURSOR_BACK_ROTATE_Y:
                rotation_axis.y = 1 if id == Menu.MENU_OPTION_CURSOR_ROTATE_Y else -1
            elif id == Menu.MENU_OPTION_CURSOR_ROTATE_Z or id == Menu.MENU_OPTION_CURSOR_BACK_ROTATE_Z:
                rotation_axis.z = 1 if id == Menu.MENU_OPTION_CURSOR_ROTATE_Z else -1
            _cursor_piece_container.rotate(rotation_axis, -PI / 2.0)
        Menu.MENU_OPTION_GROUP:
            _group_selection()
        Menu.MENU_OPTION_UNGROUP:
            _ungroup_selection()

func _set_editor_layer_visible(layer: int, value: bool) -> void:
    for i in range(4):
        var viewport_camera := EditorInterface.get_editor_viewport_3d(i).get_camera_3d()
        var viewport_layer := layer
        if layer == GIZMO_BASE_LAYER:
            viewport_layer = layer + i
        if value:
            viewport_camera.cull_mask |= (1 << viewport_layer)
        else:
            viewport_camera.cull_mask &= ~(1 << viewport_layer)

func _update_selection_outlines() -> void:
    if not _board:
        # Clear all outlines
        for root_node in _selection_piece_outlines:
            var piece_outline := _selection_piece_outlines[root_node]
            piece_outline.free()
            _selection_piece_outlines.erase(root_node)
        _selection_piece_outlines.clear()
        return
    
    var selected_root_nodes: Array[Node3D] = []
    
    for node in EditorInterface.get_selection().get_selected_nodes():
        var root_node := _get_node_root_in_ancestor(node, _board) as Node3D

        if not root_node:
            continue

        if root_node in selected_root_nodes:
            # Already processed this root node
            continue
        
        if root_node == _board:
            continue
        
        selected_root_nodes.append(root_node)
        
        if root_node in _selection_piece_outlines:
            var piece_outline := _selection_piece_outlines[root_node]
            piece_outline.global_transform = root_node.global_transform
        else:
            var piece_outline := PieceOutline3D.new()
            piece_outline.generate_from(root_node)
            piece_outline.global_transform = root_node.global_transform
            piece_outline.fill_material = valid_draw_fill_material
            piece_outline.outline_material = valid_draw_outline_material
            add_child(piece_outline)
            _selection_piece_outlines[root_node] = piece_outline
    
    # Remove piece outlines that are no longer selected
    for root_node: Node3D in _selection_piece_outlines.keys().duplicate():
        if root_node in selected_root_nodes:
            continue
        
        var piece_outline := _selection_piece_outlines[root_node]
        piece_outline.free()
        _selection_piece_outlines.erase(root_node)

#region Grid
func _draw_grids(cell_size: Vector3) -> void:
    for i in range(3):
        var grid := _grid[i]

        grid.clear_surfaces()

        var axis_n1 := Vector3()
        axis_n1[(i + 1) % 3] = cell_size[(i + 1) % 3]
        var axis_n2 := Vector3()
        axis_n2[(i + 2) % 3] = cell_size[(i + 2) % 3]

        var grid_points := PackedVector3Array()
        var grid_colors := PackedColorArray()

        for j in range(-GRID_CURSOR_SIZE, GRID_CURSOR_SIZE + 1):
            for k in range(-GRID_CURSOR_SIZE, GRID_CURSOR_SIZE + 1):
                var p := axis_n1 * (j - 0.5) + axis_n2 * (k - 0.5)
                var trans := pow(maxf(0, 1.0 - (Vector2(j - 0.5, k - 0.5).length() / GRID_CURSOR_SIZE)), 2)

                var pj := axis_n1 * (j + 0.5) + axis_n2 * (k - 0.5)
                var transj := pow(maxf(0, 1.0 - (Vector2(j + 0.5, k - 0.5).length() / GRID_CURSOR_SIZE)), 2)

                var pk := axis_n1 * (j - 0.5) + axis_n2 * (k + 0.5)
                var transk := pow(maxf(0, 1.0 - (Vector2(j - 0.5, k + 0.5).length() / GRID_CURSOR_SIZE)), 2)

                grid_points.push_back(p)
                grid_points.push_back(pk)
                grid_colors.push_back(Color(1, 1, 1, trans))
                grid_colors.push_back(Color(1, 1, 1, transk))

                grid_points.push_back(p)
                grid_points.push_back(pj)
                grid_colors.push_back(Color(1, 1, 1, trans))
                grid_colors.push_back(Color(1, 1, 1, transj))

        var d := Array()
        d.resize(Mesh.ARRAY_MAX)
        d[Mesh.ARRAY_VERTEX] = grid_points
        d[Mesh.ARRAY_COLOR] = grid_colors
        grid.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, d)
        grid.surface_set_material(0, grid_material)

func _hide_all_grids() -> void:
    for i in range(3):
        _grid_instances[i].visible = false
#endregion

#region Piece palette
func _on_piece_directory_pick_button_pressed() -> void:
    piece_directory_pick_dialog.show()

func _on_piece_directory_pick_dialog_dir_selected(dir: String) -> void:
    piece_directory_input.text = dir
    ProjectSettings.set_setting(SETTING_PIECE_DIRECTORY, dir)
    ProjectSettings.save()
    _update_palette()

func _on_palette_item_selected(index: int) -> void:
    _setup_draw_scene_from_palette_index(index)
    # Automatically change tool when palette item is manually selected
    if _draw_scene:
        paint_mode_button.set_pressed(true)
    else:
        erase_mode_button.set_pressed(true)
    _on_tool_mode_changed()

func _set_palette_selected_index(index: int) -> void:
    palette.select(index, true)
    _setup_draw_scene_from_palette_index(index)

func _setup_draw_scene_from_palette_index(index: int) -> void:
    _draw_scene = _get_palette_scene_at_index(index)
    auto_setup_draw_preview()

func _get_palette_scene_at_index(index: int) -> PackedScene:
    if not index in _palette_index_to_path:
        return null

    var path := _palette_index_to_path[index]

    if path == "":
        return null

    var scene := load(path)

    if scene:
        return scene
    
    return null

func _update_palette() -> void:
    palette.clear()
    _palette_index_to_path.clear()

    var piece_palette_base_directory: String = ProjectSettings.get_setting(SETTING_PIECE_DIRECTORY, "")
    if piece_palette_base_directory.is_empty():
        # Default to all resources
        piece_palette_base_directory = "res://"
    
    if not DirAccess.dir_exists_absolute(piece_palette_base_directory):
        # Keep existing palette by default
        return

    _add_to_palette_from_dir(piece_palette_base_directory, piece_palette_base_directory)

func _add_to_palette_from_dir(path: String, base_path: String) -> void:
    for filename in DirAccess.get_files_at(path):
        if not filename.ends_with(".tscn"):
            # Only interested in scenes
            continue
        var file_path := path.path_join(filename)
        var packed_scene := load(file_path) as PackedScene
        if not packed_scene:
            # Failed to load scene
            continue
        var scene_state := packed_scene.get_state()
        if scene_state.get_node_type(0) != "Node3D":
            # Only interested in scenes with Node3D root nodes
            continue
        var relative_file_path := file_path
        if relative_file_path.begins_with(base_path):
            relative_file_path = relative_file_path.substr(base_path.length())
            if relative_file_path.begins_with("/"):
                relative_file_path = relative_file_path.substr(1)
        EditorInterface.get_resource_previewer().queue_resource_preview(file_path, self, "_add_palette_item", relative_file_path)
    for dir_name in DirAccess.get_directories_at(path):
        if dir_name.begins_with("."):
            # Ignore hidden directories
            continue
        _add_to_palette_from_dir(path.path_join(dir_name), base_path)

func _add_palette_item(path: String, preview: Texture2D, _thumbnail_preview: Texture2D, item_text: String) -> void:
    if not preview:
        preview = _preview_blank
    var item_index := palette.add_item(item_text, preview)
    _palette_index_to_path[item_index] = path

#endregion

#region Add to Groups
func _on_group_name_filter_text_changed(filter: String) -> void:
    _update_filtered_groups(filter)

func _update_groups_list() -> void:
    var global_groups := _load_global_groups_from_config_file()
    var global_groups_to_add := global_groups.duplicate()

    # Remove checkboxes for deleted groups
    for group_checkbox: CheckBox in group_checkboxes.duplicate():
        if group_checkbox.text in global_groups:
            # CheckBox still valid
            global_groups_to_add.erase(group_checkbox.text)
            continue
        group_checkbox.pressed.disconnect(_on_group_checkbox_pressed)
        groups_container.remove_child(group_checkbox)
        group_checkboxes.erase(group_checkbox)
        group_checkbox.queue_free()
    
    # Add new checkboxes for created groups
    for group_name in global_groups_to_add:
        var group_checkbox := CheckBox.new()
        group_checkbox.text = group_name
        group_checkbox.pressed.connect(_on_group_checkbox_pressed)
        groups_container.add_child(group_checkbox)
        group_checkboxes.append(group_checkbox)
    
    global_groups.sort()
    # Reorder
    for group_checkbox in group_checkboxes:
        groups_container.move_child(group_checkbox, global_groups.find(group_checkbox.text))

    _update_filtered_groups(group_name_filter.text)

func _load_global_groups_from_config_file() -> PackedStringArray:
    var project_config := ConfigFile.new()

    if project_config.load("res://project.godot") != OK:
        return []

    if not project_config.has_section("global_group"):
        return []

    return project_config.get_section_keys("global_group")

func _on_group_checkbox_pressed() -> void:
    _update_filtered_groups(group_name_filter.text)

func _update_filtered_groups(filter: String) -> void:
    for group_checkbox in group_checkboxes:
        group_checkbox.visible = group_checkbox.button_pressed or filter.is_empty() or group_checkbox.text.contains(filter)

func _on_clear_groups_pressed() -> void:
    for group_checkbox in group_checkboxes:
        group_checkbox.button_pressed = false
    _update_filtered_groups(group_name_filter.text)
#endregion

#region Input
func forward_spatial_input_event(viewport_camera: Camera3D, event: InputEvent) -> int:
    # Don't do anything if we don't have an active board to edit
    if not _board:
        return EditorPlugin.AFTER_GUI_INPUT_PASS

    # If the mouse is currently captured, we are most likely in freelook mode.
    # In this case, disable shortcuts to avoid conflicts with freelook navigation.
    if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
        return EditorPlugin.AFTER_GUI_INPUT_PASS

    if event is InputEventKey:
        var k := event as InputEventKey
        if k.is_pressed() and not k.is_echo():
            # Transform mode (toggle button):
            # If we are in Transform mode we pass the events to the 3D editor,
            # but if the Transform mode shortcut is pressed again, we go back to the last-selected mode button
            if mode_buttons_group.get_pressed_button() == transform_mode_button:
                if transform_mode_button.shortcut.has_valid_event() and transform_mode_button.shortcut.matches_event(event):
                    last_selected_mode_button.set_pressed(true)
                    _on_tool_mode_changed()
                    accept_event()
                    return EditorPlugin.AFTER_GUI_INPUT_STOP
                return EditorPlugin.AFTER_GUI_INPUT_PASS
            # Tool modes and tool actions:
            for button in viewport_shortcut_buttons:
                if button.disabled:
                    continue
                if button.shortcut and button.shortcut.has_valid_event() and button.shortcut.matches_event(event):
                    if button.toggle_mode:
                        button.button_pressed = button.button_group or not button.pressed
                        if button.button_group == mode_buttons_group:
                            _on_tool_mode_changed()
                    else:
                        # Can't press a button without toggle mode, so just emit the signal directly.
                        button.pressed.emit()
                    accept_event()
                    return EditorPlugin.AFTER_GUI_INPUT_STOP

    if event is InputEventMouseButton:
        var mb := event as InputEventMouseButton

        # Change draw offset with Ctrl + Scroll Wheel
        if mode_buttons_group.get_pressed_button() != transform_mode_button:
            if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.is_command_or_control_pressed():
                if mb.is_pressed():
                    draw_offset_spin_box.value += mb.factor
                return EditorPlugin.AFTER_GUI_INPUT_STOP
            if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.is_command_or_control_pressed():
                if mb.is_pressed():
                    draw_offset_spin_box.value -= mb.factor
                return EditorPlugin.AFTER_GUI_INPUT_STOP
        
        if mb.is_pressed():
            # Ignore input in transform mode
            if mode_buttons_group.get_pressed_button() == transform_mode_button:
                return EditorPlugin.AFTER_GUI_INPUT_PASS

            if input_action != InputAction.INPUT_NONE:
                # Already performing an input
                return EditorPlugin.AFTER_GUI_INPUT_PASS
            if mb.button_index == MOUSE_BUTTON_LEFT:
                if mode_buttons_group.get_pressed_button() == paint_mode_button:
                    input_action = InputAction.INPUT_PAINT
                elif mode_buttons_group.get_pressed_button() == attach_mode_button:
                    input_action = InputAction.INPUT_ATTACH
                elif mode_buttons_group.get_pressed_button() == erase_mode_button:
                    input_action = InputAction.INPUT_ERASE
                elif mode_buttons_group.get_pressed_button() == pick_mode_button:
                    input_action = InputAction.INPUT_PICK
                elif mode_buttons_group.get_pressed_button() == select_mode_button:
                    input_action = InputAction.INPUT_SELECT
                    if mb.is_command_or_control_pressed():
                        _selection_mode = SelectionMode.SELECTION_MODE_REMOVE
                    elif mb.shift_pressed:
                        _selection_mode = SelectionMode.SELECTION_MODE_ADD
                    else:
                        _selection_mode = SelectionMode.SELECTION_MODE_REPLACE
            elif mb.button_index == MOUSE_BUTTON_RIGHT:
                input_action = InputAction.INPUT_PICK
            else:
                return EditorPlugin.AFTER_GUI_INPUT_PASS
            
            if input_action != InputAction.INPUT_NONE:
                input_mouse_button = mb.button_index
            
            if do_input_action(viewport_camera, mb.position, true):
                return EditorPlugin.AFTER_GUI_INPUT_STOP
            return EditorPlugin.AFTER_GUI_INPUT_PASS
        else:
            if mb.button_index == input_mouse_button:
                if input_action == InputAction.INPUT_PAINT:
                    if not _paint_changes.is_empty():
                        # Setup undo history
                        # `backward_undo_ops` is set to true in `create_action` so we don't need to add undo methods in reverse
                        undo_redo.create_action("PuzzleKit Paint", UndoRedo.MERGE_DISABLE, _board.owner, true, true)
                        for change in _paint_changes:
                            change.register_with_undo_redo(undo_redo)
                        undo_redo.commit_action(false)
                        _paint_changes.clear()
                elif input_action == InputAction.INPUT_ERASE:
                    if not _paint_changes.is_empty():
                        # Setup undo history
                        # `backward_undo_ops` is set to true in `create_action` so we don't need to add undo methods in reverse
                        undo_redo.create_action("PuzzleKit Erase", UndoRedo.MERGE_DISABLE, _board.owner, true, true)
                        for change in _paint_changes:
                            change.register_with_undo_redo(undo_redo)
                        undo_redo.commit_action(false)
                        _paint_changes.clear()
                elif input_action == InputAction.INPUT_SELECT:
                    for box_selection_preview: BoxSelectionPreview in _box_selection_preview_by_viewport.values():
                        box_selection_preview.clear()
                    _selection_root_nodes.clear()
                    _selection_root_node_bounding_boxes.clear()
                    _initial_selection.clear()
                    if _selection_debug:
                        _selection_debug.get_parent().remove_child(_selection_debug)
                        _selection_debug.queue_free()
                    if not _selection_movement_threshold_passed:
                        # Select what's under cursor
                        update_cursor_state_raycast_piece(viewport_camera, mb.position)
                        var is_double_click := Time.get_ticks_msec() - _selection_first_click_time <= 300
                        var new_selection: Node = null
                        var select_node: Variant = _cursor_root_node.get_ref() if _cursor_root_node else null
                        if select_node is Node3D:
                            new_selection = select_node
                        var editor_selection := EditorInterface.get_selection()
                        if _selection_mode == SelectionMode.SELECTION_MODE_REMOVE:
                            if new_selection in editor_selection.get_selected_nodes():
                                editor_selection.remove_node(new_selection)
                        elif _selection_mode == SelectionMode.SELECTION_MODE_ADD:
                            if new_selection:
                                editor_selection.add_node(new_selection)
                        elif is_double_click and new_selection is Board3D and new_selection in editor_selection.get_selected_nodes():
                            # Edit double-clicked Board3D
                            board_edit_requested.emit(new_selection as Board3D)
                        elif is_double_click and not new_selection and editor_selection.get_selected_nodes().is_empty():
                            # Back out to current Board3D's parent
                            if _board.parent_board:
                                board_edit_requested.emit(_board.parent_board)
                        else: # _selection_mode == SelectionMode.SELECTION_MODE_REPLACE
                            editor_selection.clear()
                            if new_selection:
                                editor_selection.add_node(new_selection)
                            _selection_first_click_time = Time.get_ticks_msec()

                input_action = InputAction.INPUT_NONE
                input_mouse_button = MOUSE_BUTTON_NONE

    if event is InputEventMouseMotion:
        var mm := event as InputEventMouseMotion

        if do_input_action(viewport_camera, mm.position, false):
            return EditorPlugin.AFTER_GUI_INPUT_STOP
        return EditorPlugin.AFTER_GUI_INPUT_PASS

    if event is InputEventPanGesture:
        # Ignore input in transform mode
        if mode_buttons_group.get_pressed_button() == transform_mode_button:
            return EditorPlugin.AFTER_GUI_INPUT_PASS

        var pg := event as InputEventPanGesture
        # Change draw offset with Ctrl + Pan Gesture
        if pg.is_command_or_control_pressed():
            var delta := pg.delta.y * 0.5
            _accumulated_draw_offset_delta += delta
            var step := 0
            if abs(_accumulated_draw_offset_delta) > 1.0:
                step = signi(roundi(_accumulated_draw_offset_delta))
                _accumulated_draw_offset_delta -= step
            if step:
                draw_offset_spin_box.value += step
            return EditorPlugin.AFTER_GUI_INPUT_STOP

    return EditorPlugin.AFTER_GUI_INPUT_PASS

func do_input_action(camera: Camera3D, mouse_position: Vector2, click: bool) -> bool:
    if input_action == InputAction.INPUT_PAINT:
        update_cursor_state_on_plane(camera, mouse_position, edit_axis, draw_offset)
        var paint_positions: Array[Vector3i]
        if click:
            _paint_changes = []
            # Always try to draw once under cursor on click
            paint_positions = [_cursor_grid_position]
        else:
            # Get positions between position we previously painted at and new position (in case of fast mouse movement)
            paint_positions = get_cells_entered(_paint_plane_position, _cursor_plane_position)
        _paint_plane_position = _cursor_plane_position
        # Nothing to draw
        if not _draw_scene:
            return true
        for paint_position in paint_positions:
            _cursor.global_position = paint_position
            if _paint_overwrite and not erase_pieces_overlapping_preview():
                    continue
            if not can_paint_at_preview_position():
                continue
            var node := _draw_scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
            var node3d := node as Node3D
            if not node3d:
                node.queue_free()
                return true
            _board.add_child(node3d, true)
            node3d.global_transform = _cursor_piece_container.global_transform
            if _board == EditorInterface.get_edited_scene_root():
                node3d.owner = _board
            else:
                node3d.owner = _board.owner
            # Add to custom groups
            for group_checkbox in group_checkboxes:
                if not group_checkbox.button_pressed or node3d.is_in_group(group_checkbox.text):
                    continue
                node3d.add_to_group(group_checkbox.text, true)
            var change := AddRemoveChange.create_from(node3d, AddRemoveChange.Action.ADD)
            _paint_changes.append(change)
        return true
    if input_action == InputAction.INPUT_ERASE:
        update_cursor_state_on_plane(camera, mouse_position, edit_axis, draw_offset)
        var erase_positions: Array[Vector3i]
        if click:
            _paint_changes = []
            # Always try to draw once under cursor on click
            erase_positions = [_cursor_grid_position]
        else:
            # Get positions between position we previously painted at and new position (in case of fast mouse movement)
            erase_positions = get_cells_entered(_paint_plane_position, _cursor_plane_position)
        _paint_plane_position = _cursor_plane_position
        for erase_position in erase_positions:
            for piece_under_cursor: Piece3D in _board.get_pieces_at(erase_position).duplicate():
                var piece_root_node := _get_piece_root_in_board(piece_under_cursor)
                if piece_root_node is Board3D:
                    # Don't erase whole boards
                    continue
                if piece_root_node is Node3D:
                    var piece_root_node3d := piece_root_node as Node3D
                    var change := AddRemoveChange.create_from(piece_root_node3d, AddRemoveChange.Action.REMOVE)
                    _paint_changes.append(change)
                    piece_root_node3d.get_parent().remove_child(piece_root_node3d)
        return true
    if input_action == InputAction.INPUT_PICK:
        update_cursor_state(camera, mouse_position)
        var found_palette_item := false
        var pick_node: Variant = _cursor_root_node.get_ref() if _cursor_root_node else null
        if pick_node is Node3D:
            var node3d: Node3D = pick_node
            for index: int in _palette_index_to_path.keys():
                var path := _palette_index_to_path[index]
                if path == node3d.scene_file_path:
                    _set_palette_selected_index(index)
                    found_palette_item = true
                    break
            if _pick_copy_rotation:
                _cursor_piece_container.global_rotation = node3d.global_rotation
            if _pick_copy_offset:
                draw_offset_spin_box.value = round(node3d.global_position[edit_axis])
            if _pick_copy_groups:
                for group_checkbox in group_checkboxes:
                    group_checkbox.button_pressed = node3d.is_in_group(group_checkbox.text)
                _update_filtered_groups(group_name_filter.text)
        if input_mouse_button == MOUSE_BUTTON_RIGHT:
            if found_palette_item:
                paint_mode_button.set_pressed(true)
                _on_tool_mode_changed()
            elif not pick_node:
                erase_mode_button.set_pressed(true)
                _on_tool_mode_changed()
                if _pick_copy_groups:
                    for group_checkbox in group_checkboxes:
                        group_checkbox.button_pressed = false
                    _update_filtered_groups(group_name_filter.text)
        return true
    if input_action == InputAction.INPUT_SELECT:
        var box_selection_preview := _box_selection_preview_by_viewport[camera.get_viewport()]
        var editor_selection := EditorInterface.get_selection()
        if click:
            _selection_movement_threshold_passed = false
            _selection_original_mouse_position = mouse_position
            # Get a list of all selectable nodes
            _selection_root_nodes.clear()
            for piece in _board.get_pieces():
                var piece_root_node := _get_piece_root_in_board(piece)
                if piece_root_node in _selection_root_nodes:
                    # Already found
                    continue
                _selection_root_nodes.append(piece_root_node)
            # Save initial selection
            _initial_selection = editor_selection.get_selected_nodes()
            # Calculate screen-space bounding boxes for selectable nodes
            _selection_debug = Control.new()
            _selection_debug.visible = false
            _selection_debug.draw.connect(_draw_selection_debug)
            camera.get_viewport().add_child(_selection_debug)
            _update_box_selection_bounding_boxes(camera, true)
        # Start box-selecting when mouse has moved enough from starting position
        if not _selection_movement_threshold_passed:
            _selection_movement_threshold_passed = _selection_original_mouse_position.distance_to(mouse_position) > 8 * EditorInterface.get_editor_theme().get_constant("scale", "Editor")
        if _selection_movement_threshold_passed:
            # Draw box selection
            box_selection_preview.rect = Rect2(_selection_original_mouse_position, mouse_position - _selection_original_mouse_position).abs()
            # Box selection
            _update_box_selection_bounding_boxes(camera)
            var new_selection: Array[Node] = []
            # Reset to initial selection if we're not just replacing
            if _selection_mode == SelectionMode.SELECTION_MODE_ADD or _selection_mode == SelectionMode.SELECTION_MODE_REMOVE:
                new_selection = _initial_selection.duplicate()
            # Find nodes contained in the selection box and modify their selection state
            for node: Node3D in _selection_root_node_bounding_boxes.keys():
                var node_bounding_box := _selection_root_node_bounding_boxes[node]
                if box_selection_preview.rect.encloses(node_bounding_box):
                    if _selection_mode == SelectionMode.SELECTION_MODE_REMOVE:
                        new_selection.erase(node)
                    elif not node in new_selection:
                        new_selection.append(node)
            var current_editor_selection := editor_selection.get_selected_nodes()
            # Deselect nodes that should no longer be selected
            for node: Node in current_editor_selection.filter(func(x: Node) -> bool: return not x in new_selection):
                editor_selection.remove_node(node)
            # Select nodes that should now be selected
            for node: Node in new_selection.filter(func(x: Node) -> bool: return not x in current_editor_selection):
                editor_selection.add_node(node)
        return true
    return false

func emulate_release_input() -> void:
    if input_action == InputAction.INPUT_NONE:
        return
    var release_event := InputEventMouseButton.new()
    release_event.button_index = input_mouse_button
    forward_spatial_input_event(null, release_event)

func _update_box_selection_bounding_boxes(camera: Camera3D, force: bool = false) -> void:
    if not force and camera.global_transform == _selection_bounding_boxes_cached_camera_global_transform and camera.size == _selection_bounding_boxes_cached_camera_size:
        return

    # Cache values to skip recalculating if camera hasn't changed
    _selection_bounding_boxes_cached_camera_global_transform = camera.global_transform
    _selection_bounding_boxes_cached_camera_size = camera.size

    _selection_root_node_bounding_boxes.clear()
    for node in _selection_root_nodes:
        var node_pieces: Array[Piece3D] = []
        Piece3D.find_descendant_pieces(node, node_pieces)
        var node_bounding_box := Rect2()
        var first_corner := true
        # Calculate root node bounding box from unprojecting its corners to screen space
        for piece in node_pieces:
            var piece_position: Vector3 = piece.grid_position
            for corner in CUBE_CORNERS:
                var corner_position := piece_position + corner
                var corner_screen_position := camera.unproject_position(corner_position)
                if first_corner:
                    node_bounding_box = Rect2(corner_screen_position, Vector2())
                    first_corner = false
                else:
                    node_bounding_box = node_bounding_box.expand(corner_screen_position)
        _selection_root_node_bounding_boxes[node] = node_bounding_box
    
    _selection_debug.queue_redraw()

func _draw_selection_debug() -> void:
    for node: Node3D in _selection_root_node_bounding_boxes.keys():
        var node_bounding_box := _selection_root_node_bounding_boxes[node]
        _selection_debug.draw_rect(node_bounding_box, Color.BLUE, false)

func _get_piece_root_in_board(piece: Piece3D) -> Node:
    if not _board:
        return null

    if not piece:
        return null
    
    if piece._board != _board:
        var search_board := piece._board

        # Walk back through piece board's ancestry to find a direct child board of the one we're editing (or null if it's not a child)
        while search_board and search_board.parent_board != _board:
            search_board = search_board.parent_board
        
        return search_board
    
    # Piece is from the board we're editing
    return _get_node_root_in_ancestor(piece, _board)

static func _get_node_root_in_ancestor(node: Node, ancestor: Node) -> Node:
    if not node:
        return null

    if not node.owner:
        # Node is temporary
        return null
    
    if node.owner == ancestor.owner or node.owner == ancestor:
        # Found node owned by ancestor's scene
        return node
    
    # Search from node's owner
    return _get_node_root_in_ancestor(node.owner, ancestor)

static func _create_plane_aabb(axis: Vector3.Axis, plane_offset: float) -> AABB:
    match axis:
        Vector3.AXIS_X: return AABB(Vector3(plane_offset - 0.5, -500000, -500000), Vector3(1.0, 1000000, 1000000))
        Vector3.AXIS_Y: return AABB(Vector3(-500000, plane_offset - 0.5, -500000), Vector3(1000000, 1.0, 1000000))
        Vector3.AXIS_Z: return AABB(Vector3(-500000, -500000, plane_offset - 0.5), Vector3(1000000, 1000000, 1.0))

    return AABB()

static func _create_plane(axis: Vector3.Axis, plane_offset: float) -> Plane:
    match axis:
        Vector3.AXIS_X: return Plane(Vector3.RIGHT, plane_offset)
        Vector3.AXIS_Y: return Plane(Vector3.UP, plane_offset)
        Vector3.AXIS_Z: return Plane(Vector3.BACK, plane_offset)

    return Plane()

static func _get_grid_position_from_intersection(intersection_point: Vector3, axis: Vector3.Axis, plane_offset: float) -> Vector3:
    match axis:
        Vector3.AXIS_X: return Vector3(plane_offset, roundf(intersection_point.y), roundf(intersection_point.z))
        Vector3.AXIS_Y: return Vector3(roundf(intersection_point.x), plane_offset, roundf(intersection_point.z))
        Vector3.AXIS_Z: return Vector3(roundf(intersection_point.x), roundf(intersection_point.y), plane_offset)
    
    return Vector3()

static func _get_plane_position_from_intersection(intersection_point: Vector3, axis: Vector3.Axis, plane_offset: float) -> Vector3:
    match axis:
        Vector3.AXIS_X: return Vector3(plane_offset, intersection_point.y, intersection_point.z)
        Vector3.AXIS_Y: return Vector3(intersection_point.x, plane_offset, intersection_point.z)
        Vector3.AXIS_Z: return Vector3(intersection_point.x, intersection_point.y, plane_offset)
    
    return Vector3()

func update_cursor_state(camera: Camera3D, mouse_position: Vector2) -> void:
    _cursor_piece = null
    _cursor_root_node = null

    if input_action == InputAction.INPUT_PICK or mode_buttons_group.get_pressed_button() == pick_mode_button:
        _cursor_piece_container.transform = Transform3D.IDENTITY
        _cursor_piece_outline.visible = true
        _cursor_tile_outline.visible = false
        _hide_all_grids()
        if input_action == InputAction.INPUT_PICK:
            _cursor_piece_outline.outline_material = valid_draw_outline_material
            _cursor_piece_outline.fill_material = valid_draw_fill_material
        else:
            _cursor_piece_outline.outline_material = invalid_draw_outline_material
            _cursor_piece_outline.fill_material = invalid_draw_fill_material
        # Using pick mode tool
        if mode_buttons_group.get_pressed_button() == pick_mode_button:
            update_cursor_state_raycast_piece(camera, mouse_position)
        # Right-click quick-pick
        else:
            update_cursor_state_on_plane(camera, mouse_position, edit_axis, draw_offset)
            var piece_under_cursor := _board.get_piece_at(_cursor_grid_position)
            if piece_under_cursor:
                var piece_root_node := _get_piece_root_in_board(piece_under_cursor)
                if piece_root_node is Board3D:
                    var piece_root_board3d := piece_root_node as Node3D
                    _cursor_piece_container.global_transform = piece_root_board3d.global_transform
                    _cursor_piece_outline.generate_from(piece_root_board3d)
                    _cursor_piece_outline.outline_material = invalid_draw_outline_material
                    _cursor_piece_outline.fill_material = invalid_draw_fill_material
                elif piece_root_node is Node3D:
                    var piece_root_node3d := piece_root_node as Node3D
                    _cursor_piece = weakref(piece_under_cursor)
                    _cursor_root_node = weakref(piece_root_node3d)
                    _cursor_piece_container.global_transform = piece_root_node3d.global_transform
                    _cursor_piece_outline.generate_from(piece_root_node3d)
                    _cursor_piece_outline.outline_material = valid_draw_outline_material
                    _cursor_piece_outline.fill_material = valid_draw_fill_material
            else:
                _cursor_piece_outline.visible = false
                _cursor_tile_outline.visible = true
                _cursor_tile_outline.outline_material = invalid_draw_outline_material
                _cursor_tile_outline.fill_material = invalid_draw_fill_material
        return

    if mode_buttons_group.get_pressed_button() == paint_mode_button:
        _cursor_piece_container.position = Vector3.ZERO
        _cursor_piece_outline.visible = true
        _cursor_tile_outline.visible = false
        update_cursor_state_on_plane(camera, mouse_position, edit_axis, draw_offset)
        if can_paint_at_preview_position():
            _cursor_piece_outline.outline_material = valid_draw_outline_material
            _cursor_piece_outline.fill_material = valid_draw_fill_material
        else:
            _cursor_piece_outline.outline_material = invalid_draw_outline_material
            _cursor_piece_outline.fill_material = invalid_draw_fill_material
        return

    if mode_buttons_group.get_pressed_button() == attach_mode_button:
        _cursor_piece_outline.visible = true
        _cursor_tile_outline.visible = false
        _hide_all_grids()
        if input_action == InputAction.INPUT_ATTACH:
            update_cursor_state_on_plane(camera, mouse_position, edit_axis, draw_offset)
        else:
            update_cursor_state_raycast_face(camera, mouse_position, draw_offset)
        return

    if mode_buttons_group.get_pressed_button() == erase_mode_button:
        _cursor_piece_outline.visible = false
        _cursor_tile_outline.visible = true
        _cursor_tile_outline.axis = edit_axis
        update_cursor_state_on_plane(camera, mouse_position, edit_axis, draw_offset)
        var piece_under_cursor := _board.get_piece_at(_cursor_grid_position)
        if piece_under_cursor:
            var piece_root_node := _get_piece_root_in_board(piece_under_cursor)
            if piece_root_node is Board3D:
                var piece_root_board3d := piece_root_node as Node3D
                _cursor_piece_container.global_transform = piece_root_board3d.global_transform
                _cursor_piece_outline.generate_from(piece_root_board3d)
                _cursor_piece_outline.visible = true
                _cursor_tile_outline.visible = false
                _cursor_piece_outline.outline_material = invalid_draw_outline_material
                _cursor_piece_outline.fill_material = invalid_draw_fill_material
            elif piece_root_node is Node3D:
                var piece_root_node3d := piece_root_node as Node3D
                _cursor_piece = weakref(piece_under_cursor)
                _cursor_root_node = weakref(piece_root_node3d)
                _cursor_piece_container.global_transform = piece_root_node3d.global_transform
                _cursor_piece_outline.generate_from(piece_root_node3d)
                _cursor_piece_outline.visible = true
                _cursor_tile_outline.visible = false
                _cursor_piece_outline.outline_material = erase_draw_outline_material
                _cursor_piece_outline.fill_material = erase_draw_fill_material
        return

    if mode_buttons_group.get_pressed_button() == select_mode_button:
        _cursor_tile_outline.visible = false
        _hide_all_grids()
        if input_action == InputAction.INPUT_SELECT and _selection_movement_threshold_passed:
            _cursor_piece_outline.visible = false
        else:
            _cursor_piece_container.transform = Transform3D.IDENTITY
            _cursor_piece_outline.visible = true
            _cursor_piece_outline.outline_material = invalid_draw_outline_material
            _cursor_piece_outline.fill_material = invalid_draw_fill_material
            update_cursor_state_raycast_piece(camera, mouse_position)
        return

func update_cursor_state_on_plane(camera: Camera3D, mouse_position: Vector2, axis: Vector3.Axis, offset: int) -> void:
    var plane_a := _create_plane(axis, offset - 0.5)
    var plane_b := _create_plane(axis, offset + 0.5)

    var mouse_origin := camera.project_ray_origin(mouse_position)
    var mouse_normal := camera.project_ray_normal(mouse_position)

    var intersection_a: Variant = plane_a.intersects_ray(mouse_origin, mouse_normal)
    var intersection_b: Variant = plane_b.intersects_ray(mouse_origin, mouse_normal)
    var intersection_point := Vector3()

    match axis:
        Vector3.AXIS_X: _cursor_grid_direction = Vector3(1, 0, 0)
        Vector3.AXIS_Y: _cursor_grid_direction = Vector3(0, 1, 0)
        Vector3.AXIS_Z: _cursor_grid_direction = Vector3(0, 0, 1)

    if not intersection_a and not intersection_b:
        # Ray didn't intersect
        _cursor.visible = false
        return
    elif intersection_a and intersection_b:
        var ia: Vector3 = intersection_a
        var ib: Vector3 = intersection_b
        if mouse_origin.distance_squared_to(ib) > mouse_origin.distance_squared_to(ia):
            intersection_point = ib
            _cursor_grid_direction *= -1
            _cursor_tile_outline.flipped = true
        else:
            intersection_point = ia
            _cursor_tile_outline.flipped = false
    elif intersection_a:
        intersection_point = intersection_a
        _cursor_tile_outline.flipped = false
    elif intersection_b:
        intersection_point = intersection_b
        _cursor_grid_direction *= -1
        _cursor_tile_outline.flipped = true
    
    var grid_position := _get_grid_position_from_intersection(intersection_point, axis, offset)

    _cursor.visible = true
    _cursor.global_position = grid_position
    _cursor_tile_outline.position = _cursor_grid_direction * 0.0001
    _cursor_grid_position = grid_position
    _cursor_plane_position = _get_plane_position_from_intersection(intersection_point, axis, offset)

    for i in range(3):
        if i == axis:
            _grid_instances[i].visible = true
            _grid_instances[i].global_position = grid_position - _cursor_grid_direction * 0.5
        else:
            _grid_instances[i].visible = false

func update_cursor_state_raycast_face(camera: Camera3D, mouse_position: Vector2, offset: int) -> void:
    pass
    
func update_cursor_state_raycast_piece(camera: Camera3D, mouse_position: Vector2) -> void:
    var mouse_origin := camera.project_ray_origin(mouse_position)
    var mouse_normal := camera.project_ray_normal(mouse_position)

    var piece := _board.raycast_piece(mouse_origin, mouse_normal)

    if not piece:
        # Ray didn't intersect
        _cursor.visible = false
        return
    
    var piece_root_node := _get_piece_root_in_board(piece)

    if not piece_root_node or not piece_root_node is Node3D:
        _cursor.visible = false
        return
    
    var piece_root_node3d := piece_root_node as Node3D
    _cursor.visible = true
    _cursor.global_transform = piece_root_node3d.global_transform
    _cursor_piece_outline.generate_from(piece_root_node3d)
    _cursor_piece = weakref(piece)
    _cursor_root_node = weakref(piece_root_node3d)

func can_paint_at_preview_position() -> bool:
    if not _draw_preview or _draw_preview_pieces.size() == 0:
        return false
    
    for piece in _draw_preview_pieces:
        for piece_overlapping in _board.get_pieces_at(piece.grid_position):
            if piece.editor_paint_layer and piece_overlapping.editor_paint_layer and piece.editor_paint_layer & piece_overlapping.editor_paint_layer == 0:
                # Piece doesn't collide with our paint layer
                continue
            return false
    
    return true

func erase_pieces_overlapping_preview() -> bool:
    if not _draw_preview or _draw_preview_pieces.size() == 0:
        return false

    var nodes_to_erase: Array[Node3D] = []
    for piece in _draw_preview_pieces:
        for piece_overlapping in _board.get_pieces_at(piece.grid_position):
            if piece_overlapping._board != _board:
                # There's a piece we can't erase (from a nested board)
                return false
            if piece.editor_paint_layer and piece_overlapping.editor_paint_layer and piece.editor_paint_layer & piece_overlapping.editor_paint_layer == 0:
                # Piece doesn't collide with our paint layer
                continue
            var piece_root_node := _get_piece_root_in_board(piece_overlapping)
            if piece_root_node is Board3D:
                # Don't erase whole boards
                return false
            if not piece_root_node is Node3D:
                # Don't know how to erase this
                return false
            if not piece_root_node.scene_file_path.is_empty() and piece_root_node.scene_file_path == _draw_scene.resource_path and is_node_in_all_groups_to_add(piece_root_node):
                # Don't overwrite piece with same piece
                return false
            var piece_root_node3d: Node3D = piece_root_node
            if nodes_to_erase.has(piece_root_node3d):
                continue
            nodes_to_erase.append(piece_root_node3d)
    
    for node in nodes_to_erase:
        var change := AddRemoveChange.create_from(node, AddRemoveChange.Action.REMOVE)
        _paint_changes.append(change)
        node.get_parent().remove_child(node)
    
    return true

func is_node_in_all_groups_to_add(node: Node) -> bool:
    for group_checkbox in group_checkboxes:
        if not group_checkbox.button_pressed:
            continue
        if not node.is_in_group(group_checkbox.text):
            return false
    return true

func clear_draw_preview() -> void:
    if not _draw_preview:
        return
    
    _draw_preview.queue_free()
    _draw_preview = null
    _draw_preview_pieces = []

func setup_draw_preview(scene: PackedScene) -> void:
    clear_draw_preview()

    if not scene:
        return
    
    var node := scene.instantiate()
    if not node is Node3D:
        node.queue_free()
        return
    
    _draw_preview = node
    _cursor_piece_container.add_child(_draw_preview)
    _draw_preview.transform = Transform3D.IDENTITY
    _cursor_piece_outline.generate_from(_draw_preview)
    
    _draw_preview_pieces = []
    Piece3D.find_descendant_pieces(_draw_preview, _draw_preview_pieces)

func auto_setup_draw_preview() -> void:
    if _draw_scene and (mode_buttons_group.get_pressed_button() == paint_mode_button or mode_buttons_group.get_pressed_button() == attach_mode_button):
        setup_draw_preview(_draw_scene)
    else:
        clear_draw_preview()
#endregion

#region Grouping
func _auto_enable_group_buttons() -> void:
    group_button.disabled = not _can_group_selection()
    ungroup_button.disabled = not _can_ungroup_selection()

func _can_group_selection() -> bool:
    var editor_selection := EditorInterface.get_selection()
    var editor_selected_nodes := editor_selection.get_selected_nodes()

    if editor_selected_nodes.size() < 2:
        # Not enough selected to group
        return false
    
    var common_node_parent: Node = null
    for node in editor_selected_nodes:
        if not common_node_parent:
            common_node_parent = node.get_parent()
        
        if node.get_parent() != common_node_parent:
            # Selected nodes must share their parent
            return false

    return true

func _can_ungroup_selection() -> bool:
    var editor_selection := EditorInterface.get_selection()
    var editor_selected_nodes := editor_selection.get_selected_nodes()

    if editor_selected_nodes.is_empty():
        # No selection to ungroup
        return false

    for node in editor_selected_nodes:
        if not node is Board3D:
            # Non-board selected
            return false
        
        if not node.scene_file_path.is_empty():
            # Selected board has its own scene
            return false
        
        var selected_board := node as Board3D

        if not selected_board.parent_board:
            # Selected board has no parent board
            return false

    return true

func _group_selection() -> void:
    if not _can_group_selection():
        return

    # Setup undo history
    undo_redo.create_action("PuzzleKit Group", UndoRedo.MERGE_DISABLE, _board.owner, false, true)

    var editor_selection := EditorInterface.get_selection()
    var editor_selected_nodes := editor_selection.get_selected_nodes()
    editor_selected_nodes.sort_custom(func(a: Node, b: Node) -> bool: return a.get_index() < b.get_index())

    var first_node := editor_selected_nodes[0]
    var parent_node := first_node.get_parent()
    var created_board := Board3D.new()
    created_board.name = "Board3D"

    # Add created board to the selected nodes' parent
    undo_redo.add_do_method(parent_node, "add_child", created_board, true)
    undo_redo.add_do_method(parent_node, "move_child", created_board, first_node.get_index())
    undo_redo.add_do_property(created_board, "owner", parent_node.owner)
    
    for node in editor_selected_nodes:
        # Move the selected nodes into the board
        undo_redo.add_do_method(parent_node, "remove_child", node)
        undo_redo.add_do_method(created_board, "add_child", node, true)
        _add_do_set_owner_node_and_children(node)
        undo_redo.add_undo_method(created_board, "remove_child", node)
        undo_redo.add_undo_method(parent_node, "add_child", node)
        undo_redo.add_undo_method(parent_node, "move_child", node, node.get_index() + 1)
        _add_undo_set_owner_node_and_children(node)
        undo_redo.add_undo_property(node, "name", node.name)

    # When undoing, remove the created board
    undo_redo.add_undo_method(parent_node, "remove_child", created_board)
    # Commit undo history (and call the do methods)
    undo_redo.commit_action(true)

func _add_do_set_owner_node_and_children(node: Node) -> void:
    undo_redo.add_do_property(node, "owner", node.owner)
    for i in range(node.get_child_count()):
        _add_do_set_owner_node_and_children(node.get_child(i))

func _add_undo_set_owner_node_and_children(node: Node) -> void:
    undo_redo.add_undo_property(node, "owner", node.owner)
    for i in range(node.get_child_count()):
        _add_undo_set_owner_node_and_children(node.get_child(i))

func _ungroup_selection() -> void:
    if not _can_ungroup_selection():
        return

    # Setup undo history
    undo_redo.create_action("PuzzleKit Ungroup", UndoRedo.MERGE_DISABLE, _board.owner, false, true)
    
    var editor_selection := EditorInterface.get_selection()
    var editor_selected_nodes := editor_selection.get_selected_nodes()

    for node in editor_selected_nodes:
        if not node is Board3D:
            # Non-board selected
            continue
        
        if not node.scene_file_path.is_empty():
            # Selected board has its own scene
            continue
        
        var selected_board := node as Board3D

        if not selected_board.parent_board:
            # Selected board has no parent board
            continue
        
        var selected_board_node_children := selected_board.get_children()
        var selected_board_node_parent := selected_board.get_parent()
        var parent_board := selected_board.parent_board
        var previous_sibling: Node = selected_board

        # When undoing, need to add board back to scene first
        undo_redo.add_undo_method(selected_board_node_parent, "add_child", selected_board)
        undo_redo.add_undo_method(selected_board_node_parent, "move_child", selected_board, selected_board.get_index())
        undo_redo.add_undo_property(selected_board, "owner", selected_board.owner)

        for child in selected_board_node_children:
            # Move the selected board's children into the parent board
            undo_redo.add_do_method(selected_board, "remove_child", child)
            undo_redo.add_do_method(previous_sibling, "add_sibling", child, true)
            undo_redo.add_do_property(child, "owner", child.owner)
            undo_redo.add_undo_method(parent_board, "remove_child", child)
            undo_redo.add_undo_method(selected_board, "add_child", child)
            undo_redo.add_undo_property(child, "owner", child.owner)
            undo_redo.add_undo_property(child, "name", child.name)
            previous_sibling = child

        # Remove the selected board from its parent
        undo_redo.add_do_method(selected_board_node_parent, "remove_child", selected_board)
        undo_redo.add_undo_reference(selected_board)

    # Commit undo history (and call the do methods)
    undo_redo.commit_action(true)

#endregion

static func get_cells_entered(from: Vector3, to: Vector3) -> Array[Vector3i]:
    var points: Array[Vector3i] = []

    var direction := (to - from).normalized()
    var start: Vector3i = from.round()
    var end: Vector3i = to.round()
    var offset := end - start
    var p := start
    var dt := Vector3(1.0 / absf(direction.x), 1.0 / absf(direction.y), 1.0 / absf(direction.z))
    var step := Vector3i()
    var next_edge := Vector3()

    for i in range(3):
        if direction[i] == 0:
            step[i] = 0
            next_edge[i] = dt[i]
        elif direction[i] > 0:
            step[i] = 1
            next_edge[i] = (p[i] + 0.5 - from[i]) * dt[i]
        else:
            step[i] = -1
            next_edge[i] = (from[i] + 0.5 - p[i]) * dt[i]

    for i in range(absi(offset.x) + absi(offset.y) + absi(offset.z)):
        # Find the closest edge and move towards it
        if next_edge.x < next_edge.y and next_edge.x < next_edge.z:
            p.x += step.x
            next_edge.x += dt.x
        elif next_edge.y < next_edge.x and next_edge.y < next_edge.z:
            p.y += step.y
            next_edge.y += dt.y
        else:
            p.z += step.z
            next_edge.z += dt.z

        points.append(p)
    return points

static func create_tool_material(color: Color) -> BaseMaterial3D:
    var m := StandardMaterial3D.new()
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    m.vertex_color_use_as_albedo = true
    m.disable_fog = true
    m.albedo_color = color
    return m

class AddRemoveChange:
    enum Action {
        INVALID,
        ADD,
        REMOVE,
    }

    var action: Action
    var node: Node3D
    var owner: Node
    var parent: Node
    var index: int
    var global_transform: Transform3D

    static func create_from(n: Node3D, a: Action) -> AddRemoveChange:
        var change := AddRemoveChange.new()
        change.action = a
        change.node = n
        change.owner = n.owner
        change.parent = n.get_parent()
        change.index = n.get_index(false)
        change.global_transform = n.global_transform
        return change

    func register_with_undo_redo(undo_redo: EditorUndoRedoManager) -> void:
        match action:
            Action.ADD:
                undo_redo.add_do_method(self, "do_add")
                undo_redo.add_undo_method(self, "do_remove")
            Action.REMOVE:
                undo_redo.add_do_method(self, "do_remove")
                undo_redo.add_undo_method(self, "do_add")
                undo_redo.add_undo_reference(node)

    func do_add() -> void:
        parent.add_child(node, true)
        parent.move_child(node, index)
        node.owner = owner
        node.global_transform = global_transform

    func do_remove() -> void:
        parent.remove_child(node)
