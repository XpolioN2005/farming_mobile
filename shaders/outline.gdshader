shader_type canvas_item;

uniform bool outline_enabled = true; // 🔘 Outline on/off switch
uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0); // Default: white

// Blinking modulates the base color.
// Set blink_time_scale to 0 if you don't want blinking.
uniform vec4 blink_color : source_color = vec4(1.0);
uniform float blink_time_scale : hint_range(0.0, 10.0, 0.1) = 0.0;

void fragment() {
	vec2 pixel_size = TEXTURE_PIXEL_SIZE;

	// Only sample 4 directions (no diagonals)
	bool within = false;
	within = within || texture(TEXTURE, UV + pixel_size * vec2(1.0, 0.0)).a > 0.0;  // right
	within = within || texture(TEXTURE, UV + pixel_size * vec2(-1.0, 0.0)).a > 0.0; // left
	within = within || texture(TEXTURE, UV + pixel_size * vec2(0.0, 1.0)).a > 0.0;  // up
	within = within || texture(TEXTURE, UV + pixel_size * vec2(0.0, -1.0)).a > 0.0; // down

	bool outline = within && texture(TEXTURE, UV).a == 0.0;

	// Blinking effect
	COLOR = mix(COLOR, COLOR * blink_color, 0.5 - 0.5 * cos(TIME * blink_time_scale));

	// Apply outline only if enabled
	if (outline_enabled && outline) {
		COLOR = outline_color;
	}
}
