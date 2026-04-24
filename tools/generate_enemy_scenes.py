"""
Generuje sceny Enemy_XXX.tscn dla wszystkich wrogów z enemies.json.
Każda scena dziedziczy z Enemy.tscn i ustawia teksturę + kolizję.
Istniejące pliki są pomijane (nie nadpisuje ręcznych edycji).
"""

import os, json, re

PROJECT     = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ENEMIES_JSON = os.path.join(PROJECT, "data", "enemies.json")
SPRITES_DIR  = os.path.join(PROJECT, "data", "enemy_sprites")
OUTPUT_DIR   = os.path.join(PROJECT, "scenes", "enemies")

RADIUS_BY_ESIZE = {0: 10.0, 1: 14.0}

def scan_sprites():
    pattern = re.compile(r"^enemy_(\d+)_bank\d+_f00\.png$")
    result = {}
    for f in os.listdir(SPRITES_DIR):
        m = pattern.match(f)
        if m:
            result[int(m.group(1))] = f
    return result

def build_scene(idx: int, esize: int, sprite_file: str | None) -> str:
    id_str = "%03d" % idx
    radius = RADIUS_BY_ESIZE.get(esize, 10.0)

    lines = [
        "[gd_scene format=3]",
        "",
        '[ext_resource type="PackedScene" path="res://scenes/enemy/Enemy.tscn" id="1_base"]',
    ]

    if sprite_file:
        lines.append(f'[ext_resource type="Texture2D" '
                     f'path="res://data/enemy_sprites/{sprite_file}" id="2_tex"]')

    lines += [
        "",
        f'[sub_resource type="CircleShape2D" id="CircleShape2D_{id_str}"]',
        f"radius = {radius}",
        "",
        f'[node name="Enemy_{id_str}" instance=ExtResource("1_base")]',
    ]

    if sprite_file:
        lines += [
            "",
            '[node name="Visual" parent="." index="0"]',
            'texture = ExtResource("2_tex")',
        ]

    lines += [
        "",
        '[node name="CollisionShape2D" parent="." index="1"]',
        f'shape = SubResource("CircleShape2D_{id_str}")',
        "",
    ]

    return "\n".join(lines)

def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    enemies  = json.load(open(ENEMIES_JSON, encoding="utf-8"))
    sprites  = scan_sprites()

    created = skipped = no_sprite = 0

    for enemy in enemies:
        idx = int(enemy.get("index", -1))
        if idx < 0:
            continue

        id_str = "%03d" % idx
        out_path = os.path.join(OUTPUT_DIR, f"Enemy_{id_str}.tscn")

        if os.path.exists(out_path):
            skipped += 1
            continue

        esize       = int(enemy.get("esize", 0))
        sprite_file = sprites.get(idx)
        if not sprite_file:
            no_sprite += 1

        content = build_scene(idx, esize, sprite_file)
        with open(out_path, "w", encoding="utf-8") as f:
            f.write(content)
        created += 1

    total = created + skipped
    print(f"Wrogów w enemies.json:      {len(enemies)}")
    print(f"Scen utworzono:             {created}")
    print(f"Pominięto (już istnieje):   {skipped}")
    print(f"Bez sprite'a (fallback):    {no_sprite}")
    print(f"Łącznie scen w folderze:    {total}")

if __name__ == "__main__":
    main()
