@tool
class_name PuzzleKitEditor3D
extends VBoxContainer

const SETTING_PIECE_DIRECTORY := "puzzle_kit/editor/piece_directory"

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

var input_action: InputAction = InputAction.INPUT_NONE

var undo_redo: EditorUndoRedoManager

var _palette_index_to_path: Dictionary[int, String] = {}
var _draw_preview: Node3D
var _draw_scene: PackedScene

var _board: Board3D

var _cursor: Node3D

var _debug_material: StandardMaterial3D
var _debug_mesh: PiecePreviewMesh
var _debug_mesh_instance: MeshInstance3D

func _enter_tree() -> void:
    if is_being_edited():
        return
    
    _update_theme()

    ProjectSettings.settings_changed.connect(_on_settings_changed)

func _exit_tree() -> void:
    if is_being_edited():
        return

    ProjectSettings.settings_changed.disconnect(_on_settings_changed)

func _ready() -> void:
    if is_being_edited():
        return

    _cursor = Node3D.new()
    add_child(_cursor)

    _debug_material = StandardMaterial3D.new()
    _debug_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    _debug_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    _debug_material.vertex_color_is_srgb = true
    # _debug_material.vertex_color_use_as_albedo = true
    _debug_material.disable_fog = true
    _debug_material.albedo_color = Color.WHITE

    _debug_mesh = PiecePreviewMesh.new()
    _debug_mesh_instance = MeshInstance3D.new()
    _debug_mesh_instance.mesh = _debug_mesh
    _cursor.add_child(_debug_mesh_instance)

    _add_shortcuts_to_editor_settings()

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
    paint_mode_button.button_group = mode_buttons_group
    attach_mode_button.button_group = mode_buttons_group
    erase_mode_button.button_group = mode_buttons_group
    pick_mode_button.button_group = mode_buttons_group
    select_mode_button.button_group = mode_buttons_group

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

func _add_shortcuts_to_editor_settings() -> void:
    # Toolbar
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
    var viewport := EditorInterface.get_editor_viewport_3d()
    var camera := viewport.get_camera_3d()
    var mouse_position := viewport.get_mouse_position()

    update_cursor_position(camera.project_ray_origin(mouse_position), camera.project_ray_normal(mouse_position))

func _notification(what: int) -> void:
    if is_being_edited():
        return
    
    match what:
        NOTIFICATION_THEME_CHANGED:
            _update_theme()

func _update_theme() -> void:
    var editor_theme := EditorInterface.get_editor_theme()

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

func _on_tool_mode_changed() -> void:
    #_show_viewports_transform_gizmo(mode_buttons_group.get_pressed_button() == transform_mode_button)
    auto_setup_draw_preview()

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
            _cursor.rotate(rotation_axis, -PI / 2.0)

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
            # Tool modes and tool actions:
            for button in viewport_shortcut_buttons:
                if button.disabled:
                    continue
                if button.shortcut and button.shortcut.has_valid_event() and button.shortcut.matches_event(event):
                    if button.toggle_mode:
                        button.button_pressed = button.button_group or not button.pressed
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
            else:
                return EditorPlugin.AFTER_GUI_INPUT_PASS
            
            if do_input_action(viewport_camera, mb.position, true):
                return EditorPlugin.AFTER_GUI_INPUT_STOP
            return EditorPlugin.AFTER_GUI_INPUT_PASS
        else:
            if input_action == InputAction.INPUT_PAINT:
                undo_redo.create_action("Board3D Paint")
                # TODO Undo/redo for paint
                undo_redo.commit_action()
            input_action = InputAction.INPUT_NONE

    if event is InputEventMouseMotion:
        var mm := event as InputEventMouseMotion
        # preview_raycast(viewport_camera.project_ray_origin(mm.position), viewport_camera.project_ray_normal(mm.position))
        preview_grid_position_along_plane(viewport_camera.project_ray_origin(mm.position), viewport_camera.project_ray_normal(mm.position), edit_axis, draw_offset)
        
        if do_input_action(viewport_camera, mm.position, false):
            return EditorPlugin.AFTER_GUI_INPUT_STOP
        return EditorPlugin.AFTER_GUI_INPUT_PASS

    return EditorPlugin.AFTER_GUI_INPUT_PASS

func do_input_action(camera: Camera3D, position: Vector2, click: bool) -> bool:
    if input_action == InputAction.INPUT_PAINT:
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

func _create_plane_aabb(axis: Vector3.Axis, plane_offset: float) -> AABB:
    match axis:
        Vector3.AXIS_X: return AABB(Vector3(plane_offset - 0.5, -500000, -500000), Vector3(1.0, 1000000, 1000000))
        Vector3.AXIS_Y: return AABB(Vector3(-500000, plane_offset - 0.5, -500000), Vector3(1000000, 1.0, 1000000))
        Vector3.AXIS_Z: return AABB(Vector3(-500000, -500000, plane_offset - 0.5), Vector3(1000000, 1000000, 1.0))

    return AABB()

func _create_plane(axis: Vector3.Axis, plane_offset: float) -> Plane:
    match axis:
        Vector3.AXIS_X: return Plane(Vector3.RIGHT, plane_offset)
        Vector3.AXIS_Y: return Plane(Vector3.UP, plane_offset)
        Vector3.AXIS_Z: return Plane(Vector3.BACK, plane_offset)

    return Plane()

func _get_grid_position_from_intersection(intersection_point: Vector3, axis: Vector3.Axis, plane_offset: float) -> Vector3:
    match axis:
        Vector3.AXIS_X: return Vector3(plane_offset, roundf(intersection_point.y), roundf(intersection_point.z))
        Vector3.AXIS_Y: return Vector3(roundf(intersection_point.x), plane_offset, roundf(intersection_point.z))
        Vector3.AXIS_Z: return Vector3(roundf(intersection_point.x), roundf(intersection_point.y), plane_offset)
    
    return Vector3()

func update_cursor_position(from: Vector3, direction: Vector3) -> void:
    var axis := edit_axis
    var plane_offset := draw_offset

    var plane_a := _create_plane(axis, plane_offset - 0.5)
    var plane_b := _create_plane(axis, plane_offset + 0.5)

    var intersection_a: Variant = plane_a.intersects_ray(from, direction)
    var intersection_b: Variant = plane_b.intersects_ray(from, direction)
    var intersection_point := Vector3()

    if not intersection_a and not intersection_b:
        # Ray didn't intersect
        _cursor.visible = false
        return
    elif intersection_a and intersection_b:
        var ia: Vector3 = intersection_a
        var ib: Vector3 = intersection_b
        if from.distance_squared_to(ib) > from.distance_squared_to(ia):
            intersection_point = ib
        else:
            intersection_point = ia
    elif intersection_a:
        intersection_point = intersection_a
    elif intersection_b:
        intersection_point = intersection_b
    
    var grid_position := _get_grid_position_from_intersection(intersection_point, axis, plane_offset)

    _cursor.visible = true
    _cursor.global_position = grid_position

func preview_grid_position_along_plane(from: Vector3, direction: Vector3, axis: Vector3.Axis, plane_offset: float) -> void:
    _debug_mesh.clear_surfaces()

    var plane_a := _create_plane(axis, plane_offset - 0.5)
    var plane_b := _create_plane(axis, plane_offset + 0.5)

    var intersection_a: Variant = plane_a.intersects_ray(from, direction)
    var intersection_b: Variant = plane_b.intersects_ray(from, direction)
    var intersection_point := Vector3()

    if not intersection_a and not intersection_b:
        # Ray didn't intersect
        return
    elif intersection_a and intersection_b:
        var ia: Vector3 = intersection_a
        var ib: Vector3 = intersection_b
        if from.distance_squared_to(ib) > from.distance_squared_to(ia):
            intersection_point = ib
        else:
            intersection_point = ia
    elif intersection_a:
        intersection_point = intersection_a
    elif intersection_b:
        intersection_point = intersection_b
    
    var grid_position := _get_grid_position_from_intersection(intersection_point, axis, plane_offset)

    var surface_array := []
    surface_array.resize(Mesh.ARRAY_MAX)

    var verts := PackedVector3Array()
    var indices := PackedInt32Array()

    add_cube(grid_position, verts, indices)

    surface_array[Mesh.ARRAY_VERTEX] = verts
    surface_array[Mesh.ARRAY_INDEX] = indices

    _debug_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, surface_array)
    _debug_mesh.surface_set_material(0, _debug_material)

func preview_grid_position_along_plane_aabb(from: Vector3, direction: Vector3, axis: Vector3.Axis, plane_offset: float) -> void:
    _debug_mesh.clear_surfaces()

    var aabb := _create_plane_aabb(axis, plane_offset)

    var aabb_intersection: Variant = aabb.intersects_ray(from, direction)
    if not aabb_intersection:
        # Ray didn't intersect aabb
        return
    
    var intersection_point: Vector3 = aabb_intersection
    var grid_position := _get_grid_position_from_intersection(intersection_point, axis, plane_offset)

    var surface_array := []
    surface_array.resize(Mesh.ARRAY_MAX)

    var verts := PackedVector3Array()
    var indices := PackedInt32Array()

    add_cube(grid_position, verts, indices)

    surface_array[Mesh.ARRAY_VERTEX] = verts
    surface_array[Mesh.ARRAY_INDEX] = indices

    _debug_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, surface_array)
    _debug_mesh.surface_set_material(0, _debug_material)

func preview_raycast(from: Vector3, direction: Vector3) -> void:
    _debug_mesh.clear_surfaces()

    var points := _board.raycast_points(from, direction)

    if points.is_empty():
        return

    var surface_array := []
    surface_array.resize(Mesh.ARRAY_MAX)

    var verts := PackedVector3Array()
    var indices := PackedInt32Array()

    for point in points:
        add_cube(point, verts, indices)

    surface_array[Mesh.ARRAY_VERTEX] = verts
    surface_array[Mesh.ARRAY_INDEX] = indices

    _debug_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, surface_array)
    _debug_mesh.surface_set_material(0, _debug_material)

func add_cube(center: Vector3, verts: PackedVector3Array, indices: PackedInt32Array) -> void:
    var offset := verts.size()

    verts.append(center + Vector3( 0.5,  0.5,  0.5)) # 0 Right, top, back
    verts.append(center + Vector3(-0.5,  0.5,  0.5)) # 1 Left, top, back
    verts.append(center + Vector3( 0.5, -0.5,  0.5)) # 2 Right, bottom, back
    verts.append(center + Vector3(-0.5, -0.5,  0.5)) # 3 Left, bottom, back
    verts.append(center + Vector3( 0.5,  0.5, -0.5)) # 4 Right, top, front
    verts.append(center + Vector3(-0.5,  0.5, -0.5)) # 5 Left, top, front
    verts.append(center + Vector3( 0.5, -0.5, -0.5)) # 6 Right, bottom, front
    verts.append(center + Vector3(-0.5, -0.5, -0.5)) # 7 Left, bottom, front

    indices.append(offset +  0)
    indices.append(offset +  1)
    indices.append(offset +  2)
    indices.append(offset +  3)
    indices.append(offset +  4)
    indices.append(offset +  5)
    indices.append(offset +  6)
    indices.append(offset +  7)

    indices.append(offset +  0)
    indices.append(offset +  2)
    indices.append(offset +  1)
    indices.append(offset +  3)
    indices.append(offset +  4)
    indices.append(offset +  6)
    indices.append(offset +  5)
    indices.append(offset +  7)

    indices.append(offset +  0)
    indices.append(offset +  4)
    indices.append(offset +  1)
    indices.append(offset +  5)
    indices.append(offset +  2)
    indices.append(offset +  6)
    indices.append(offset +  3)
    indices.append(offset +  7)

func clear_draw_preview() -> void:
    if not _draw_preview:
        return
    
    _draw_preview.queue_free()
    _draw_preview = null

func setup_draw_preview(scene: PackedScene) -> void:
    clear_draw_preview()

    if not scene:
        return
    
    var node := scene.instantiate()
    if not node is Node3D:
        node.queue_free()
        return
    
    _draw_preview = node
    _cursor.add_child(_draw_preview)
    _draw_preview.transform = Transform3D.IDENTITY
    _debug_mesh.generate_from(_draw_preview)

func auto_setup_draw_preview() -> void:
    if _draw_scene and mode_buttons_group.get_pressed_button() == paint_mode_button or mode_buttons_group.get_pressed_button() == attach_mode_button:
        setup_draw_preview(_draw_scene)
    else:
        clear_draw_preview()
#endregion
