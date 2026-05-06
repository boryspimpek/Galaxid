# GALAXID PROJECT CODE REVIEW & REFACTORING OPPORTUNITIES

## Project Overview
Galaxid is a Godot 4.6 remake of the classic 1995 shooter "Tyrian 2000." It's a vertical-scrolling shoot-'em-up using Godot 4.6 (Forward+ rendering) with a 360×200 viewport (scaled to 1440×800). The project spans ~30 GDScript files organized into clear architectural layers.

Key Context: The game uses Tyrian pixel units (not Godot pixels), with all enemy movement, weapon firing, and game logic based on frame-by-frame Tyrian semantics.

## DIRECTORY/FILE STRUCTURE
Galaxid/
├── project.godot                          (Config: 4.6, max_fps=30, 360×200 viewport)
├── UI/
│   ├── Hud.gd                            (UI HUD system: power/shield/armor bars + weapon selection)
│   └── Hud.tscn
├── scenes/
│   ├── background/
│   │   ├── Background.tscn               (Root background node)
│   │   ├── Starfield.gd                  (100-star parallax scroller, 2-4px/frame + global speed)
│   │   ├── TileBackground.gd             (3-layer tilemap loader: layer1/2/3 + different scroll speeds)
│   │   └── TileLayer.gd                  (Individual tile layer: scrolls, wraps, caches textures)
│   ├── world/
│   │   ├── World.tscn                    (Main scene root)
│   │   └── LevelManager.gd               (Root manager: init 3 managers, run level_distance += back_move each frame)
│   ├── player/
│   │   ├── Player.tscn                   (Player CharacterBody2D with 3 child systems)
│   │   ├── player.gd                     (SPEED_CAP=4px/frame, friction=2, acceleration=1, power regen)
│   │   ├── DamageSystem.gd               (take_damage: shield absorbs first, then armor)
│   │   ├── ShieldSystem.gd               (regen on 15-frame cooldown, costs power per point)
│   │   ├── WeaponSystem.gd               (weapon config from DataManager, shoot() instantiates projectiles)
│   │   ├── DamageSystem.tscn
│   │   ├── ShieldSystem.tscn
│   │   ├── WeaponSystem.tscn
│   ├── projectile/
│   │   ├── Projectile.tscn               (Player bullet: Area2D, handles circlesize orbits)
│   │   └── projectile.gd                 (velocity+acceleration, circlesize drift, lifetime, texture)
│   ├── enemy/
│   │   ├── Enemy.tscn                    (Base enemy template)
│   │   └── Enemy.gd                      (xmove/ymove physics, weapon firing, path follow, death explosions)
│   ├── enemies/
│   │   ├── Enemy_001.tscn through Enemy_999.tscn  (350+ enemy instances)
│   │   └── PathConfig.gd                 (@tool Path2D: scroll_speed, auto_advance, progress cycling)
│   ├── enemy_projectile/
│   │   ├── EnemyProjectile.tscn          (Enemy bullet: Area2D)
│   │   └── EnemyProjectile.gd            (anim_frames, tx/ty homing, acceleration, duration)
│   ├── explosions/
│   │   ├── Explosion.tscn
│   │   ├── Explosion.gd                  (type-based sprite caching: 14 types, 3-12 frames each)
│   │   ├── RepExplosion.tscn
│   │   └── RepExplosion.gd               (repeating explosions: bursts every 3-4 frames with jitter)
├── scripts/
│   ├── core/
│   │   ├── DataManager.gd                (Autoload: JSON loader, caches ships/enemies/weapons/shields/generators)
│   │   ├── GameConstants.gd              (Autoload: bounds, preloaded scenes)
│   │   └── PlayerSetup.gd                (Autoload: player ship/weapon/shield/generator state)
│   ├── managers/
│   │   ├── EnemySpawner.gd               (instantiates enemies, stores scene cache, 5 spawn event types)
│   │   ├── EnemyController.gd            (enemy_fire_power event: modifies tur/freq per link_num)
│   │   ├── EventProcessor.gd             (sorts/processes events, fast_forward_to, scroll speed changes)
│   │   └── SoundManager.gd               (Autoload: AudioStreamPlayer channels for weapons & impacts)
├── demo/                                  (3D Terrain3D demo with navigation — separate from main game)
│   ├── Demo.tscn
│   ├── src/
│   │   ├── DemoScene.gd
│   │   ├── Player.gd                     (3D movement: WASD, camera with mouse, first-person toggle)
│   │   ├── Enemy.gd                      (3D navigation agent)
│   │   ├── CameraManager.gd              (mouselook with yaw/pitch limits)
│   │   ├── UI.gd                         (F8-F12 debug overlays, fullscreen toggle)
│   │   ├── RuntimeNavigationBaker.gd     (async nav mesh baking around player position)
│   │   └── CodeGenerated.gd
├── addons/                               (Third-party plugins)
│   ├── terrain_3d/                       (3D terrain system for demo only)
│   ├── level_editor/                     (Custom timeline-based level editor)
│   │   ├── plugin.cfg
│   │   ├── LevelEditorPanel.gd
│   │   └── plugin.gd
└── data/                                 (JSON game data, extracted tiles/sounds/sprites)
    ├── ships.json, enemies.json, weapon.json, shields.json, etc.
    ├── lvl01.json through lvl99.json      (Level event data)
    ├── weapon_sprites/                    (PNG weapon graphics)
    ├── explosion_sprites/                 (PNG explosion animations)
    ├── extracted_sounds/                  (WAV audio files)
    ├── extracted_map_tiles/               (Level-specific tile layers)
    └── extracted_weapon_sprites/          (Enemy bullet graphics)
## SCRIPT FILE CONTENTS SUMMARY

| File | Lines | Purpose | Key Methods |
|------|-------|---------|-------------|
| **Core (Autoload)** | | | |
| DataManager.gd | 336 | Central JSON loader, caches all data | load_json, get_*_by_id, clear_cache |
| GameConstants.gd | 28 | Shared constants, scene preloads | _ready preloads 4 PackedScenes |
| PlayerSetup.gd | 37 | Player equipment state | (properties only: ship_id, weapon_index, power_level, etc.) |
| **Managers** | | | |
| LevelManager.gd | 107 | Level orchestrator | _ready, _process, load_data, init_managers |
| EnemySpawner.gd | 211 | Enemy instantiation factory | spawn_free_enemy, spawn_path_enemy, spawn_formation, spawn_free_4x4 |
| EnemyController.gd | 24 | Global enemy command channel | enemy_fire_power |
| EventProcessor.gd | 140 | Event timeline processor | fast_forward_to, process_events_for_distance, process_event |
| SoundManager.gd | 55 | Audio playback | play_weapon_sound, play_sound, _scan_sounds |
| **Player & UI** | | | |
| player.gd | 165 | Player physics & weapon firing | _physics_process, load_ship_data, _clamp_to_screen |
| DamageSystem.gd | 31 | Damage allocation (shield → armor) | take_damage, _on_player_death |
| ShieldSystem.gd | 45 | Shield regeneration | load_shield_config, take_shield_damage |
| WeaponSystem.gd | 150 | Weapon firing logic | load_weapon_config, shoot, create_projectile |
| Hud.gd | 119 | UI bar updates & equipment switching | _update_labels, _on_weapon_next/prev, etc. |
| **Projectiles** | | | |
| projectile.gd | 116 | Player bullets | _physics_process, _init_circlesize (orbit movement) |
| EnemyProjectile.gd | 94 | Enemy bullets | _physics_process, homing, acceleration, duration |
| **Enemies & Explosions** | | | |
| Enemy.gd | 284 | Enemy base class (AI, shooting, death) | _process, _process_shooting, take_damage, die, _spawn_death_explosion |
| Explosion.gd | 57 | Single explosion sprite animation | setup, _process (frame-by-frame) |
| RepExplosion.gd | 63 | Repeating burst explosions | setup, _fire_burst (3-4 frame intervals) |
| **Background** | | | |
| TileBackground.gd | 121 | Multi-layer tilemap setup | setup, set_scroll_speed, seek_to |
| TileLayer.gd | 65 | Single tilemap layer scrolling | _process (_scroll_y -= back_move), _draw |
| Starfield.gd | 66 | Parallax starfield (uint16 wrapping) | _process (star.position overflow), _draw |
| PathConfig.gd | 27 | @tool path configuration | _process (auto_advance, progress cycling) |
| **UI (Demo)** | | | |
| UI.gd | 65 | Debug overlay (F8-F12 toggles) | _unhandled_key_input, toggle_fullscreen |
| **3D Navigation** | | | |
| RuntimeNavigationBaker.gd | 152 | Async nav mesh baking | _rebake, _task_bake (offloaded to WorkerThreadPool) |
## KEY ARCHITECTURAL PATTERNS

1. **Autoload Singletons** (Top-level managers in project.godot)
   - **DataManager** — JSON caching & hot-loading
   - **PlayerSetup** — Persistent equipment state
   - **GameConstants** — Shared constants & preloaded scenes
   - **SoundManager** — Audio channel pooling

2. **Manager Pattern** (Created by LevelManager._ready())
   - **EnemySpawner** — Enemy scene instantiation & caching
   - **EnemyController** — Global enemy command bus (enemy_fire_power events)
   - **EventProcessor** — Timeline processor (sorted by dist)

3. **Scene Hierarchy for Player**
   ```
   Player (CharacterBody2D)
   ├── WeaponSystem (fires projectiles)
   ├── DamageSystem (takes damage)
   ├── ShieldSystem (regenerates shields)
   ├── CollisionShape2D
   └── [other visual/collision nodes]
   ```

4. **Enemy Spawning** (5 event types)
   - `100` (path_enemy): Enemy follows a Path2D (RemoteTransform2D-controlled)
   - `200` (spawn_free_enemy): Single enemy with direct velocity
   - `201` (spawn_free_4x4): 2×2 grid of 4 enemies
   - `202` (just_spawn_enemy): Hybrid (path if "path" key present, else free)
   - `204` (spawn_formation): Group scene with PathFollow2D-controlled children

5. **Event System** (JSON-driven)
   - Events sorted by dist (level timeline position)
   - Type-based dispatch in EventProcessor.process_event()
   - Context events (type 2) update scroll speeds globally
   - Spawn events create enemy instances synchronously