shader_type canvas_item;

// Outline settings
uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float outline_width : hint_range(0.0, 10.0) = 1.0;
uniform bool outline_enabled = true;

// xBR smoothing settings
uniform float smoothing_strength : hint_range(0.0, 1.0) = 0.35;
uniform bool smoothing_enabled = true;

void fragment() {
	vec2 pixel_size = TEXTURE_PIXEL_SIZE;
	vec4 color = texture(TEXTURE, UV);
	vec4 final_color = color;

	// xBR-style smoothing (only on opaque pixels)
	if (smoothing_enabled && color.a > 0.1) {
		// Sample neighbors
		vec4 left = texture(TEXTURE, UV + vec2(-pixel_size.x, 0.0));
		vec4 right = texture(TEXTURE, UV + vec2(pixel_size.x, 0.0));
		vec4 up = texture(TEXTURE, UV + vec2(0.0, -pixel_size.y));
		vec4 down = texture(TEXTURE, UV + vec2(0.0, pixel_size.y));

		// Edge detection
		float diff_h = length(left.rgb - right.rgb);
		float diff_v = length(up.rgb - down.rgb);

		// Only smooth non-edge areas
		if (diff_h < 0.5 && diff_v < 0.5) {
			vec4 avg = (left + right + up + down + color * 2.0) / 6.0;
			color = mix(color, avg, smoothing_strength);
			final_color = color;
		}
	}

	// Outline layer (around sprite)
	if (outline_enabled && color.a < 0.1) {
		float outline = 0.0;
		vec2 outline_size = pixel_size * outline_width;

		// 8-direction sampling for outline detection
		outline += texture(TEXTURE, UV + vec2(-outline_size.x, 0.0)).a;
		outline += texture(TEXTURE, UV + vec2(outline_size.x, 0.0)).a;
		outline += texture(TEXTURE, UV + vec2(0.0, -outline_size.y)).a;
		outline += texture(TEXTURE, UV + vec2(0.0, outline_size.y)).a;
		outline += texture(TEXTURE, UV + vec2(-outline_size.x, -outline_size.y)).a;
		outline += texture(TEXTURE, UV + vec2(outline_size.x, -outline_size.y)).a;
		outline += texture(TEXTURE, UV + vec2(-outline_size.x, outline_size.y)).a;
		outline += texture(TEXTURE, UV + vec2(outline_size.x, outline_size.y)).a;

		// If surrounded by opaque pixels, draw outline
		if (outline > 0.0) {
			final_color = outline_color;
		}
	}

	COLOR = final_color;
}
