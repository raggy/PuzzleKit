extends Node

const PalettePreview := preload("res://addons/puzzle_kit/3d/editor/palette_preview.gd")

const SETTING_PALETTE_PREVIEW_CAMERA_DIRECTION := "puzzle_kit/editor/palette_preview_camera_direction"
const SETTING_PALETTE_PREVIEW_CAMERA_UP_DIRECTION := "puzzle_kit/editor/palette_preview_camera_up_direction"

const PALETTE_PREVIEW_DIRECTORY := "res://.godot/puzzle_kit/palette_previews"

const DEFAULT_CAMERA_DIRECTION := Vector3(0.333333, -0.666667, -0.666667)
const DEFAULT_CAMERA_UP_DIRECTION := Vector3.UP

const PREVIEW_SIZE := 64

func _ready() -> void:
    if not ProjectSettings.has_setting(SETTING_PALETTE_PREVIEW_CAMERA_DIRECTION):
        ProjectSettings.set_setting(SETTING_PALETTE_PREVIEW_CAMERA_DIRECTION, DEFAULT_CAMERA_DIRECTION)
        ProjectSettings.set_initial_value(SETTING_PALETTE_PREVIEW_CAMERA_DIRECTION, DEFAULT_CAMERA_DIRECTION)
        ProjectSettings.add_property_info({
            "name": SETTING_PALETTE_PREVIEW_CAMERA_DIRECTION,
            "type": TYPE_VECTOR3,
        })
    if not ProjectSettings.has_setting(SETTING_PALETTE_PREVIEW_CAMERA_UP_DIRECTION):
        ProjectSettings.set_setting(SETTING_PALETTE_PREVIEW_CAMERA_UP_DIRECTION, DEFAULT_CAMERA_UP_DIRECTION)
        ProjectSettings.set_initial_value(SETTING_PALETTE_PREVIEW_CAMERA_UP_DIRECTION, DEFAULT_CAMERA_UP_DIRECTION)
        ProjectSettings.add_property_info({
            "name": SETTING_PALETTE_PREVIEW_CAMERA_UP_DIRECTION,
            "type": TYPE_VECTOR3,
        })

func generate_from_path(path: String) -> PalettePreview:
    var uid_path := ResourceUID.path_to_uid(path)
    if uid_path == path:
        # Unknown path
        printerr("Could not find UID for path: %s" % path)
        return null
    
    if not uid_path.begins_with("uid:/"):
        printerr("Invalid UID: %s" % uid_path)
    
    var uid := uid_path.substr("uid:/".length())

    var scene_modified_time := FileAccess.get_modified_time(path)
    var preview_path := _get_preview_file_path_from_uid(uid)
    var camera_direction: Vector3 = ProjectSettings.get_setting(SETTING_PALETTE_PREVIEW_CAMERA_DIRECTION, DEFAULT_CAMERA_DIRECTION)
    var camera_up_direction: Vector3 = ProjectSettings.get_setting(SETTING_PALETTE_PREVIEW_CAMERA_UP_DIRECTION, DEFAULT_CAMERA_UP_DIRECTION)

    if FileAccess.file_exists(preview_path):
        var existing_preview := load(preview_path) as PalettePreview
        if existing_preview:
            if existing_preview.scene_modified_time == scene_modified_time and \
            existing_preview.camera_direction == camera_direction and \
            existing_preview.camera_up_direction == camera_up_direction:
                # Found an existing, valid preview
                return existing_preview

    var scene := load(path) as PackedScene
    if not scene:
        printerr("Could not load scene at path: %s" % path)
        return null

    var scenario := RenderingServer.scenario_create()
    
    var subviewport := SubViewport.new()
    subviewport.size = Vector2i(PREVIEW_SIZE, PREVIEW_SIZE)
    subviewport.transparent_bg = true
    subviewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
    add_child(subviewport)
    RenderingServer.viewport_set_scenario(subviewport.get_viewport_rid(), scenario)

    var camera := Camera3D.new()
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.near = 0.5
    camera.far = 1000
    camera.size = 1
    camera.basis = Basis.looking_at(camera_direction, camera_up_direction)
    subviewport.add_child(camera)

    var light := DirectionalLight3D.new()
    light.rotation = camera.rotation
    subviewport.add_child(light)
    _set_scenario(light, scenario)

    var node := scene.instantiate()
    subviewport.add_child(node)
    _set_scenario(node, scenario)

    var node_aabb := _calculate_aabb(node)
    camera.position = node_aabb.get_center() + camera.basis.z * 500
    var size := _calculate_size_from_aabb(camera, node_aabb)
    
    if size > 0.0:
        camera.size = size / float(PREVIEW_SIZE)

    subviewport.render_target_update_mode = SubViewport.UPDATE_ONCE
    await RenderingServer.frame_post_draw

    if not DirAccess.dir_exists_absolute(PALETTE_PREVIEW_DIRECTORY):
        DirAccess.make_dir_recursive_absolute(PALETTE_PREVIEW_DIRECTORY)

    var preview := PalettePreview.new()
    preview.camera_direction = camera_direction
    preview.camera_up_direction = camera_up_direction
    preview.scene_uid = uid_path
    preview.scene_modified_time = scene_modified_time
    preview.texture = ImageTexture.create_from_image(subviewport.get_texture().get_image())

    ResourceSaver.save(preview, preview_path)

    subviewport.free()
    RenderingServer.free_rid(scenario)

    return preview

func _get_preview_file_path_from_uid(uid: String) -> String:
    return PALETTE_PREVIEW_DIRECTORY.path_join("%s.res" % uid)

func _set_scenario(node: Node, scenario: RID) -> void:
    if node is VisualInstance3D:
        var vi3d := node as VisualInstance3D
        RenderingServer.instance_set_scenario(vi3d.get_instance(), scenario)

    for i in range(node.get_child_count()):
        _set_scenario(node.get_child(i), scenario)

func _calculate_aabb(node: Node) -> AABB:
    var aabb := AABB()

    if node is VisualInstance3D and not node is Light3D:
        var visual_instance := node as VisualInstance3D
        var node_aabb := visual_instance.global_transform * visual_instance.get_aabb()
        if not aabb.has_surface():
            aabb = node_aabb
        else:
            aabb = aabb.merge(node_aabb)
    
    for i in range(node.get_child_count()):
        var child_aabb := _calculate_aabb(node.get_child(i))

        if not aabb.has_surface():
            aabb = child_aabb
        else:
            aabb = aabb.merge(child_aabb)

    return aabb

func _calculate_size_from_aabb(camera: Camera3D, aabb: AABB) -> float:
    var screen_endpoints: Array[Vector2] = []
    for i in range(8):
        screen_endpoints.append(camera.unproject_position(aabb.get_endpoint(i)))
    var max_distance := 0.0
    for i in range(8):
        var endpoint_i := screen_endpoints[i]
        for j in range(i + 1, 8):
            var endpoint_j := screen_endpoints[j]
            var distance_x := absf(endpoint_i.x - endpoint_j.x)
            if distance_x > max_distance:
                max_distance = distance_x
            var distance_y := absf(endpoint_i.y - endpoint_j.y)
            if distance_y > max_distance:
                max_distance = distance_y
    return max_distance
