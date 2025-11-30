shader_type canvas_item;

// Simplified xBR-inspired upscaling shader
// Smooths edges while preserving pixel art characteristics

uniform sampler2D TEXTURE : hint_default_white, filter_linear;
uniform float edge_strength : hint_range(0.0, 1.0) = 0.5;

void fragment() {
	vec2 pixel_size = TEXTURE_PIXEL_SIZE;
	vec4 color = texture(TEXTURE, UV);

	// Sample neighboring pixels
	vec4 left = texture(TEXTURE, UV + vec2(-pixel_size.x, 0.0));
	vec4 right = texture(TEXTURE, UV + vec2(pixel_size.x, 0.0));
	vec4 up = texture(TEXTURE, UV + vec2(0.0, -pixel_size.y));
	vec4 down = texture(TEXTURE, UV + vec2(0.0, pixel_size.y));

	// Detect edges by comparing colors
	float diff_h = length(left.rgb - right.rgb);
	float diff_v = length(up.rgb - down.rgb);

	// If not on an edge, apply slight smoothing
	if (diff_h < edge_strength && diff_v < edge_strength) {
		// Bilinear-like interpolation for smooth areas
		vec4 avg = (left + right + up + down + color * 2.0) / 6.0;
		color = mix(color, avg, 0.3);
	}

	COLOR = color;
}
