shader_type canvas_item;

// xBR smoothing settings
uniform float smoothing_strength : hint_range(0.0, 1.0) = 0.35;
uniform bool smoothing_enabled = true;

// Style unification settings
uniform float posterize_levels : hint_range(2.0, 64.0) = 20.0;
uniform bool posterize_enabled = true;
uniform float saturation : hint_range(0.0, 2.0) = 0.85;
uniform bool saturation_enabled = true;
uniform float contrast : hint_range(0.5, 1.5) = 1.05;
uniform bool contrast_enabled = true;

// Dithering
uniform bool dithering_enabled = false;
uniform float dither_strength : hint_range(0.0, 1.0) = 0.15;

// RGB to HSV conversion
vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

// HSV to RGB conversion
vec3 hsv2rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

// Dither pattern (Bayer 4x4)
float bayer_dither(vec2 screen_pos) {
	int x = int(mod(screen_pos.x, 4.0));
	int y = int(mod(screen_pos.y, 4.0));

	int index = x + y * 4;
	float bayer[16] = float[16](
		0.0/16.0, 8.0/16.0, 2.0/16.0, 10.0/16.0,
		12.0/16.0, 4.0/16.0, 14.0/16.0, 6.0/16.0,
		3.0/16.0, 11.0/16.0, 1.0/16.0, 9.0/16.0,
		15.0/16.0, 7.0/16.0, 13.0/16.0, 5.0/16.0
	);

	return bayer[index];
}

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

	// Apply style unification only to opaque pixels
	if (final_color.a > 0.1) {
		vec3 rgb = final_color.rgb;

		// Contrast adjustment
		if (contrast_enabled) {
			rgb = (rgb - 0.5) * contrast + 0.5;
			rgb = clamp(rgb, 0.0, 1.0);
		}

		// Saturation adjustment (via HSV)
		if (saturation_enabled) {
			vec3 hsv = rgb2hsv(rgb);
			hsv.y *= saturation;  // Adjust saturation
			rgb = hsv2rgb(hsv);
		}

		// Dithering (before posterization for better results)
		if (dithering_enabled) {
			float dither = (bayer_dither(FRAGCOORD.xy) - 0.5) * dither_strength;
			rgb += vec3(dither);
			rgb = clamp(rgb, 0.0, 1.0);
		}

		// Posterization (color depth reduction)
		if (posterize_enabled) {
			rgb = floor(rgb * posterize_levels) / posterize_levels;
		}

		final_color.rgb = rgb;
	}

	COLOR = final_color;
}
