class_name DeviceData
extends RefCounted

## Data container for device parameters
## Mirrors the Unity DeviceData class

var name: String = "5.7"
var imgs_count_x: int = 8
var imgs_count_y: int = 5
var viewnum: int = 40
var theta: float = 40.0
var output_size_X: float = 1440.0
var output_size_Y: float = 2560.0
var subimg_width: int = 540
var subimg_height: int = 960
var f_cam: float = 3806.0
var tan_alpha_2: float = 0.071
var x0: float = 3.59
var interval: float = 19.6169
var slope: float = 0.1021
var nearrate: float = 0.96
var farrate: float = 1.08


func _init(params: Dictionary = {}):
	if not params.is_empty():
		from_dictionary(params)


func from_dictionary(params: Dictionary) -> void:
	name = params.get("name", name)
	imgs_count_x = params.get("imgs_count_x", imgs_count_x)
	imgs_count_y = params.get("imgs_count_y", imgs_count_y)
	viewnum = params.get("viewnum", viewnum)
	theta = params.get("theta", theta)
	output_size_X = params.get("output_size_X", output_size_X)
	output_size_Y = params.get("output_size_Y", output_size_Y)
	subimg_width = params.get("subimg_width", subimg_width)
	subimg_height = params.get("subimg_height", subimg_height)
	f_cam = params.get("f_cam", f_cam)
	tan_alpha_2 = params.get("tan_alpha_2", tan_alpha_2)
	x0 = params.get("x0", x0)
	interval = params.get("interval", interval)
	slope = params.get("slope", slope)
	nearrate = params.get("nearrate", nearrate)
	farrate = params.get("farrate", farrate)


func to_dictionary() -> Dictionary:
	return {
		"name": name,
		"imgs_count_x": imgs_count_x,
		"imgs_count_y": imgs_count_y,
		"viewnum": viewnum,
		"theta": theta,
		"output_size_X": output_size_X,
		"output_size_Y": output_size_Y,
		"subimg_width": subimg_width,
		"subimg_height": subimg_height,
		"f_cam": f_cam,
		"tan_alpha_2": tan_alpha_2,
		"x0": x0,
		"interval": interval,
		"slope": slope,
		"nearrate": nearrate,
		"farrate": farrate
	}


## Calculate grid texture dimensions
func get_grid_texture_size() -> Vector2i:
	return Vector2i(
		subimg_width * imgs_count_x,
		subimg_height * imgs_count_y
	)


## Calculate aspect ratio
func get_aspect_ratio() -> float:
	return output_size_X / output_size_Y


## Get camera FOV from physical parameters
func get_fov_degrees() -> float:
	# Convert from tan_alpha_2 to degrees
	return rad_to_deg(2.0 * atan(tan_alpha_2))
