shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float outline_width : hint_range(0.0, 10.0) = 2.0;

void fragment() {
	vec2 pixel = TEXTURE_PIXEL_SIZE * outline_width;

	float alpha = texture(TEXTURE, UV).a;

	// Sprawdź sąsiadów — jeśli któryś ma alpha > 0, a obecny piksel jest przezroczysty → kontur
	float n  = texture(TEXTURE, UV + vec2( 0.0,      pixel.y)).a;
	float s  = texture(TEXTURE, UV + vec2( 0.0,     -pixel.y)).a;
	float e  = texture(TEXTURE, UV + vec2( pixel.x,  0.0)).a;
	float w  = texture(TEXTURE, UV + vec2(-pixel.x,  0.0)).a;
	float ne = texture(TEXTURE, UV + vec2( pixel.x,  pixel.y)).a;
	float nw = texture(TEXTURE, UV + vec2(-pixel.x,  pixel.y)).a;
	float se = texture(TEXTURE, UV + vec2( pixel.x, -pixel.y)).a;
	float sw = texture(TEXTURE, UV + vec2(-pixel.x, -pixel.y)).a;

	float outline = max(max(max(n, s), max(e, w)), max(max(ne, nw), max(se, sw)));

	vec4 base = texture(TEXTURE, UV);
	COLOR = mix(base, vec4(outline_color.rgb, outline_color.a * outline), (1.0 - alpha) * outline);
}
