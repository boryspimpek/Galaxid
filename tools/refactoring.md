Przeczytałem CLAUDE.md, cały projekt i `tools/refactoring.odt`. Poniżej mój plan — podzielony na fazy według stosunku zysku do ryzyka. Każdy punkt to oddzielna, bezpieczna zmiana.

---

## Plan refaktoryzacji Galaxid

### Faza 1 — Naprawy bugów i niskokosztowe poprawki Godot-owe
*Można robić w dowolnej kolejności, każda jest izolowana.*

**1.1 `VisibleOnScreenNotifier2D` zamiast ręcznych granic**
- Gdzie: `Enemy.gd:221`, `projectile.gd`, `EnemyProjectile.gd` — każdy sprawdza `BOUNDS_*` co klatkę
- Co: dodać `VisibleOnScreenNotifier2D` jako dziecko sceny, podłączyć sygnał `screen_exited → queue_free()`
- Zysk: zero kodu w `_process`, zero zależności od `GameConstants.BOUNDS_*`, renderer sam to obsługuje
- Ryzyko: minimalne — sygnał działa tak samo jak ręczne sprawdzenie

**1.2 Cache gracza w `Enemy._ready()` zamiast `get_first_node_in_group` w pętli**
- Gdzie: `Enemy.gd:152` — wywoływane przy każdym strzale celującego wroga
- Co: `var _player: Node2D` ustawiany raz w `_ready()`
- Zysk: eliminacja przeszukiwania całego drzewa sceny przy każdym strzale

**1.3 `fmod` w `TileLayer` może zwracać wartość ujemną**
- Gdzie: `TileLayer.gd:45`
- Co: `_scroll_y = fmod(_scroll_y + total_h, total_h)` zamiast dwulinijkowej korekty
- Zysk: jeden wiersz, poprawna semantyka

**1.4 `max_polyphony` w `SoundManager` zamiast dwóch kanałów**
- Gdzie: `SoundManager.gd` — dwa `AudioStreamPlayer` = obcinanie dźwięków przy nakładaniu
- Co: jeden `AudioStreamPlayer` z `max_polyphony = 8` w inspektorze, usunąć `_weapon_player`/`_impact_player`
- Zysk: natywna funkcja Godota, brak obcinania dźwięku, mniej kodu

**1.5 `print()` → `push_warning()` / `push_error()`**
- Gdzie: `player.gd`, `DataManager.gd`, `LevelManager.gd`
- Co: zamienić informacyjne printy na push_warning, błędy na push_error
- Zysk: widoczne w Debuggerze z call stackiem, nie zaśmiecają Output

**1.6 Cache broni w `Enemy._ready()` zamiast `DataManager.get_weapon_by_id` przy każdym strzale**
- Gdzie: `Enemy.gd:119`, `_fire_projectile()`
- Co: `var _weapon_cache: Array = [null, null, null]` wypełniany raz w `_ready()`
- Zysk: O(1) zamiast O(n) przy każdym strzale

---

### Faza 2 — Wykorzystanie wbudowanych funkcji Godota
*Większa wartość, ale wymaga testowania po każdej zmianie.*

**2.1 `AnimatedSprite2D` + `SpriteFrames` zamiast ręcznej animacji w `Explosion.gd`**
- Gdzie: `Explosion.gd` i `RepExplosion.gd` — ładują tablicę PNG, podmieniana klatkę przez `_process`, ręczny licznik
- Co: w scenie `.tscn` utworzyć `AnimatedSprite2D` z zasobem `SpriteFrames`, podłączyć `animation_finished → queue_free()`
- Zysk: zero kodu w `_process`, zero ręcznego licznika klatek, renderer batchuje sprite'y tego samego atlasu
- Uwaga: 14 typów eksplozji — najlepiej zacząć od jednego, sprawdzić, potem pozostałe

**2.2 `CharacterBody2D.velocity` + `move_and_slide()` w graczu**
- Gdzie: `player.gd:17` — własne `velocity_x`, `velocity_y` + ręczne `position.x += velocity_x`
- Co: przenieść na wbudowany `velocity: Vector2`, na końcu `move_and_slide()`
- Zysk: automatyczna obsługa kolizji ze ścianami, jeden wektor zamiast dwóch zmiennych, semantycznie poprawniejsze użycie `CharacterBody2D`
- Uwaga: fizyka Tyrian jest celowo bez delta — `move_and_slide()` i tak można wywoływać bez `_delta`, fizyka zostaje frame-based

**2.3 Refaktoryzacja `player.gd` — ekstrakcja obsługi inputu**
- Gdzie: `player.gd:76–146` — ~70 linii mieszające mouse/keyboard bez separacji
- Co: metoda `_get_input_velocity() -> Vector2` zwracająca gotową prędkość, `move_toward()` zamiast ręcznego `if/elif` na każdej osi
- Zysk: ~50 linii → ~25, łatwiejsze tunowanie parametrów fizyki
- Potencjalny bug do naprawienia przy okazji: `player.gd:136` — oś Y przy `input_down` używa `FRICTION` zamiast `ACCEL` (oś X ma `ACCEL` w analogicznym miejscu)

**2.4 `CPUParticles2D` dla pola gwiezdnego — opcjonalnie**
- Gdzie: `Starfield.gd` — 100 gwiazd, pozycja kodowana jako `y * SCREEN_W + x`, symulacja `uint16` przez `& 0xFFFF`
- Co: `CPUParticles2D` z właściwym materiałem, zero kodu, konfiguracja w edytorze
- Zysk: czytelność; bez kodu źródłowego efekt wizualny jest identyczny
- Uwaga: jeśli starfield ma specyficzne właściwości Tyriana (np. dokładne rozmieszczenie gwiazd z save'a), zachować `Starfield.gd`

---

### Faza 3 — Rozbicie monolitów
*Każda zmiana powinna iść w osobnym PR/commicie z testem "czy gra działa".*

**3.1 `Enemy.gd` (284 linie, 7 odpowiedzialności) → osobne komponenty**
- Podział:
  - `EnemyMovement.gd` — `xmove`, `ymove`, `velocity`, scroll_y
  - `EnemyWeaponSystem.gd` — `tur[]`, `freq[]`, `eshotwait[]`, `_fire_projectile()`
  - `EnemyDeathHandler.gd` — `take_damage()`, `die()`, eksplozje
  - `EnemyPathFollower.gd` — śledzenie `Path2D`, `PathFollow2D`
  - `Enemy.gd` jako orkiestrator `@onready`-ów
- Kolejność: najpierw wydzielić `EnemyWeaponSystem` (najczystsze granice), potem resztę
- Zysk: każdy podsystem testowalny osobno, wielokrotnego użytku (np. bossowie z silniejszą bronią)

**3.2 Naprawa `EventProcessor.fast_forward_to()` — potencjalny błąd z wieloma zdarzeniami scroll_speed**
- Gdzie: `EventProcessor.gd:43–97`
- Problem: obliczanie przesunięcia tła zakłada stałą prędkość scrolla na całym segmencie; jeśli między `dist=0` a `dist=1500` jest zdarzenie zmieniające `back_move` na `dist=1000`, segment 1000–1500 jest liczony ze starą prędkością
- Co: iterować przez zdarzenia segment po segmencie, akumulując `back_move` po każdym zdarzeniu kontekstowym
- Ryzyko: subtelne — dotyczy tylko trybu "graj od pozycji X", nie rozgrywki

---

### Faza 4 — Architektura danych (długoterminowo)
*Duże zmiany, dużo pracy — warto tylko jeśli projekt będzie rósł.*

**4.1 `Resource` zamiast `Dictionary` z JSON**
- Gdzie: `DataManager.gd` — wszystkie dane gry jako `Dictionary` z `dict.get("damage", 0)` wszędzie
- Co: `class_name WeaponData extends Resource` z `@export var damage: int`, edycja w inspektorze, pełne type-safety
- Zysk: autocompletion w edytorze, brak literówek w kluczach słownika, walidacja w compile-time
- Uwaga: wymaga migracji JSON → `.tres` lub parsera JSON → Resource; spora inwestycja

**4.2 Tekstury w `.tscn` zamiast `texture_filter` ustawianego w kodzie**
- Gdzie: `Enemy.gd:80` — `visual.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS`
- Co: ustawić `Texture Filter` w inspektorze `Sprite2D` sceny `.tscn`, usunąć z kodu
- Zysk: jedna konfiguracja w jednym miejscu, nie trzeba o niej pamiętać w kodzie

---

### Sugerowana kolejność wprowadzania zmian

| Kolejność | Zmiana | Zysk | Ryzyko |
|-----------|--------|------|--------|
| 1 | Cache gracza w Enemy (`1.2`) | duży | brak |
| 2 | Cache broni w Enemy (`1.6`) | duży | brak |
| 3 | `max_polyphony` w SoundManager (`1.4`) | średni | brak |
| 4 | `fmod` fix w TileLayer (`1.3`) | mały | brak |
| 5 | `print` → `push_warning` (`1.5`) | mały | brak |
| 6 | `VisibleOnScreenNotifier2D` (`1.1`) | duży | niski |
| 7 | `AnimatedSprite2D` dla eksplozji (`2.1`) | duży | niski |
| 8 | Input/fizyka gracza (`2.3` + `2.2`) | duży | średni |
| 9 | Naprawa bugów z potencjalnym błędem osi Y (`2.3`) | mały | niski |
| 10 | Rozbicie `Enemy.gd` — `EnemyWeaponSystem` (`3.1`) | duży | średni |
| 11 | Rozbicie `Enemy.gd` — reszta (`3.1`) | duży | średni |
| 12 | `fast_forward_to` fix (`3.2`) | mały | niski |
| 13 | `Resource` zamiast `Dictionary` (`4.1`) | duży | wysoki |

---

Które zmiany chcesz zacząć wprowadzać pierwsze? Mogę też od razu zabrać się za konkretny punkt.