@tool
extends EditorPlugin

## CubeVi Swizzle Editor Plugin
## Provides gizmos for visualizing camera frustum and focal plane in the editor

const BatchCameraGizmoPlugin = preload("res://addons/cube_vi_swizzle_editor/batch_camera_gizmo_plugin.gd")
var gizmo_plugin = BatchCameraGizmoPlugin.new()

func _enter_tree():
	add_node_3d_gizmo_plugin(gizmo_plugin)


func _exit_tree():
	remove_node_3d_gizmo_plugin(gizmo_plugin)
