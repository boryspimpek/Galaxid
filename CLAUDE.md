# GALAXID — DOKUMENTACJA PROJEKTU

## Ogólny opis
Galaxid to remake "Tyrian 2000" (1995) w Godot 4.6. Gra to pionowy shoot-'em-up (viewport 360×200, skalowany do 1440×800, max_fps=30). Logika ruchu, broni i wrogów bazuje na jednostkach Tyrian (px/klatkę).

---

## STRUKTURA KATALOGÓW

```
Galaxid/
├── project.godot                    (Godot 4.6, max_fps=30, viewport 360×200)
├── UI/
│   ├── Hud.gd / Hud.tscn           (paski power/shield/armor, wybór broni)
├── scenes/
│   ├── world/
│   │   ├── World.tscn               (główna scena: Player + LevelMap + HUD)
│   │   ├── LevelManager.gd          (skrypt LevelMap: scroll + routing pocisków)
│   │   └── LevelRuler.gd            (@tool wizualna linijka czasowa w edytorze)
│   ├── player/
│   │   ├── Player.tscn / player.gd  (CharacterBody2D, SPEED_CAP=4, friction=2)
│   │   ├── DamageSystem.gd/.tscn    (shield absorbuje pierwszy, potem armor)
│   │   ├── ShieldSystem.gd/.tscn    (regen co 15 klatek, kosztuje power)
│   │   └── WeaponSystem.gd/.tscn    (konfiguracja z DataManager, shoot())
│   ├── enemy/
│   │   ├── Enemy.tscn               (baza: Area2D + Visual + CollisionShape2D + VisibleOnScreenNotifier2D)
│   │   └── Enemy.gd                 (fizyka, strzelanie, ścieżki, śmierć)
│   ├── enemies/
│   │   ├── Enemy_001.tscn … Enemy_999.tscn  (350+ gotowych wrogów)
│   │   └── PathConfig.gd            (@tool na Path2D: speed, speed_curve, scroll_speed, auto_advance)
│   ├── projectile/
│   │   ├── Projectile.tscn / projectile.gd  (pocisk gracza: velocity, circlesize, lifetime)
│   ├── enemy_projectile/
│   │   ├── EnemyProjectile.tscn / EnemyProjectile.gd  (pocisk wroga: homing, acceleration, duration)
│   ├── explosions/
│   │   ├── Explosion.tscn / Explosion.gd       (14 typów, 3-12 klatek)
│   │   └── RepExplosion.tscn / RepExplosion.gd  (wybuchy cykliczne, burst co 3-4 klatki)
│   └── background/                  (NIEUŻYWANE — zachowane na dysku)
│       ├── Background.tscn, TileBackground.gd, TileLayer.gd, Starfield.gd
├── scripts/
│   ├── core/
│   │   ├── DataManager.gd           (Autoload: ładuje JSON, cache broni/statków/wrogów)
│   │   ├── GameConstants.gd         (Autoload: preload 4 scen — pociski + eksplozje)
│   │   └── PlayerSetup.gd           (Autoload: stan ekwipunku gracza)
│   └── managers/
│       ├── SoundManager.gd          (Autoload: kanały audio)
│       ├── EnemySpawner.gd          (NIEUŻYWANY — stary system eventowy)
│       ├── EnemyController.gd       (NIEUŻYWANY — stary system eventowy)
│       └── EventProcessor.gd        (NIEUŻYWANY — stary system eventowy)
├── demo/                            (demo 3D Terrain3D — niezależne od gry)
├── addons/terrain_3d/, level_editor/
└── data/
    ├── ships.json, enemies.json, weapon.json, shields.json, generators.json
    ├── lvl01.json … lvl99.json      (NIEUŻYWANE — stary system eventowy)
    ├── enemy_sprites/               (PNG sprite wrogów)
    ├── weapon_sprites/              (PNG grafiki broni)
    ├── explosion_sprites/           (PNG animacje eksplozji)
    ├── extracted_sounds/            (WAV audio)
    └── extracted_weapon_sprites/    (PNG pociski wrogów)
```

---

## ARCHITEKTURA — AKTUALNA (po refaktorze 2026-05-06)

### Hierarchia sceny World.tscn
```
World (Node2D)
├── Player (CharacterBody2D)          ← stały w przestrzeni świata
│   ├── WeaponSystem
│   ├── DamageSystem
│   └── ShieldSystem
├── LevelMap (Node2D, LevelManager.gd) ← scrolluje w dół, zawiera wrogów
│   ├── LevelRuler                    ← wizualna linijka (@tool, opcjonalna)
│   ├── Enemy_XXX (instancje)         ← przeciągane z scenes/enemies/
│   └── …
└── CanvasLayer
    └── HUD
```

### LevelManager.gd (scrypt LevelMap)
- `@export var scroll_speed: int = 2` — px/klatkę w dół
- `_process`: `position.y += scroll_speed` (przesuwa całą mapę w dół)
- `_ready`: rekurencyjnie łączy sygnał `projectile_spawned` od wszystkich wrogów
- `_on_projectile_spawned`: dodaje pocisk do `get_parent()` (World) — nie scrolluje z mapą

### LevelRuler.gd (@tool)
- Wizualna linijka z markerami co 1s/5s/10s w przestrzeni LevelMap
- Zielona strefa Y=0..200 = widoczne od startu
- `@export scroll_speed`, `level_length_seconds`, `show_in_game`
- **Konwencja:** 1 sekunda = `scroll_speed × 30` px; Y=-600 przy speed=2 ≈ 10 sekund

### Konwencja rozmieszczania wrogów
| Czas pojawienia | Pozycja Y w LevelMap (speed=2, 30fps) |
|---|---|
| od razu | 0 … 200 |
| 5 sekund | −300 |
| 10 sekund | −600 |
| 30 sekund | −1800 |
| 1 minuta | −3600 |

---

## SKRYPTY — TABELA PLIKÓW

| Plik | Linie | Cel | Kluczowe metody |
|------|-------|-----|-----------------|
| **Core (Autoload)** | | | |
| DataManager.gd | 336 | Cache JSON (statki, wrogowie, bronie) | load_json, get_*_by_id |
| GameConstants.gd | 28 | Preload 4 PackedScenes | enemy_projectile_scene, explosion_scene |
| PlayerSetup.gd | 37 | Stan ekwipunku gracza | (właściwości) |
| SoundManager.gd | 55 | Kanały audio | play_weapon_sound, play_sound |
| **Świat** | | | |
| LevelManager.gd | ~20 | Scroll LevelMap + routing pocisków | _process, _connect_signals, _on_projectile_spawned |
| LevelRuler.gd | ~80 | @tool linijka edytora | _draw |
| **Gracz & UI** | | | |
| player.gd | 165 | Fizyka gracza, strzały | _physics_process, load_ship_data |
| DamageSystem.gd | 31 | Podział obrażeń (shield→armor) | take_damage |
| ShieldSystem.gd | 45 | Regeneracja tarczy | load_shield_config, take_shield_damage |
| WeaponSystem.gd | 150 | Logika strzelania | load_weapon_config, shoot, create_projectile |
| Hud.gd | 119 | Paski UI, zmiana broni | _update_labels |
| **Wrogowie** | | | |
| Enemy.gd | ~290 | Baza wrogów (AI, strzelanie, ścieżki, śmierć) | _process, _process_shooting, take_damage, die |
| PathConfig.gd | 27 | @tool konfiguracja Path2D | _process (scroll_speed, auto_advance) |
| **Pociski** | | | |
| projectile.gd | 116 | Pocisk gracza | _physics_process, _init_circlesize |
| EnemyProjectile.gd | 94 | Pocisk wroga | _physics_process, homing, acceleration |
| **Eksplozje** | | | |
| Explosion.gd | 57 | Jedna eksplozja | setup, _process |
| RepExplosion.gd | 63 | Eksplozje cykliczne | setup, _fire_burst |

---

## ENEMY.GD — SZCZEGÓŁY

### Inicjalizacja (_ready)
- `velocity = Vector2(float(xmove), float(ymove))` — pobiera z inspektora sceny
- `projectile_scene = GameConstants.enemy_projectile_scene` — auto-ustawiane
- `set_process(false)` — wróg nieaktywny dopóki nie wejdzie na ekran
- `screen_entered` → `set_process(true)` — aktywacja po wejściu w viewport
- `screen_exited` → `_on_screen_exited()` — usuwa tylko gdy NIE jest na ścieżce

### _on_screen_exited — ważna zasada
```gdscript
func _on_screen_exited():
    if _active_follow:
        return   # ścieżka trwa — ignoruj (visual może wychodzić poza ekran)
    queue_free()
```
**Dlaczego:** Godot śledzi granice canvas całego drzewa (łącznie z Visual przesuwanym przez RemoteTransform2D). Wróg lecący w górę → visual wychodzi przez górę ekranu → `screen_exited` → bez tej ochrony byłby usuwany w środku ścieżki.

### Zakończenie ścieżki
```gdscript
if _active_follow.progress_ratio >= 1.0:
    _active_follow = null   # przejście na swobodny ruch (velocity)
    # screen_exited wyczyści wroga gdy opuści ekran
```

### Tryby ruchu
1. **Swobodny** (`wybran_sciezka == ""`): `position += velocity` każdą klatkę
2. **Ścieżka** (`wybran_sciezka != ""`): PathFollow2D via RemoteTransform2D przesuwa Visual i CollisionShape2D; po zakończeniu → tryb swobodny

### PathConfig.gd (na Path2D)
- `speed`: px/klatkę wzdłuż krzywej
- `speed_curve`: Curve modulująca prędkość (0..1 → mnożnik)
- `scroll_speed`: `position.y += scroll_speed` per klatka — używane do kontrowania scrollu LevelMap (ustaw na `-LevelManager.scroll_speed` żeby ścieżka była nieruchoma w świecie)
- `auto_advance = true`: tylko dla formacji — PathConfig sam przesuwa PathFollow2D

---

## KLUCZOWE WZORCE ARCHITEKTONICZNE

### 1. Autołady (project.godot)
- **DataManager** — JSON cache
- **PlayerSetup** — ekwipunek gracza
- **GameConstants** — preload scen
- **SoundManager** — audio

### 2. Hierarchia gracza
```
Player (CharacterBody2D)
├── WeaponSystem  (instancjuje pociski)
├── DamageSystem  (przyjmuje obrażenia)
├── ShieldSystem  (regeneruje tarczę)
└── CollisionShape2D
```

### 3. Pociski wrogów — przepływ
```
Enemy._fire_projectile()
  → emit projectile_spawned(projectile)
    → LevelMap._on_projectile_spawned()
      → World.add_child(projectile)   ← nie scrolluje z mapą
```

### 4. Sceny wrogów (Enemy_NNN.tscn)
- Dziedziczą z `Enemy.tscn` (instancja z nadpisanymi właściwościami)
- Eksportowane właściwości: `armor`, `esize`, `value`, `explosiontype`, `xmove`, `ymove`, `tur[3]`, `freq[3]`, `wybran_sciezka`
- Mogą zawierać wiele Path2D (różne trasy); aktywna wskazana przez `wybran_sciezka`
- Można nadpisywać właściwości per-instancja bezpośrednio w World.tscn

---

## NIEUŻYWANE PLIKI (zachowane na dysku)
| Plik | Powód zachowania |
|------|-----------------|
| scripts/managers/EnemySpawner.gd | Stary system eventowy — może być przydatny jako referencja |
| scripts/managers/EnemyController.gd | j.w. |
| scripts/managers/EventProcessor.gd | j.w. |
| scenes/background/*.gd / *.tscn | Potencjalne użycie w przyszłości |
| data/lvl*.json | Dane źródłowe poziomów Tyrian |
