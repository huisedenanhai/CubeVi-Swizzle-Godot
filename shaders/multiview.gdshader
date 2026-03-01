shader_type canvas_item;

// MultiView Interlacing Shader
// Converts 40-camera grid texture into light field output
// Uses single atlas texture instead of multiple uniforms

uniform sampler2D _MainTex : hint_default_black;
uniform float _Slope = 0.1021;
uniform float _Interval = 19.6169;
uniform float _X0 = 3.59;
uniform float _ImgsCountX = 8.0;
uniform float _ImgsCountY = 5.0;
uniform float _ImgsCountAll = 40.0;
uniform float _OutputSizeX = 1440.0;
uniform float _OutputSizeY = 2560.0;
uniform bool _ShowAtlas = false;

// Calculate lenticular lens choice
float get_choice_float(vec2 pos, float bias) {
    float x = pos.x * _OutputSizeX + 0.5;
    // float y = (1.0 - pos.y) * _OutputSizeY + 0.5;
	// Tested on metal, no need to flip y here...
    float y = pos.y * _OutputSizeY + 0.5;
    float x1 = (x + y * _Slope) * 3.0 + bias;
    return fract((x1 + _X0) / _Interval);
}

// Map choice to viewport UV coordinates
vec2 get_uv_from_choice(vec2 pos, float choice_float) {
    float choice = floor(choice_float * _ImgsCountAll);
    
    // Calculate grid position
    float grid_x = mod(choice, _ImgsCountX);
    float grid_y = floor(choice / _ImgsCountX);
    
    // Convert to UV coordinates within the atlas
    vec2 cell_uv = pos;
    vec2 cell_size = vec2(1.0 / _ImgsCountX, 1.0 / _ImgsCountY);
    vec2 cell_offset = vec2(
        grid_x / _ImgsCountX,
        grid_y / _ImgsCountY
    );
    
    return cell_offset + cell_uv * cell_size;
}

// Get color from grid texture
vec4 get_color(vec2 uv, float bias) {
    float choice_float = get_choice_float(uv, bias);
    vec2 atlas_uv = get_uv_from_choice(uv, choice_float);
    return texture(_MainTex, atlas_uv);
}

void fragment() {
    vec2 uv = UV;
    
    if (_ShowAtlas) {
        // Debug mode: show raw atlas texture
        COLOR = texture(_MainTex, uv);
    } else {
        // Normal mode: sample RGB from adjacent views for lenticular interlacing
        COLOR = get_color(uv, 0.0);
        COLOR.g = get_color(uv, 1.0).g;
        COLOR.b = get_color(uv, 2.0).b;
    }
}
