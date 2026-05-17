shader_type spatial;

// --- TWOJE TEKSTURY I KOLORY ---
uniform vec4 albedo_color : source_color = vec4(1.0, 1.0, 1.0, 1.0); // DODANE: Jednolity kolor
uniform sampler2D albedo_texture : source_color, hint_default_white; // MODYFIKACJA: Dodany hint_default_white
uniform vec4 line_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

// --- PRZYWRÓCONE OPCJE ---
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.5;
uniform float specular : hint_range(0.0, 1.0) = 0.5;

// --- TOON SETTINGS ---
uniform float shadow_threshold : hint_range(0.0, 1.0) = 0.5;
uniform float shadow_softness : hint_range(0.0, 1.0) = 0.02;

void fragment() {
	vec4 tex = texture(albedo_texture, UV);
	
	// MODYFIKACJA: Mnożenie jednolitego koloru przez teksturę
	ALBEDO = albedo_color.rgb * tex.rgb;
	
	// Przypisujemy wartości do silnika Godota
	METALLIC = metallic;
	ROUGHNESS = roughness;
	SPECULAR = specular;
}

void light() {
	// --- 1. OSTRY CIEŃ (TOON DIFFUSE) ---
	float diffuse = dot(NORMAL, LIGHT);
	float toon_diffuse = smoothstep(shadow_threshold - shadow_softness, shadow_threshold + shadow_softness, diffuse);
	vec3 diffuse_color = mix(line_color.rgb, LIGHT_COLOR, toon_diffuse);
	
	// --- 2. OSTRY ODBLASK (TOON SPECULAR) ---
	// Obliczamy wektor odbicia światła
	vec3 half_vector = normalize(VIEW + LIGHT);
	float spec_dot = dot(NORMAL, half_vector);
	
	// Tworzymy ostry blik słońca zależny od Roughness
	// Im mniejszy Roughness, tym mniejsza i ostrzejsza plamka
	float spec_intensity = pow(spec_dot, 1.0 / max(roughness, 0.01) * 100.0);
	float toon_specular = smoothstep(0.5 - shadow_softness, 0.5 + shadow_softness, spec_intensity);
	
	// --- 3. FINALNE ŁĄCZENIE ---
	// Dodajemy kolor rozproszony (planeta) i blik (słońce)
	DIFFUSE_LIGHT += diffuse_color * ATTENUATION;
	SPECULAR_LIGHT += toon_specular * specular * LIGHT_COLOR * ATTENUATION;
}