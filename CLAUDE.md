# GALAXID — Dokumentacja projektu dla Claude

## Czym jest projekt

Klasyczny shoot'em up (shmup) w stylu Tyrian (1995). Gra mobilna portrait, silnik Godot 4.6 Forward Plus, GDScript. Gałąź robocza: `GalaxidFree`.

---

## Konfiguracja projektu

```
Rozdzielczość : 1080×1920 (portrait)
FPS           : 60 (logika fizyki: 30 fps)
Physics engine: Jolt Physics
Stretch mode  : canvas_items
Główna scena  : res://scenes/world/World.tscn
```

**project.godot** — kluczowe sekcje:
- `physics/common/physics_ticks_per_second = 30`
- `physics/common/physics_interpolation = true`
- Autoloads: DataManager, PlayerSetup, GameConstants, SoundManager

---

## Struktura katalogów

```
Galaxid/
├── scenes/
│   ├── world/          # World.tscn, LevelManager.gd, LevelRuler.gd
│   ├── player/         # Player.gd, WeaponSystem.gd, DamageSystem.gd, ShieldSystem.gd
│   ├── enemy/          # Enemy.gd, EnemyPath.gd
│   ├── enemies/        # Konkretne sceny wrogów (small_aircraft.tscn itp.)
│   ├── enemy_projectile/ # EnemyProjectile.gd
│   ├── projectile/     # projectile.gd
│   └── explosions/     # Explosion.gd, RepExplosion.gd
├── scripts/
│   ├── core/           # DataManager.gd, GameConstants.gd, PlayerSetup.gd
│   ├── managers/       # SoundManager.gd
│   └── resources/      # ShipData.gd, ShieldData.gd, GeneratorData.gd
├── UI/                 # Hud.tscn, Hud.gd
├── data/
│   ├── weapon.json          # ~1MB, wszystkie dane broni
│   ├── weapon_ports.json    # Porty broni i tryby strzelania
│   ├── ships/               # 13 plików .tres (ShipData)
│   ├── shields/             # 10 plików .tres (ShieldData)
│   ├── generators/          # 6 plików .tres (GeneratorData)
│   ├── weapon_sprites/      # Sprite'y pocisków (z Tyriana)
│   ├── explosion_sprites/   # Animacje eksplozji
│   └── extracted_sounds/    # Dźwięki WAV
├── demo/               # Demo.tscn, CodeGeneratedDemo.tscn, NavigationDemo.tscn
└── assets/             # Ikony, grafiki
```

---

## Autoloady (singletony)

| Singleton | Plik | Rola |
|-----------|------|------|
| `DataManager` | `scripts/core/DataManager.gd` | Cache i ładowanie danych JSON/.tres |
| `PlayerSetup` | `scripts/core/PlayerSetup.gd` | Rejestr wybranego ekwipunku gracza |
| `GameConstants` | `scripts/core/GameConstants.gd` | Preload scen |
| `SoundManager` | `scripts/managers/SoundManager.gd` | Obsługa dźwięku z cache |

---

## Warstwy fizyki (Collision Layers)

| Bit | Nazwa | Kto używa |
|-----|-------|-----------|
| 1 | Player | Gracz (CharacterBody2D) |
| 2 | Enemies | Wrogowie (Area2D) |
| 4 | PlayerProjectile | Pociski gracza (Area2D) |
| 8 | EnemyProjectile | Pociski wrogów (Area2D) |

**Collision masks:**
- Gracz: `layer=1, mask=0` — gracz nie wykrywa nic, to wrogowie go wykrywają
- Wróg: `layer=2, mask=5` (1+4) — wykrywa gracza i pociski gracza
- Pocisk gracza: `layer=4, mask=2` — wykrywa wrogów
- Pocisk wroga: `layer=8, mask=1` — wykrywa gracza

---

## Główne komponenty

### Player (`scenes/player/Player.gd`)
`extends CharacterBody2D`

Kluczowe zmienne:
- `armor: int` — pancerz
- `power: float` — energia (regeneruje się)
- `power_max: float` — max energia
- `power_add: float` — szybkość regeneracji (obliczona z generatora × 30)
- `ship_data: ShipData`

Węzły-dzieci: `WeaponSystem`, `DamageSystem`, `ShieldSystem`

Ruch: śledzenie pozycji myszy w `_physics_process`.

---

### WeaponSystem (`scenes/player/WeaponSystem.gd`)
`extends Node`

Kluczowe zmienne:
- `current_weapon_index: int` — indeks portu z weapon_ports.json
- `power_level: int` — poziom mocy (1–11)
- `weapon_data: Dictionary` — pełne dane broni z weapon.json
- `pattern_index: int` — tracker dla multi-shot

Przepływ strzelania:
```
shoot()
  → sprawdź power_use (PlayerSetup → DataManager)
  → player.power -= power_use
  → dla każdego pattern w multi:
      create_projectile(attack, sx, sy, bx, by, sg, del, aim, ...)
```

Ładowanie broni: `load_weapon_config()` → `DataManager.get_weapon_firing_index(port_id, mode, power)` → `DataManager.get_weapon_by_id(firing_id)`

---

### Enemy (`scenes/enemy/Enemy.gd`)
`extends Area2D`

Eksportowane właściwości:
- `armor: int` — życie
- `esize: int` — 0=mały, 1=duży
- `value: int` — punkty
- `explosiontype: int` — bit 0: naziemny/powietrzny; bity 1+: liczba wybuchów
- `xmove, ymove: int` — prędkość (w Tyrian px/frame, skalowana × 30)
- `tur[3]: Array` — ID broni [dół, prawo, lewo]
- `freq[3]: Array` — częstotliwość strzelania

Strzelanie: `eshotwait[i] -= delta` → gdy ≤ 0 → `_fire_projectile(i)`

Sygnał: `projectile_spawned(projectile)` — odbierany przez LevelManager

Śmierć: `die()` → `_spawn_death_explosion()` → `queue_free()`
- Mały wróg: 1 eksplozja
- Duży wróg: 4 eksplozje w rogach

---

### Projectile (`scenes/projectile/projectile.gd`)
`extends Area2D`

Parametry:
- `velocity: Vector2` — prędkość px/s
- `acceleration: Vector2` — przyspieszenie px/s²
- `damage: int`
- `lifetime: float` — 0 = nieskończony
- `shot_graphic: int` — ID sprite'a
Kolizja: `_on_area_entered(enemy)` → `enemy.take_damage(damage)` → `queue_free()`

---

### EnemyProjectile (`scenes/enemy_projectile/EnemyProjectile.gd`)
`extends Area2D`

Parametry:
- `velocity: Vector2`
- `damage: int`
- `sprite_id: int`
- `tx, ty: int` — prędkość homingu (px/frame)
- `acceleration, accelerationx: int`
- `duration: float` — czas życia

Homing:
```gdscript
homing_step = 900 * delta
velocity.x = move_toward(velocity.x, sign(player_dir_x) * tx, homing_step)
velocity.y = move_toward(velocity.y, sign(player_dir_y) * ty, homing_step)
```

---

### DamageSystem (`scenes/player/DamageSystem.gd`)
`extends Node`

`take_damage(amount)` → tarcza absorbuje część → `player.armor -= reszta` → jeśli ≤ 0: `_on_player_death()`

**Uwaga:** `_on_player_death()` jest jeszcze niezaimplementowane (TODO).

---

### ShieldSystem (`scenes/player/ShieldSystem.gd`)
`extends Node`

- `shield: float` — aktualna tarcza
- `shield_max: float` — max (= protection × 2)
- `shield_t: int` — koszt energii za punkt regeneracji (= generator_needed × 20)

Regeneracja co 0.5s, koszt `shield_t` energii, zysk +1.0 tarczy.

---

### Explosion (`scenes/explosions/Explosion.gd`)

Typy (0–13):
- 0: hit_flash, 1: small_enemy
- 2–5: large_ground (rogi), 6: white_smoke
- 7–10: large_air (rogi), 11: flash_short, 12: medium, 13: brief

Cache sprite'ów per typ; animacja klatka po klatce w `_process`; `queue_free()` po ostatniej klatce.

### RepExplosion (`scenes/explosions/RepExplosion.gd`)

Seria eksplozji co 3–4 klatki z jitterem. `_bursts_left` kontroluje liczbę serii.

---

### LevelManager (`scenes/world/LevelManager.gd`)
`extends Node2D`

- `scroll_speed: int = 2` — prędkość scrollu tła w Tyrian px/frame (domyślna eksportowana wartość)
- Ruch: `position.y += float(scroll_speed) * 30.0 * delta`
- `start_dist: int = 0` — debug offset startowy mapy
- Rekursywnie podłącza sygnał `projectile_spawned` od wszystkich Enemy w scenie
- `_on_projectile_spawned(projectile)` → `add_child(projectile)`

---

### HUD (`UI/Hud.gd`)
`extends CanvasLayer`

Paski: Power, Shield, Armor. Przyciski prev/next dla broni, tarczy, generatora.

`_reload_systems()` — po zmianie ekwipunku w UI: przeładowuje WeaponSystem, ShieldSystem, PowerRegeneration.

---

## DataManager — API

### Statki
```gdscript
DataManager.get_ships() → Array[ShipData]
DataManager.get_ship_by_id(id: int) → ShipData
```
Źródło: `res://data/ships/*.tres`

### Bronie
```gdscript
DataManager.get_weapons() → Array
DataManager.get_weapon_by_id(id: int) → Dictionary
DataManager.get_weapon_firing_index(port_id, mode, power) → int
DataManager.get_weapon_power_use(port_id) → int
```
Źródło: `res://data/weapon.json` + `weapon_ports.json`

**Uwaga:** `_normalize_weapon()` skaluje sx/sy/del z 30fps Tyriana na delta-time.

### Tarcze
```gdscript
DataManager.get_shields() → Array[ShieldData]
DataManager.get_shield_by_id(id: int) → ShieldData
```
Źródło: `res://data/shields/*.tres`

### Generatory
```gdscript
DataManager.get_generators() → Array[GeneratorData]
DataManager.get_generator_by_id(id: int) → GeneratorData
DataManager.get_generator_power(generator_id) → float  # moc × 30.0
```
Źródło: `res://data/generators/*.tres`

### Sprite'y pocisków
```gdscript
DataManager.get_shot_texture(sg: int) → Texture2D
DataManager.get_shot_texture_frames(sg, anim_count) → Array[Texture2D]
```

---

## Struktury danych JSON

### weapon_ports.json
```json
{
  "weapon_ports": [{
    "index": 1,
    "name": "Pulse-Cannon",
    "stats": {
      "power_use": 30,
      "modes_count": 1
    },
    "firing_modes": {
      "mode_1": [155, 156, 157, 158, 159, 160, 161, 162, 163, 164, 165]
    }
  }]
}
```
`firing_modes.mode_X[i]` = ID broni dla power level (i+1), i ∈ 0..10.

### weapon.json
```json
{
  "TyrianHDT": {
    "weapon": [{
      "index": 155,
      "multi": 1,
      "max": 1,
      "shotRepeat": 0.1,
      "aim": 0,
      "acceleration": 0,
      "accelerationx": 0,
      "tx": 0, "ty": 0,
      "patterns": [{
        "attack": 5,
        "sx": 0, "sy": -4,
        "bx": 0, "by": 0,
        "sg": 0,
        "del": 0
      }]
    }]
  }
}
```
- `sx/sy` — prędkość (Tyrian px/frame, skalowane × 30)
- `del` — czas życia (klatki/30 → sekundy; 0 = nieskończony)
- `aim` — homing (>0)
- `tx/ty` — homing speed dla wrogów

### ShipData (.tres)
```
index: int, name: String, armor: int, speed: int, cost: int
```

### ShieldData (.tres)
```
index: int, name: String, generator_needed: int, protection: int, cost: int
```

### GeneratorData (.tres)
```
index: int, name: String, power: int, speed: int, cost: int
```

---

## PlayerSetup — rejestr ekwipunku

```gdscript
ship_id: int = 1
front_weapon_index: int = 1    # indeks portu broni
front_weapon_mode: int = 1     # tryb strzału (1 lub 2)
front_power_level: int = 1     # 1–11
rear_weapon_index: int = 1
rear_weapon_mode: int = 1
rear_power_level: int = 1
generator_id: int = 1
shield_id: int = 1
credits: int = 1000
score: int = 0
lives: int = 3
```

---

## Kluczowe przepływy

### Gracz strzela
```
Player._physics_process()
→ weapon_system.set_firing(mouse_pressed)
→ WeaponSystem: fire_timer -= delta → shoot()
→ player.power -= power_use
→ create_projectile() → add_child(World)
```

### Wróg strzela
```
Enemy._process() → _process_shooting(delta)
→ eshotwait[i] -= delta → _fire_projectile(i)
→ instantiate EnemyProjectile
→ emit projectile_spawned
→ LevelManager.add_child(projectile)
```

### Pocisk gracza trafia wroga
```
Projectile._on_area_entered(enemy)
→ enemy.take_damage(damage)
→ armor <= 0 → die() → _spawn_death_explosion() → queue_free()
→ projectile.queue_free()
```

### Zmiana ekwipunku w UI
```
Hud._on_weapon_next()
→ PlayerSetup.front_weapon_index = next
→ _reload_systems()
→ weapon_system.load_weapon_config()
→ shield_system.reload()
→ player.reload_power_regeneration()
```

---

## System delta-time — konwencja przeliczania jednostek

Projekt używa **delta-time wszędzie**. Dane z Tyriana są w `px/frame @ 30fps` — przeliczenie na delta-time odbywa się przez mnożenie × 30.0.

### Łańcuch przeliczenia — pociski gracza i wroga
```
weapon.json: sx = Tyrian px/frame
DataManager._normalize_weapon(): velocity.x = sx * 30.0   → Tyrian px/s
projectile.gd:  position.x += velocity.x * 4.0 * delta    → Godot px
                position.y += velocity.y * 9.6 * delta
```
Mnożniki przestrzeni: **X = 4.0**, **Y = 9.6** — wynikają z przejścia rozdzielczości 360×200 → 1080×1920.
- Y = 1920 / 200 = **9.6** (dokładna skala)
- X = 1080 / 360 = 3.0 matematycznie, ale używamy **4.0** — celowo wyższy, żeby pociski poziome czuły się lepiej.

### Łańcuch przeliczenia — ruch wroga
```
Enemy.gd: xmove/ymove w Tyrian px/frame
_ready(): velocity = Vector2(xmove, ymove) * 30.0           → px/s w przestrzeni Godot (BEZ mnożnika 4/9.6)
_process(): position += velocity * delta
```
**Uwaga:** wrogowie NIE mają mnożnika 4.0/9.6. Ich prędkość `× 30` trafia bezpośrednio do Godot px/s.

### Łańcuch przeliczenia — scroll tła
```
LevelManager: scroll_speed = 2  (Tyrian px/frame)
_process(): position.y += float(scroll_speed) * 30.0 * delta
```

### Inne przeliczenia
| Wartość | JSON/eksport | Przeliczenie | Użycie |
|---------|-------------|--------------|--------|
| `freq[i]` (Enemy) | klatki Tyriana | `/ 30.0` → sekundy | `eshotwaitmax[i]` |
| `del` (weapon pattern) | klatki Tyriana | `/ 30.0` → sekundy | `lifetime` pocisku |
| `shotRepeat` (weapon) | sekundy | bez zmian | `fire_timer` |
| `generator.power` | wartość surowa | `* 30.0` | `power_add` gracza |
| homing step | — | `900 * delta` | `move_toward` w EnemyProjectile |

### Circlesize — wyjątek: własny 30fps timer
Ruch okrężny pocisków taktuje **niezależnym timerem co 1/30s** (nie po delta):
```gdscript
const _CIRCLE_STEP: float = 1.0 / 30.0
_circle_timer += delta
while _circle_timer >= _CIRCLE_STEP:
    _circle_timer -= _CIRCLE_STEP
    circle_dev_x += circle_dir_x  # integer step
```

### Czego NIE robić
- Nie skaluj ponownie wartości z DataManagera — `sx/sy` są już w Tyrian px/s po `_normalize_weapon()`.
- Nie dodawaj mnożnika 4.0/9.6 do prędkości wroga — Enemy używa innego łańcucha niż pociski.

---

## Ważne konwencje i pułapki

- **Gracz CharacterBody2D, wrogowie/pociski Area2D**: Gracz używa `move_and_slide()`, reszta tylko Area.
- **Gracz mask=0**: Gracz celowo nie wykrywa kolizji — pociski wroga same go wykrywają.
- **Eksplozje dużych wrogów**: 4 osobne Explosion w rogach + opcjonalny RepExplosion.
- **VisibleOnScreenNotifier2D**: Wrogowie i pociski mają go podłączonego do `queue_free()` — nie usuwaj.
- **EnemyPath / PathFollow2D**: jeśli parent wroga to PathFollow2D, to `_on_screen_exited` nie usuwa wroga (EnemyPath zarządza cyklem życia), a ruch przez `position +=` jest pominięty.

---

## Co jest niezaimplementowane (TODO)

- `_on_player_death()` w DamageSystem — logika śmierci gracza
- Rear weapon (broń tylna)
- Sidekicks (pomocnicy lewy/prawy)
- Menu główne
- Pause/Resume
- Power-upy / drop items
- Boss fights
- Wiele poziomów (LevelManager ma zaczątki loadera lvl*.json)

---

## Audio (SoundManager)

Dwa kanały AudioStreamPlayer: `Weapons` i `Explosions`. Lazy load + cache.
Dźwięki z `res://data/extracted_sounds/`. Kluczowe ID: 3=hit, 8=small explosion, 9=large explosion.
