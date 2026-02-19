extends Node

## Default device parameters shared across the project
## Avoids duplication between runtime and editor code

const DEFAULT_PARAMS := {
	"name": "5.7",
	"imgs_count_x": 8,
	"imgs_count_y": 5,
	"viewnum": 40,
	"theta": 40.0,
	"output_size_X": 1440.0,
	"output_size_Y": 2560.0,
	"subimg_width": 540,
	"subimg_height": 960,
	"f_cam": 3806.0,
	"tan_alpha_2": 0.071,
	"x0": 3.59,
	"interval": 19.6169,
	"slope": 0.1021,
	"nearrate": 0.96,
	"farrate": 1.08
}


static func get_defaults() -> Dictionary:
	return DEFAULT_PARAMS.duplicate()
