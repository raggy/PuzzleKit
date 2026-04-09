@tool
class_name PuzzleKitEditor3D
extends VBoxContainer

# Written heavily referencing the GridMap editor plugin
# With thanks to Godot contributors
# https://github.com/godotengine/godot/blob/master/modules/gridmap/editor/grid_map_editor_plugin.cpp

const SETTING_PIECE_DIRECTORY := "puzzle_kit/editor/piece_directory"

const GRID_CURSOR_SIZE := 50

@export var transform_mode_button: Button
@export var paint_mode_button: Button
@export var attach_mode_button: Button
@export var erase_mode_button: Button
@export var pick_mode_button: Button
@export var select_mode_button: Button

@export var rotate_x_button: Button
@export var rotate_y_button: Button
@export var rotate_z_button: Button

@export var viewport_shortcut_buttons: Array[BaseButton]

@export var draw_offset_spin_box: SpinBox

@export var piece_directory_input: TextEdit
@export var piece_directory_pick_button: Button
@export var piece_directory_pick_dialog: FileDialog

@export var palette: ItemList

@export var options_button: MenuButton

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
    MENU_OPTION_CURSOR_ROTATE_X,
    MENU_OPTION_CURSOR_ROTATE_Y,
    MENU_OPTION_CURSOR_ROTATE_Z,
    MENU_OPTION_CURSOR_BACK_ROTATE_X,
    MENU_OPTION_CURSOR_BACK_ROTATE_Y,
    MENU_OPTION_CURSOR_BACK_ROTATE_Z,
}

var options_axis_ids: Array[Menu] = [Menu.MENU_OPTION_X_AXIS, Menu.MENU_OPTION_Y_AXIS, Menu.MENU_OPTION_Z_AXIS]

var mode_buttons_group: ButtonGroup

var edit_axis: Vector3.Axis
var draw_offset: int
var _accumulated_draw_offset_delta: float = 0.0

var input_action: InputAction = InputAction.INPUT_NONE

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
var _cursor_root_node: WeakRef

var _paint_fresh_nodes: Array[Node3D]
var _paint_changes: Array[AddRemoveChange]
var _paint_plane_position: Vector3

var _grid: Array[ArrayMesh]
var _grid_instances: Array[MeshInstance3D]

func _enter_tree() -> void:
    if is_being_edited():
        return
    
    _update_theme()

    ProjectSettings.settings_changed.connect(_on_settings_changed)
    EditorInterface.get_selection().selection_changed.connect(_on_editor_selection_changed)

func _exit_tree() -> void:
    if is_being_edited():
        return

    ProjectSettings.settings_changed.disconnect(_on_settings_changed)
    EditorInterface.get_selection().selection_changed.disconnect(_on_editor_selection_changed)

func _ready() -> void:
    if is_being_edited():
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
        grid_instance.layers = 1 << 24
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
    piece_directory_pick_button.shortcut = EditorInterface.get_editor_settings().get_shortcut("puzzle_kit/pick_piece_directory")

    mode_buttons_group = ButtonGroup.new()
    transform_mode_button.button_group = mode_buttons_group
    paint_mode_button.button_group = mode_buttons_group
    attach_mode_button.button_group = mode_buttons_group
    erase_mode_button.button_group = mode_buttons_group
    pick_mode_button.button_group = mode_buttons_group
    select_mode_button.button_group = mode_buttons_group

    transform_mode_button.pressed.connect(_on_tool_mode_changed)
    paint_mode_button.pressed.connect(_on_tool_mode_changed)
    attach_mode_button.pressed.connect(_on_tool_mode_changed)
    erase_mode_button.pressed.connect(_on_tool_mode_changed)
    pick_mode_button.pressed.connect(_on_tool_mode_changed)
    select_mode_button.pressed.connect(_on_tool_mode_changed)

    rotate_x_button.pressed.connect(_menu_option.bind(Menu.MENU_OPTION_CURSOR_ROTATE_X))
    rotate_y_button.pressed.connect(_menu_option.bind(Menu.MENU_OPTION_CURSOR_ROTATE_Y))
    rotate_z_button.pressed.connect(_menu_option.bind(Menu.MENU_OPTION_CURSOR_ROTATE_Z))

    visibility_changed.connect(_on_visibility_changed)

    draw_offset_spin_box.value_changed.connect(_set_draw_offset)

    piece_directory_pick_button.pressed.connect(_on_piece_directory_pick_button_pressed)
    piece_directory_pick_dialog.dir_selected.connect(_on_piece_directory_pick_dialog_dir_selected)

    piece_directory_input.text = ProjectSettings.get_setting(SETTING_PIECE_DIRECTORY, "")
    
    palette.item_selected.connect(_on_palette_item_selected)

    edit_axis = Vector3.AXIS_Y
    draw_offset = 0

    options_button.get_popup().add_radio_check_shortcut(EditorInterface.get_editor_settings().get_shortcut("puzzle_kit/edit_x_axis"), Menu.MENU_OPTION_X_AXIS)
    options_button.get_popup().add_radio_check_shortcut(EditorInterface.get_editor_settings().get_shortcut("puzzle_kit/edit_y_axis"), Menu.MENU_OPTION_Y_AXIS)
    options_button.get_popup().add_radio_check_shortcut(EditorInterface.get_editor_settings().get_shortcut("puzzle_kit/edit_z_axis"), Menu.MENU_OPTION_Z_AXIS)
    options_button.get_popup().set_item_checked(options_button.get_popup().get_item_index(Menu.MENU_OPTION_Y_AXIS), true);
    options_button.get_popup().id_pressed.connect(_menu_option)

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

func _process(_delta: float) -> void:
    if is_being_edited():
        return
    
    var viewport := EditorInterface.get_editor_viewport_3d()

    update_cursor_state(viewport.get_camera_3d(), viewport.get_mouse_position())

func _notification(what: int) -> void:
    if is_being_edited():
        return
    
    match what:
        NOTIFICATION_THEME_CHANGED:
            _update_theme()

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
    piece_directory_pick_button.icon = editor_theme.get_icon("Folder", "EditorIcons")
    options_button.icon = editor_theme.get_icon("Tools", "EditorIcons")

func is_being_edited() -> bool:
    return get_parent() is SubViewport

func edit(board: Board3D) -> void:
    _board = board

    if _board:
        if not mode_buttons_group.get_pressed_button():
            select_mode_button.button_pressed = true
        _on_tool_mode_changed()
        set_process(true)
        _set_interactable(true)
        palette.visible = true
        info_no_board.visible = false
    else:
        set_process(false)
        _set_interactable(false)
        transform_mode_button.disabled = true
        palette.visible = false
        info_no_board.visible = true
        _cursor_piece_outline.visible = false
        _cursor_tile_outline.visible = false
        _hide_all_grids()

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
    if is_being_edited():
        return

    if is_visible_in_tree():
        _update_palette()

func _on_settings_changed() -> void:
    if is_being_edited():
        return

    piece_directory_input.text = ProjectSettings.get_setting(SETTING_PIECE_DIRECTORY, "")
    if is_visible_in_tree():
        _update_palette()

func _on_editor_selection_changed() -> void:
    edit(_get_board_to_edit_from_selection())

func _get_board_to_edit_from_selection() -> Board3D:
    var editor_selection := EditorInterface.get_selection()
    var selected_nodes := editor_selection.get_selected_nodes()

    if selected_nodes.is_empty():
        var edited_scene_root := EditorInterface.get_edited_scene_root()
        # Allow editing where scene root is a Board3D
        return edited_scene_root if edited_scene_root is Board3D else null
    
    var board: Board3D = null
    
    for selected_node in selected_nodes:
        var selected_node_board: Board3D = selected_node if selected_node is Board3D else _find_nearest_ancestor_board(selected_node)
        # This selected node is not a descendant of a board
        if not selected_node_board:
            return null
        if board == null:
            # This is the first board we've found, save it to return later
            board = selected_node_board
        elif selected_node_board.is_ancestor_of(board):
            # This is an ancestor of previously-found board, use this instead
            board = selected_node_board
        elif board != selected_node_board and not board.is_ancestor_of(selected_node_board):
            # Multiple boards selected that aren't nested, invalid
            return null

    return board

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
    #_show_viewports_transform_gizmo(mode_buttons_group.get_pressed_button() == transform_mode_button)
    auto_setup_draw_preview()
    # Hide by default
    _cursor_piece_outline.visible = false
    _cursor_tile_outline.visible = false
    _hide_all_grids()

func _set_draw_offset(value: float) -> void:
    draw_offset = roundi(value)

func _menu_option(id: Menu) -> void:
    match id:
        Menu.MENU_OPTION_X_AXIS, Menu.MENU_OPTION_Y_AXIS, Menu.MENU_OPTION_Z_AXIS:
            for axis_id in options_axis_ids:
                var index := options_button.get_popup().get_item_index(axis_id)
                options_button.get_popup().set_item_checked(index, axis_id == id)
                edit_axis = (id - Menu.MENU_OPTION_X_AXIS) as Vector3.Axis
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

func _on_palette_item_selected(_index: int) -> void:
    _draw_scene = _load_selected_scene()
    auto_setup_draw_preview()

func _update_palette() -> void:
    palette.clear()
    _palette_index_to_path.clear()

    _add_palette_item("", null, null, "[None]")

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

func _load_selected_scene() -> PackedScene:
    if not palette.is_anything_selected():
        return null
    
    for index in palette.get_selected_items():
        var path := _palette_index_to_path[index]
        var scene := load(path)

        if scene:
            return scene
        
    return null

#endregion

#region Input
func forward_spatial_input_event(viewport_camera: Camera3D, event: InputEvent) -> int:
    # If the mouse is currently captured, we are most likely in freelook mode.
    # In this case, disable shortcuts to avoid conflicts with freelook navigation.
    if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
        return EditorPlugin.AFTER_GUI_INPUT_PASS

    if event is InputEventKey:
        var k := event as InputEventKey
        if k.is_pressed() and not k.is_echo():
            # Transform mode (toggle button):
            # If we are in Transform mode we pass the events to the 3D editor,
            # but if the Transform mode shortcut is pressed again, we go back to Selection mode.
            if mode_buttons_group.get_pressed_button() == transform_mode_button:
                if transform_mode_button.shortcut.has_valid_event() and transform_mode_button.shortcut.matches_event(event):
                    select_mode_button.set_pressed(true)
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
        if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.is_command_or_control_pressed():
            if mb.is_pressed():
                draw_offset_spin_box.value += mb.factor
            return EditorPlugin.AFTER_GUI_INPUT_STOP
        if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.is_command_or_control_pressed():
            if mb.is_pressed():
                draw_offset_spin_box.value -= mb.factor
            return EditorPlugin.AFTER_GUI_INPUT_STOP
        
        if mb.is_pressed():
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
            elif mb.button_index == MOUSE_BUTTON_RIGHT:
                if input_action == InputAction.INPUT_NONE:
                    # TODO Pick
                    pass
            else:
                return EditorPlugin.AFTER_GUI_INPUT_PASS
            
            if do_input_action(viewport_camera, mb.position, true):
                return EditorPlugin.AFTER_GUI_INPUT_STOP
            return EditorPlugin.AFTER_GUI_INPUT_PASS
        else:
            if mb.button_index == MOUSE_BUTTON_LEFT:
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
                input_action = InputAction.INPUT_NONE

    if event is InputEventMouseMotion:
        var mm := event as InputEventMouseMotion

        if do_input_action(viewport_camera, mm.position, false):
            return EditorPlugin.AFTER_GUI_INPUT_STOP
        return EditorPlugin.AFTER_GUI_INPUT_PASS

    if event is InputEventPanGesture:
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
            _paint_fresh_nodes = []
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
            if not can_paint_at_preview_position():
                continue
            var node := _draw_scene.instantiate()
            var node3d := node as Node3D
            if not node3d:
                node.queue_free()
                return true
            _paint_fresh_nodes.append(node3d)
            _board.add_child(node3d, true)
            node3d.global_transform = _cursor_piece_container.global_transform
            node3d.owner = _board.owner
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
            var piece_under_cursor := _board.get_piece_at(erase_position)
            if not piece_under_cursor:
                # Nothing to erase here
                continue
            var piece_root_node := _get_node_root_in_ancestor(piece_under_cursor, _board)
            if piece_root_node is Node3D:
                var piece_root_node3d := piece_root_node as Node3D
                var change := AddRemoveChange.create_from(piece_root_node3d, AddRemoveChange.Action.REMOVE)
                _paint_changes.append(change)
                piece_root_node3d.get_parent().remove_child(piece_root_node3d)
        return true
    if input_action == InputAction.INPUT_PICK:
        update_cursor_state(camera, mouse_position)
        var pick_node: Variant = _cursor_root_node.get_ref() if _cursor_root_node else null
        if pick_node is Node3D:
            var node3d: Node3D = pick_node
            for index: int in _palette_index_to_path.keys():
                var path := _palette_index_to_path[index]
                if path == node3d.scene_file_path:
                    palette.select(index, true)
                    _on_palette_item_selected(index)
                    break
        return true
    return false

func _get_node_root_in_ancestor(node: Node, ancestor: Node) -> Node:
    if not node:
        return null

    if not node.owner:
        # Node is temporary
        return null
    
    if node.owner == ancestor.owner:
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
    _cursor_root_node = null

    if mode_buttons_group.get_pressed_button() == paint_mode_button:
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
            var piece_root_node := _get_node_root_in_ancestor(piece_under_cursor, _board)
            if piece_root_node is Node3D:
                var piece_root_node3d := piece_root_node as Node3D
                _cursor_root_node = weakref(piece_root_node3d)
                _cursor.global_transform = piece_root_node3d.global_transform
                _cursor_piece_outline.generate_from(piece_root_node3d)
                _cursor_piece_outline.visible = true
                _cursor_tile_outline.visible = false
                _cursor_piece_outline.outline_material = erase_draw_outline_material
                _cursor_piece_outline.fill_material = erase_draw_fill_material
        return

    if mode_buttons_group.get_pressed_button() == pick_mode_button or mode_buttons_group.get_pressed_button() == select_mode_button:
        _cursor_piece_outline.visible = true
        _cursor_tile_outline.visible = false
        _hide_all_grids()
        if input_action == InputAction.INPUT_PICK:
            _cursor_piece_outline.outline_material = valid_draw_outline_material
            _cursor_piece_outline.fill_material = valid_draw_fill_material
        else:
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
    
    var piece_root_node := _get_node_root_in_ancestor(piece, _board)

    if not piece_root_node or not piece_root_node is Node3D:
        _cursor.visible = false
        return
    
    var piece_root_node3d := piece_root_node as Node3D
    _cursor.visible = true
    _cursor.global_transform = piece_root_node3d.global_transform
    _cursor_piece_outline.generate_from(piece_root_node3d)
    _cursor_root_node = weakref(piece_root_node3d)

func can_paint_at_preview_position() -> bool:
    if not _draw_preview or _draw_preview_pieces.size() == 0:
        return false
    
    for piece in _draw_preview_pieces:
        if _board.get_piece_at(piece.grid_position):
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
