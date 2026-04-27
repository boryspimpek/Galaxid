"""
convert_to_direct_overrides.py
Zastępuje SubResource EnemyData w każdej Enemy_XXX.tscn
bezpośrednimi overrides właściwości na węźle głównym.
Uruchom raz: python tools/convert_to_direct_overrides.py
"""

import json
import os
import re

GALAXID     = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ENEMIES_JSON = os.path.join(GALAXID, "data", "enemies.json")
ENEMIES_DIR  = os.path.join(GALAXID, "scenes", "enemies")

# Właściwości do ustawienia i ich mapowanie JSON → nazwa @export w Enemy.gd
PROPS = [
    ("armor",   "armor",   1),
    ("esize",   "esize",   0),
    ("xmove",   "xmove",   0),
    ("ymove",   "ymove",   0),
    ("xaccel",  "xaccel",  0),
    ("yaccel",  "yaccel",  0),
    ("xcaccel", "excc",    0),   # JSON xcaccel -> GDScript excc
    ("ycaccel", "eycc",    0),   # JSON ycaccel -> GDScript eycc
    ("xrev",    "xrev",    0),
    ("yrev",    "yrev",    0),
    ("startx",  "startx",  0),
    ("starty",  "starty",  0),
    ("startxc", "startxc", 0),
]

def build_overrides(enemy: dict) -> str:
    lines = []
    for json_key, gd_key, default in PROPS:
        val = int(enemy.get(json_key, default))
        if val != default:          # pomiń wartości domyślne — krótsze pliki
            lines.append(f"{gd_key} = {val}")

    # tur i freq — zawsze wpisuj (bronie są istotne nawet gdy 0)
    tur  = [int(x) for x in enemy.get("tur",  [0, 0, 0])]
    freq = [int(x) for x in enemy.get("freq", [0, 0, 0])]
    if tur != [0, 0, 0]:
        lines.append(f"tur = [{', '.join(str(x) for x in tur)}]")
    if freq != [0, 0, 0]:
        lines.append(f"freq = [{', '.join(str(x) for x in freq)}]")

    return "\n".join(lines)


# Regex do usunięcia bloku sub_resource EnemyData
SUB_RESOURCE_PAT = re.compile(
    r'\[sub_resource type="(?:Resource|EnemyData)" id="EnemyData_[^"]*"\].*?(?=\n\[)',
    re.DOTALL
)
# Ext_resource dla skryptu EnemyData
EXT_SCRIPT_PAT = re.compile(
    r'\[ext_resource type="Script" path="res://scripts/resources/EnemyData\.gd"[^\]]*\]\n'
)
# Linia data = SubResource(...)
DATA_PROP_PAT = re.compile(r'^data = SubResource\("[^"]*"\)\n', re.MULTILINE)

# Węzeł główny (instance=)
MAIN_NODE_PAT = re.compile(
    r'(\[node name="[^"]*"[^\]]*instance=ExtResource\("[^"]*"\)\]\n)'
)


def convert_tscn(path: str, enemy: dict) -> bool:
    with open(path, encoding="utf-8") as f:
        src = f.read()

    original = src

    # 1. Usuń ext_resource dla skryptu EnemyData
    src = EXT_SCRIPT_PAT.sub("", src)

    # 2. Usuń sub_resource EnemyData (cały blok)
    src = SUB_RESOURCE_PAT.sub("", src)

    # 3. Usuń linię "data = SubResource(...)"
    src = DATA_PROP_PAT.sub("", src)

    # 4. Wstaw overrides bezpośrednio za linią [node ... instance=...]
    overrides = build_overrides(enemy)
    if overrides:
        insert = overrides + "\n"
        src = MAIN_NODE_PAT.sub(r'\g<1>' + insert, src, count=1)

    # Usuń podwójne puste linie po usunięciu bloków
    src = re.sub(r'\n{3,}', '\n\n', src)

    if src == original:
        return False

    with open(path, "w", encoding="utf-8") as f:
        f.write(src)
    return True


def main():
    with open(ENEMIES_JSON, encoding="utf-8") as f:
        enemies = json.load(f)
    by_id = {int(e.get("index", -1)): e for e in enemies}

    converted = skipped = missing = 0
    for fname in sorted(os.listdir(ENEMIES_DIR)):
        if not (fname.startswith("Enemy_") and fname.endswith(".tscn")):
            continue
        try:
            eid = int(fname[6:9])
        except ValueError:
            continue

        if eid not in by_id:
            print(f"WARN: brak danych dla ID={eid} ({fname})")
            missing += 1
            continue

        path = os.path.join(ENEMIES_DIR, fname)
        if convert_tscn(path, by_id[eid]):
            converted += 1
        else:
            skipped += 1

    print(f"Gotowe: {converted} przekonwertowanych, {skipped} bez zmian, {missing} brak w JSON")


if __name__ == "__main__":
    main()
