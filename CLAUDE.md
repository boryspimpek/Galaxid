# Galaxid — Project Context

Galaxid is a Godot 4 remake of the classic shooter **Tyrian** (1995, Epic MegaGames).
The game is a vertical-scrolling shoot-'em-up. All game-logic units (positions, velocities,
distances) use **Tyrian pixel/frame** values, not Godot pixels. The screen is **288 px wide**.

---

## Architecture

```
scenes/world/LevelManager.gd      — root node of a level; owns all managers
scripts/managers/EnemySpawner.gd  — instantiates & configures enemy scenes
scripts/managers/EnemyController.gd — global enemy commands (move, accel, fire)
scripts/managers/EventProcessor.gd — reads lvlXX.json events, dispatches them
scenes/enemy/Enemy.gd             — base class for all enemies (Area2D)
scenes/background/Background.gd   — owns TileBackground + Starfield
scenes/background/TileBackground.gd — 3 TileLayer nodes (ground / sky / top)
scenes/background/TileLayer.gd    — scrolls a tilemap layer each frame
addons/level_editor/LevelEditorPanel.gd — @tool editor plugin (timeline + JSON editor)
```

---

## Scroll System

Each frame `LevelManager._process` runs:
```gdscript
level_distance += float(back_move)         # advances level timeline
TileLayer._scroll_y -= back_move           # moves the tile layer down
```

Three scroll speeds correspond to three background layers and enemy slots:

| Variable    | Slot  | Layer   | Typical value |
|-------------|-------|---------|---------------|
| `back_move` | 25,75 | ground  | 1–4           |
| `back_move2`| 0     | sky     | 2× back_move  |
| `back_move3`| 50    | top     | 3× back_move  |

**Critical invariant:** `layer1_scroll_px == level_distance` (1:1 ratio, no multiplier).
`layer2` and `layer3` scroll proportionally: `segment * backMoveN / back_move`.

When `back_move` changes mid-level (event type 2/30), all living enemies' `scroll_y` is
updated immediately and `EnemySpawner.set_scroll_data()` is called.

---

## Level Data Format

Files: `data/lvlXX.json`

```json
{
  "lvl17": {
    "header": {
      "map_x": 1, "map_x2": 1, "map_x3": 1, "map_y": 0,
      "level_enemies": [3, 5, 7],
      "level_enemy_frequency": 96
    },
    "events": [ ... ]
  }
}
```

Events are **sorted by `dist`** (ascending). `dist` is in Tyrian units (== `level_distance`).
Each event has: `dist`, `event_type`, `event_name`, `category` (`"spawn"` or `"context"`).

---

## Event Types

### Context events (change global state, replayed on fast-forward)

| type | event_name            | key fields                                      |
|------|-----------------------|-------------------------------------------------|
| 1    | starfield_speed       | `starfield_speed`                               |
| 2,30 | scroll_speed          | `back_move`, `back_move2`, `back_move3`         |
| 8    | starfield             | `star_active` (bool)                            |
| 13   | disable_random_spawn  | `enemies_active: false`                         |
| 14   | enable_random_spawn   | `enemies_active: true`                          |
| 19   | global_enemy_move     | applies velocity to all live enemies            |
| 20   | global_enemy_accel    | applies acceleration to all live enemies        |
| 26   | small_enemy_adjust    | `small_enemy_adjust` (bool)                     |
| 27   | global_enemy_accelrev | reverse accel                                   |
| 31   | enemy_fire_override   | overrides fire params of live enemies           |

### Spawn events (create enemies)

| type | event_name        | key fields                                                  |
|------|-------------------|-------------------------------------------------------------|
| 6    | spawn_ground      | `screen_x`, `screen_y`, `enemy_id`, `enemy_slot`(25)       |
| 7    | spawn_top         | `screen_x`, `screen_y`, `enemy_id`, `enemy_slot`(50)       |
| 10   | spawn_ground_2    | like 6, slot 75                                             |
| 15   | spawn_sky         | `screen_x`, `screen_y`, `enemy_id`, `enemy_slot`           |
| 17   | spawn_enemy       | generic: `screen_x`, `screen_y`, `enemy_id`, `enemy_slot`, `y_vel` |
| 18   | spawn_sky_bottom  | sky layer, scrolls upward (`-back_move2`)                   |
| 23   | spawn_sky_bottom2 | sky layer, scrolls with slot                                |
| 32   | spawn_enemy_special | spawns at y=190, scrolls with `-back_move3`               |
| 33   | enemy_from_enemy  | spawns enemy when another dies                              |
| 40   | enemy_continual_damage | env damage to player                                  |
| 56   | spawn_ground2_bottom | ground2, offset +6/+3                                   |
| 60   | assign_special_enemy | `dat`..`dat6` fields, marks special/boss enemy          |
| 100  | path_enemy        | `enemy_id`, `path` (node name), `screen_x`, `screen_y`     |
| 200  | spawn_free_enemy  | `enemy_id`, `screen_x`, `screen_y`, `vel_x`, `vel_y` — scroll_y=0, slot=0 |
| 201  | spawn_free_4x4    | `enemy_ids`[4], `screen_x`, `screen_y`, `vel_x`, `vel_y` — 2×2 grid, free |

Common optional fields: `link_num`, `fixed_move_y`, `y_vel`, `enemy_slot`.

---

## Enemy System

Enemy scenes: `scenes/enemies/Enemy_XXX.tscn` (inherit from `scenes/enemy/Enemy.tscn`).
Loaded on demand and cached by `EnemySpawner._scene_for_enemy(id)`.

### Scene-exported fields (set in .tscn, define enemy behaviour)

| field    | meaning                                                  |
|----------|----------------------------------------------------------|
| `armor`  | HP; enemy dies when armor ≤ 0                           |
| `esize`  | 0=small, 1=large (affects explosion sound & adjust)      |
| `xmove`  | base velocity X (px/frame)                               |
| `ymove`  | base velocity Y (px/frame, added to scroll_y)            |
| `startx`, `starty` | default spawn position for random spawn         |
| `startxc`| random spread radius for X in random spawn               |
| `excc`, `eycc` | pendulum acceleration engine (Tyrian xcaccel/ycaccel) |
| `xrev`, `yrev` | pendulum reversal threshold velocity                |
| `xaccel`, `yaccel` | random per-frame velocity addition (unbounded if excc=0!) |
| `tur[3]` | weapon IDs [down, right, left], 0=none                  |
| `freq[3]`| fire cooldown frames per weapon                         |

### Runtime movement per frame

```gdscript
velocity.x += float(xaccel)     # random accel (dangerous without excc)
velocity.y += float(yaccel)
# pendulum engine updates velocity.x / velocity.y via excc/eycc
position.x += velocity.x
position.y += velocity.y + float(fixed_move_y) + float(scroll_y)
```

Enemy is removed when position goes outside `GameConstants.BOUNDS_*`.

### Enemy slot → scroll_y

```
slot 0    → scroll_y = 0          (free, independent)
slot 25   → scroll_y = back_move  (ground layer)
slot 50   → scroll_y = back_move3 (top layer)
slot 75   → scroll_y = back_move  (ground layer)
```

**spawn_free_enemy / spawn_free_4x4** always use slot=0, scroll_y=0, velocity from event.

---

## Debug / Play from dist

Plugin saves to `ProjectSettings`:
- `game/debug/start_dist` — level_distance starting value
- `game/debug/level_name` — overrides `LevelManager.level_name` export

`LevelManager._ready()` reads both **before** `init_managers()` / `load_data()`.
`EventProcessor.fast_forward_to(dist)` replays only context events and computes exact
background pixel offsets for `Background.seek_to(px1, px2, px3)`.

---

## Level Editor Plugin

File: `addons/level_editor/LevelEditorPanel.gd` (`@tool extends Control`)

- Timeline: Y axis = `dist` (inverted: 0 at bottom), X axis = screen X (0–288).
- Spawn events drawn as colored circles at `screen_x`.
- Context events drawn as colored bars (full width).
- Filter bar: `spawn` visible by default, `context` hidden by default.
- Click on event → editable form in right panel → "Zapisz zmiany" writes JSON to disk.
- Custom `_serialize()` preserves key insertion order and keeps simple arrays on one line.
- `READONLY_FIELDS = ["event_name", "event_type", "category"]` — never editable.
- `STRIP_FIELDS = ["raw_x"]` — auto-removed on load.
- Zoom buttons `[-]`/`[+]` scale Y axis; scroll center is preserved.
