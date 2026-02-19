@tool
extends EditorNode3DGizmoPlugin

## Gizmo plugin for BatchCameraManager visualization
## Draws camera frustums using manager-calculated parameters

const FRUSTUM_COLOR := Color.YELLOW
const FOCAL_PLANE_COLOR := Color(1, 0.2, 0.2, 0.8)
const TARGET_COLOR := Color(0.2, 1.0, 0.2, 0.8)

func _init():
	create_material("frustum", FRUSTUM_COLOR)
	create_material("focal_plane", FOCAL_PLANE_COLOR)
	create_material("target", TARGET_COLOR)


func _get_gizmo_name() -> String:
	return "BatchCameraManager"


func _has_gizmo(node: Node3D) -> bool:
	return node is BatchCameraManager


func _redraw(gizmo: EditorNode3DGizmo) -> void:
	gizmo.clear()
	
	var manager: BatchCameraManager = gizmo.get_node_3d()
	if not is_instance_valid(manager):
		return
	
	if manager.root == null:
		return
	
	var root: Node3D = manager.root
	var target_transform: Node3D = manager.target_transform
	var focal_plane: float = manager.focal_plane
	
	# Get camera array orientation
	var cam_forward: Vector3 = -root.basis.z
	var cam_right: Vector3 = root.basis.x
	var cam_up: Vector3 = root.basis.y
	
	# Calculate view direction
	var view_dir: Vector3
	if target_transform != null:
		view_dir = (target_transform.position - root.position).normalized()
	else:
		view_dir = cam_forward
	
	# Draw all camera frustums using manager parameters
	var all_frustum_lines := _build_frustums_from_params(manager, cam_right, cam_up, view_dir)
	gizmo.add_lines(all_frustum_lines, get_material("frustum", gizmo), false)
	
	# Draw focal plane
	var focal_pos: Vector3
	if target_transform != null:
		focal_pos = target_transform.position
	else:
		focal_pos = root.position + cam_forward * focal_plane
	
	var device: DeviceData = manager.get_device()
	if device != null:
		var aspect: float = device.output_size_X / device.output_size_Y
		_draw_focal_plane(gizmo, focal_pos, cam_right, cam_up, focal_plane, aspect, device.theta)
	
	# Draw line from root center to focal plane center
	var center_line := PackedVector3Array()
	center_line.push_back(root.position)
	center_line.push_back(focal_pos)
	gizmo.add_lines(center_line, get_material("focal_plane", gizmo), false)
	
	# Draw target point marker if using target
	if target_transform != null:
		_draw_target_marker(gizmo, target_transform.position)


func _build_frustums_from_params(
	manager: BatchCameraManager,
	cam_right: Vector3,
	cam_up: Vector3,
	view_dir: Vector3
) -> PackedVector3Array:
	var all_lines := PackedVector3Array()
	var params: Array[Dictionary] = manager.get_camera_frustum_params()
	
	for cam_data in params:
		var frustum_lines := _build_single_frustum(cam_data, cam_right, cam_up, view_dir)
		all_lines.append_array(frustum_lines)
	
	return all_lines


func _build_single_frustum(
	cam_data: Dictionary,
	cam_right: Vector3,
	cam_up: Vector3,
	view_dir: Vector3
) -> PackedVector3Array:
	var cam_pos: Vector3 = cam_data["position"]
	var cam_rot: Vector3 = cam_data["rotation"]
	var offset: Vector2 = cam_data["offset"]
	var size: float = cam_data["size"]
	var focal_plane: float = cam_data.get("focal_plane", 10.0)
	var near: float = cam_data["near"]
	var far: float = cam_data["far"]
	
	# Build rotation basis
	var rot_basis := Basis.from_euler(cam_rot)
	var forward: Vector3 = -rot_basis.z
	var right: Vector3 = rot_basis.x
	var up: Vector3 = rot_basis.y
	
	# Frustum half-width at near plane (before offset)
	var half_width: float = size / 2.0
	var aspect: float = 9.0 / 16.0  # Portrait aspect from subimg dimensions
	var half_height: float = half_width / aspect
	
	# Near plane bounds with offset applied
	var left: float = -half_width + offset.x
	var right_bound: float = half_width + offset.x
	var bottom: float = -half_height + offset.y
	var top: float = half_height + offset.y
	
	# Scale for far plane
	var far_scale: float = far / near
	
	# Near plane corners in world space
	var ntl: Vector3 = cam_pos + forward * near + right * left + up * top
	var ntr: Vector3 = cam_pos + forward * near + right * right_bound + up * top
	var nbl: Vector3 = cam_pos + forward * near + right * left + up * bottom
	var nbr: Vector3 = cam_pos + forward * near + right * right_bound + up * bottom
	
	# Far plane corners in world space
	var ftl: Vector3 = cam_pos + forward * far + right * (left * far_scale) + up * (top * far_scale)
	var ftr: Vector3 = cam_pos + forward * far + right * (right_bound * far_scale) + up * (top * far_scale)
	var fbl: Vector3 = cam_pos + forward * far + right * (left * far_scale) + up * (bottom * far_scale)
	var fbr: Vector3 = cam_pos + forward * far + right * (right_bound * far_scale) + up * (bottom * far_scale)
	
	var lines := PackedVector3Array()
	
	# Near plane
	lines.push_back(ntl); lines.push_back(ntr)
	lines.push_back(ntr); lines.push_back(nbr)
	lines.push_back(nbr); lines.push_back(nbl)
	lines.push_back(nbl); lines.push_back(ntl)
	
	# Far plane
	lines.push_back(ftl); lines.push_back(ftr)
	lines.push_back(ftr); lines.push_back(fbr)
	lines.push_back(fbr); lines.push_back(fbl)
	lines.push_back(fbl); lines.push_back(ftl)
	
	# Connecting lines
	lines.push_back(ntl); lines.push_back(ftl)
	lines.push_back(ntr); lines.push_back(ftr)
	lines.push_back(nbl); lines.push_back(fbl)
	lines.push_back(nbr); lines.push_back(fbr)
	
	return lines


func _draw_focal_plane(
	gizmo: EditorNode3DGizmo,
	focal_pos: Vector3,
	cam_right: Vector3,
	cam_up: Vector3,
	focal_plane: float,
	aspect: float,
	fov: float
) -> void:
	var focal_width: float = focal_plane * tan(deg_to_rad(fov / 2.0)) * 2.0
	var focal_height: float = focal_width / aspect
	
	var fp_tl: Vector3 = focal_pos - cam_right * focal_width / 2.0 + cam_up * focal_height / 2.0
	var fp_tr: Vector3 = focal_pos + cam_right * focal_width / 2.0 + cam_up * focal_height / 2.0
	var fp_bl: Vector3 = focal_pos - cam_right * focal_width / 2.0 - cam_up * focal_height / 2.0
	var fp_br: Vector3 = focal_pos + cam_right * focal_width / 2.0 - cam_up * focal_height / 2.0
	
	var lines := PackedVector3Array()
	lines.push_back(fp_tl); lines.push_back(fp_tr)
	lines.push_back(fp_tr); lines.push_back(fp_br)
	lines.push_back(fp_br); lines.push_back(fp_bl)
	lines.push_back(fp_bl); lines.push_back(fp_tl)
	
	gizmo.add_lines(lines, get_material("focal_plane", gizmo), false)


func _draw_target_marker(gizmo: EditorNode3DGizmo, pos: Vector3) -> void:
	var size: float = 0.5
	var lines := PackedVector3Array()
	
	lines.push_back(pos + Vector3(-size, 0, 0)); lines.push_back(pos + Vector3(size, 0, 0))
	lines.push_back(pos + Vector3(0, -size, 0)); lines.push_back(pos + Vector3(0, size, 0))
	lines.push_back(pos + Vector3(0, 0, -size)); lines.push_back(pos + Vector3(0, 0, size))
	
	gizmo.add_lines(lines, get_material("target", gizmo), false)


func _is_selectable_when_hidden() -> bool:
	return true
