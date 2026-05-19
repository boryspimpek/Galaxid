shader_type canvas_item;

// Kontrola nad efektem z poziomu inspektora Godota
uniform float czestotliwosc_mrugania : hint_range(0.1, 10.0) = 2.0;
uniform float minimalna_jasnosc : hint_range(0.0, 1.0) = 0.2;
uniform float maksymalna_jasnosc : hint_range(1.0, 5.0) = 2.5; // Powyżej 1.0 dla efektu Glow

// Prosta funkcja generująca pseudolosową wartość na podstawie pozycji piksela
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void fragment() {
    // Pobieramy oryginalny kolor piksela z naszego tła
    vec4 kolor_tekstury = texture(TEXTURE, UV);
    
    // Obliczamy jasność piksela (luminancję)
    float jasnosc = (kolor_tekstury.r + kolor_tekstury.g + kolor_tekstury.b) / 3.0;
    
    // Jeśli piksel nie jest czarny (czyli jest częścią gwiazdy)
    if (jasnosc > 0.05) {
        // Generujemy unikalne przesunięcie fazowe dla tej konkretnej gwiazdy
        float losowa_wartosc = hash(UV);
        
        // Używamy funkcji sin, aby uzyskać płynną falę mrugania (wartość od -1 do 1)
        // Dodajemy losową wartość, aby gwiazdy nie mrugały synchronicznie
        float fala = sin(TIME * czestotliwosc_mrugania + losowa_wartosc * 6.28318);
        
        // Mapujemy falę (-1 do 1) na zakres od minimalnej do maksymalnej jasności
        float modyfikator = mix(minimalna_jasnosc, maksymalna_jasnosc, (fala + 1.0) / 2.0);
        
        // Nakładamy modyfikator na kolor gwiazdy (modyfikujemy tylko RGB, zostawiając Alfa)
        kolor_tekstury.rgb *= modyfikator;
    }
    
    // Zwracamy ostateczny kolor piksela
    COLOR = kolor_tekstury;
}