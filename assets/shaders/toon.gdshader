shader_type canvas_item;

// --- Krawędzie ---
uniform float edge_thickness : hint_range(0.0, 5.0) = 1.0;
uniform vec4 edge_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float edge_strength : hint_range(0.0, 1.0) = 0.8;

// --- Spłaszczenie kolorów (toon) ---
uniform float color_steps : hint_range(1.0, 16.0) = 4.0;
uniform float color_effect : hint_range(0.0, 1.0) = 0.0;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

void fragment() {
	vec2 pixel = SCREEN_PIXEL_SIZE * edge_thickness;

	// Pobierz sąsiednie piksele (Sobel 3x3)
	vec4 c  = texture(screen_texture, SCREEN_UV);
	vec4 tl = texture(screen_texture, SCREEN_UV + vec2(-pixel.x,  pixel.y));
	vec4 tc = texture(screen_texture, SCREEN_UV + vec2( 0.0,      pixel.y));
	vec4 tr = texture(screen_texture, SCREEN_UV + vec2( pixel.x,  pixel.y));
	vec4 ml = texture(screen_texture, SCREEN_UV + vec2(-pixel.x,  0.0));
	vec4 mr = texture(screen_texture, SCREEN_UV + vec2( pixel.x,  0.0));
	vec4 bl = texture(screen_texture, SCREEN_UV + vec2(-pixel.x, -pixel.y));
	vec4 bc = texture(screen_texture, SCREEN_UV + vec2( 0.0,     -pixel.y));
	vec4 br = texture(screen_texture, SCREEN_UV + vec2( pixel.x, -pixel.y));

	// Sobel — wykrywanie krawędzi po luminancji
	float lum_tl = dot(tl.rgb, vec3(0.299, 0.587, 0.114));
	float lum_tc = dot(tc.rgb, vec3(0.299, 0.587, 0.114));
	float lum_tr = dot(tr.rgb, vec3(0.299, 0.587, 0.114));
	float lum_ml = dot(ml.rgb, vec3(0.299, 0.587, 0.114));
	float lum_mr = dot(mr.rgb, vec3(0.299, 0.587, 0.114));
	float lum_bl = dot(bl.rgb, vec3(0.299, 0.587, 0.114));
	float lum_bc = dot(bc.rgb, vec3(0.299, 0.587, 0.114));
	float lum_br = dot(br.rgb, vec3(0.299, 0.587, 0.114));

	float gx = -lum_tl - 2.0*lum_ml - lum_bl + lum_tr + 2.0*lum_mr + lum_br;
	float gy = -lum_tl - 2.0*lum_tc - lum_tr + lum_bl + 2.0*lum_bc + lum_br;
	float edge = clamp(sqrt(gx*gx + gy*gy), 0.0, 1.0);

	// Spłaszczenie kolorów
	vec4 toon_color = c;
	if (color_effect > 0.0) {
		vec3 quantized = floor(c.rgb * color_steps + 0.5) / color_steps;
		toon_color.rgb = mix(c.rgb, quantized, color_effect);
	}

	// Nałóż krawędzie
	float edge_alpha = edge * edge_strength * edge_color.a;
	COLOR = mix(toon_color, vec4(edge_color.rgb, toon_color.a), edge_alpha);
}
