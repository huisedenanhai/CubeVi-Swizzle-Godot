@tool
class_name BatchCameraManager
extends Node3D

## Main camera manager for CubeVi light field rendering
## Manages 40-camera array (8x5 grid), display output, and visualization
## Uses single atlas texture for efficient shader sampling

@export_group("Camera Settings")
@export var target_transform: Node3D

@export_group("Focal Settings")
@export_range(0.1, 500.0) var focal_plane: float:
	get:
		return _focal_plane

var _focal_plane: float = 10.0
var _target_offset: Vector2 = Vector2.ZERO

var device_defaults = preload("res://autoload/device_defaults.gd")

const CAMERA_NEAR = 0.1
const CAMERA_FAR = 1000.0
# Visualization disabled - use editor gizmos instead

# Device parameters
var _device: DeviceData

# Grid cameras - still need individual viewports for each camera
var _batch_cameras: Array[Camera3D] = []
var _camera_viewports: Array[SubViewport] = []

# Atlas texture - combines all 40 views into one texture
var _atlas_viewport: SubViewport
var _atlas_texture: ViewportTexture

# Display
var _quad_object: MeshInstance3D
var _display_camera: Camera3D
var _quad_material: ShaderMaterial


# Window display
var _target_screen_index: int = 0


func _ready():
	# Initialize device data (needed for both editor and runtime)
	_init_device_data()
	
	# Skip runtime initialization in editor
	if Engine.is_editor_hint():
		return
	
	# Make persistent
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Setup display (detect or use primary)
	_setup_display()
	
	# Validate required references
	if target_transform == null:
		SwizzleLogger.log_error("TargetTransform is not assigned.")
		set_process(false)
		return
	
	# Initialize components
	_init_cameras()
	_init_atlas()  # New: Create atlas texture
	_init_display_camera()
	_init_quad()
	
	SwizzleLogger.log_important("BatchCameraManager initialized with %d cameras" % _device.viewnum)


func _process(_delta):
	_update_target()
	if Engine.is_editor_hint():
		# In editor, just update gizmo when transforms change
		_update_gizmo_if_needed()
		return
	
	_update_camera_positions()


var _last_root_transform: Transform3D
var _last_target_pos: Vector3

func _update_gizmo_if_needed() -> void:
	var needs_update := false
	
	# Check if self transform changed
	if transform != _last_root_transform:
		_last_root_transform = transform
		needs_update = true
	
	# Check if target position changed
	if target_transform != null:
		if target_transform.position != _last_target_pos:
			_last_target_pos = target_transform.position
			needs_update = true
	
	if needs_update:
		# Trigger property change notification to update gizmo
		update_gizmos()


func _init_device_data():
	# Load from config or use defaults
	var params: Dictionary
	if Engine.is_editor_hint() or not is_instance_valid(DeviceConfig):
		# Use default parameters in editor or when autoload not ready
		params = device_defaults.get_defaults()
	else:
		params = DeviceConfig.device_params
	
	_device = DeviceData.new(params)


func _setup_display():
	# Detect 1440x2560 display for Companion 01
	var found_display := false
	
	for i in range(DisplayServer.get_screen_count()):
		var size := DisplayServer.screen_get_size(i)
		# Check for portrait orientation (1440x2560) or landscape (2560x1440)
		if (size.x == 1440 and size.y == 2560) or (size.x == 2560 and size.y == 1440):
			_target_screen_index = i
			found_display = true
			SwizzleLogger.log_info("Found Companion 01 display on screen %d: %dx%d" % [i, size.x, size.y])
			break
	
	if not found_display:
		SwizzleLogger.log_warning("Companion 01 display (1440x2560) not found, using primary display")
		_target_screen_index = DisplayServer.SCREEN_PRIMARY
	
	# Move window to target display
	var target_pos := DisplayServer.screen_get_position(_target_screen_index)
	DisplayServer.window_set_position(target_pos, 0)
	
	# Set window size to output resolution
	DisplayServer.window_set_size(Vector2i(int(_device.output_size_X), int(_device.output_size_Y)), 0)


func _init_cameras():
	for i in range(_device.viewnum):
		var viewport := SubViewport.new()
		viewport.name = "Viewport_%d" % i
		viewport.size = Vector2i(_device.subimg_width, _device.subimg_height)
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(viewport)
		_camera_viewports.append(viewport)
		
		var camera := Camera3D.new()
		camera.name = "BatchCamera_%d" % i
		camera.projection = Camera3D.PROJECTION_FRUSTUM
		camera.size = 2.0 * CAMERA_NEAR * tan(deg_to_rad(_device.theta / 2.0))
		camera.near = CAMERA_NEAR
		camera.far = CAMERA_FAR
		viewport.add_child(camera)
		_batch_cameras.append(camera)


func _init_atlas():
	## Create atlas viewport that combines all camera views
	## Size: 4320x4800 (540*8 x 960*5)
	
	_atlas_viewport = SubViewport.new()
	_atlas_viewport.name = "AtlasViewport"
	_atlas_viewport.size = Vector2i(
		_device.subimg_width * _device.imgs_count_x,
		_device.subimg_height * _device.imgs_count_y
	)
	_atlas_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_atlas_viewport)
	
	# Create canvas layer for atlas composition
	var canvas_layer := CanvasLayer.new()
	_atlas_viewport.add_child(canvas_layer)
	
	# Create TextureRect for each camera viewport in the atlas
	for i in range(_device.viewnum):
		var n_i: int = i
		var m: int = _device.imgs_count_y - int(float(n_i) / float(_device.imgs_count_x)) - 1
		var n: int = n_i % _device.imgs_count_x
		
		var tex_rect := TextureRect.new()
		tex_rect.name = "AtlasCell_%d" % i
		tex_rect.texture = _camera_viewports[i].get_texture()
		tex_rect.size = Vector2(_device.subimg_width, _device.subimg_height)
		tex_rect.position = Vector2(
			n * _device.subimg_width,
			m * _device.subimg_height
		)
		tex_rect.stretch_mode = TextureRect.STRETCH_SCALE
		canvas_layer.add_child(tex_rect)
	
	# Get atlas texture
	_atlas_texture = _atlas_viewport.get_texture()


func _init_display_camera():
	_display_camera = Camera3D.new()
	_display_camera.name = "DisplayCamera"
	_display_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_display_camera.size = 1.0
	_display_camera.near = CAMERA_NEAR
	_display_camera.far = 100.0
	_display_camera.position = Vector3(0, 0, 0)
	_display_camera.cull_mask = 2  # Only render layer 2 (display quad)
	add_child(_display_camera)


func _init_quad():
	# Create fullscreen quad for display output
	var quad_mesh := QuadMesh.new()
	quad_mesh.size = Vector2(1, 1)
	
	_quad_object = MeshInstance3D.new()
	_quad_object.name = "DisplayQuad"
	_quad_object.mesh = quad_mesh
	_quad_object.layers = 2  # Layer 2
	_quad_object.position = Vector3(0, 0, -1)  # In front of camera (camera looks toward -Z)
	_quad_object.rotation = Vector3(0, 0, 0)
	
	# Scale to fill orthographic view
	var aspect: float = _device.output_size_X / _device.output_size_Y
	_quad_object.scale = Vector3(aspect, 1, 1)
	
	# Create material with interlacing shader
	_quad_material = ShaderMaterial.new()
	_quad_material.shader = preload("res://shaders/multiview.gdshader")
	
	# Set shader parameters
	_quad_material.set_shader_parameter("_Slope", _device.slope)
	_quad_material.set_shader_parameter("_Interval", _device.interval)
	_quad_material.set_shader_parameter("_X0", _device.x0)
	_quad_material.set_shader_parameter("_ImgsCountX", float(_device.imgs_count_x))
	_quad_material.set_shader_parameter("_ImgsCountY", float(_device.imgs_count_y))
	_quad_material.set_shader_parameter("_ImgsCountAll", float(_device.viewnum))
	_quad_material.set_shader_parameter("_Gamma", 1.0)
	_quad_material.set_shader_parameter("_OutputSizeX", _device.output_size_X)
	_quad_material.set_shader_parameter("_OutputSizeY", _device.output_size_Y)
	
	# Set atlas texture (single texture instead of 40 uniforms!)
	_quad_material.set_shader_parameter("_MainTex", _atlas_texture)
	
	_quad_object.material_override = _quad_material
	add_child(_quad_object)


func _update_target():
	if target_transform != null:
		var target_local: Vector3 = to_local(target_transform.position)
		_focal_plane = abs(target_local.z)
		_target_offset = Vector2(target_local.x, target_local.y)


## Camera parameter calculation functions

func _get_spread_direction() -> Vector3:
	## Returns local X direction for camera spread (relative to CameraManager)
	return Vector3.RIGHT


func _get_camera_offset_x(camera_index: int, x_fov: float) -> float:
	## Calculate camera offset distance from center along local X
	var n_i: int = (camera_index + _device.viewnum * 10) % _device.viewnum
	return -(-x_fov + (n_i * 2.0 * x_fov) / (_device.viewnum - 1))


func _get_frustum_offset_meters(camera_offset_x: float, near: float) -> Vector2:
	## Calculate frustum offset in meters at near plane given camera offset
	return (Vector2(-camera_offset_x, 0) + _target_offset) * (near / _focal_plane)


func _update_camera_positions():
	var x_fov: float = _focal_plane * tan(deg_to_rad(_device.theta / 2.0))
	var near: float = CAMERA_NEAR
	var far: float = CAMERA_FAR
	var frustum_size: float = 2.0 * near * tan(deg_to_rad(_device.theta / 2.0))

	for i in range(_device.viewnum):
		var x_i: float = _get_camera_offset_x(i, x_fov)
		var local_pos := Vector3(x_i, 0, 0)
		var world_pos := to_global(local_pos)
		
		_batch_cameras[i].position = world_pos
		
		var offset_meters: Vector2 = _get_frustum_offset_meters(x_i, near)
		_batch_cameras[i].set_frustum(frustum_size, offset_meters, near, far)
		_batch_cameras[i].rotation = rotation


## Getters for editor gizmos
func get_device() -> DeviceData:
	return _device


func get_batch_cameras() -> Array[Camera3D]:
	return _batch_cameras


func get_camera_frustum_params() -> Array[Dictionary]:
	## Returns array of frustum parameters for each camera (in local space)
	## Each dict contains: position, offset, near, far, size
	var params: Array[Dictionary] = []
	
	if _device == null:
		return params
	
	var x_fov: float = _focal_plane * tan(deg_to_rad(_device.theta / 2.0))
	var near: float = CAMERA_NEAR
	var far: float = CAMERA_FAR
	var frustum_size: float = 2.0 * near * tan(deg_to_rad(_device.theta / 2.0))

	for i in range(_device.viewnum):
		var x_i: float = _get_camera_offset_x(i, x_fov)
		var offset_meters: Vector2 = _get_frustum_offset_meters(x_i, near)
		var cam_pos: Vector3 = Vector3(x_i, 0, 0)

		params.append({
			"position": cam_pos,
			"rotation": Vector3.ZERO,
			"offset": offset_meters,
			"size": frustum_size,
			"near": near,
			"far": far,
			"focal_plane": _focal_plane
		})
	
	return params


## Debug API
func set_debug_show_atlas(yes: bool) -> void:
	if _quad_material != null:
		_quad_material.set_shader_parameter("_ShowAtlas", yes)

func get_debug_info() -> Dictionary:
	return {
		"camera_count": _device.viewnum if _device != null else 0,
		"focal_plane": _focal_plane,
		"grid_size": "%dx%d" % [_device.imgs_count_x, _device.imgs_count_y] if _device != null else "0x0",
		"atlas_size": "%dx%d" % [_atlas_viewport.size.x, _atlas_viewport.size.y] if _atlas_viewport != null else "0x0"
	}
