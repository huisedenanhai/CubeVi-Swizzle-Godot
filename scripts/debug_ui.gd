extends CanvasLayer

## Debug UI for CubeVi Swizzle
## Shows debug info and allows toggling between interleaved/atlas views
## Only visible in debug builds

@onready var panel: PanelContainer = $Panel
@onready var toggle_button: CheckButton = $Panel/MarginContainer/VBoxContainer/ToggleButton
@onready var info_label: Label = $Panel/MarginContainer/VBoxContainer/InfoLabel
@onready var fps_label: Label = $Panel/MarginContainer/VBoxContainer/FPSLabel

var camera_manager: BatchCameraManager
var show_atlas: bool = false


func _ready():
	# Only show in debug builds
	if not OS.is_debug_build():
		hide()
		return
	
	# Find camera manager
	camera_manager = _find_camera_manager()
	if camera_manager == null:
		push_warning("DebugUI: Could not find BatchCameraManager")
		return
	
	# Connect toggle button
	toggle_button.toggled.connect(_on_toggle_changed)
	
	# Set initial state
	_update_display()


func _find_camera_manager() -> BatchCameraManager:
	# Try to find in scene
	var managers = get_tree().get_nodes_in_group("camera_manager")
	if managers.size() > 0:
		return managers[0] as BatchCameraManager
	
	# Search recursively
	return _find_in_node(get_tree().root)


func _find_in_node(node: Node) -> BatchCameraManager:
	if node is BatchCameraManager:
		return node
	
	for child in node.get_children():
		var result = _find_in_node(child)
		if result != null:
			return result
	
	return null


func _on_toggle_changed(toggled: bool) -> void:
	show_atlas = toggled
	if camera_manager != null:
		camera_manager.set_debug_show_atlas(show_atlas)
	_update_display()


func _process(_delta: float) -> void:
	if not OS.is_debug_build() or camera_manager == null:
		return
	
	_update_display()


func _update_display() -> void:
	if camera_manager == null:
		return
	
	var info = camera_manager.get_debug_info()
	var mode_text = "Atlas" if show_atlas else "Interleaved"
	
	info_label.text = """Mode: %s
Cameras: %d
Grid: %s
Focal: %.2f
Atlas: %s""" % [
		mode_text,
		info.camera_count,
		info.grid_size,
		info.focal_plane,
		info.atlas_size
	]
	
	fps_label.text = "FPS: %d" % Engine.get_frames_per_second()
	
	toggle_button.text = "Show Atlas" if not show_atlas else "Show Interleaved"


func _input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	
	# Toggle with F1 key
	if event is InputEventKey and event.pressed and event.keycode == KEY_F1:
		toggle_button.button_pressed = not toggle_button.button_pressed
		_on_toggle_changed(toggle_button.button_pressed)
