"""
Reads Tyrian\data\lvl17.json and injects all spawn events into
Galaxid\scenes\world\World.tscn as Enemy_NNN nodes under LevelMap.

Writes result to World.tscn (backs up original as World.tscn.bak first).
"""

import json
import os
import re
import random

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LVL_JSON  = os.path.join(ROOT, r"..\Tyrian\data\lvl17.json")
WORLD     = os.path.join(ROOT, r"scenes\world\World.tscn")
ENEMIES   = os.path.join(ROOT, r"scenes\enemies")

# ── 1. Load spawn events ────────────────────────────────────────────────────
with open(LVL_JSON, encoding="utf-8") as f:
    data = json.load(f)

spawns = [e for e in data["lvl17"]["events"] if e.get("category") == "spawn"]
unique_eids = sorted(set(e["enemy_id"] for e in spawns))
print(f"Spawn events : {len(spawns)}")
print(f"Unique enemy IDs: {unique_eids}")

# ── 2. Read UID from each enemy scene file ──────────────────────────────────
enemy_uid = {}   # enemy_id -> "uid://..." or None (file exists but no uid)
missing = []
for eid in unique_eids:
    path = os.path.join(ENEMIES, f"Enemy_{eid:03d}.tscn")
    if not os.path.exists(path):
        missing.append(eid)
        continue
    with open(path, encoding="utf-8") as f:
        line = f.readline()
    m = re.search(r'uid="(uid://[^"]+)"', line)
    enemy_uid[eid] = m.group(1) if m else None  # None = no uid, file still usable

if missing:
    print(f"WARNING – no scene file for enemy IDs: {missing}")
no_uid = [eid for eid, uid in enemy_uid.items() if uid is None]
if no_uid:
    print(f"INFO – scene exists but no uid (will use path-only ref): {sorted(no_uid)}")

# ── 3. Read World.tscn ──────────────────────────────────────────────────────
with open(WORLD, encoding="utf-8") as f:
    content = f.read()

# ── 4. Collect already-used IDs and existing enemy path→res_id map ──────────
used_res_ids   = set(re.findall(r'\bid="([^"]+)"', content))
used_node_uids = set(int(x) for x in re.findall(r'unique_id=(\d+)', content))
existing_paths = set(re.findall(r'path="([^"]+)"', content))

ext_resource_map = {}  # enemy_id -> res_id string
for m in re.finditer(
    r'\[ext_resource[^\]]+path="res://scenes/enemies/Enemy_(\d+)\.tscn"[^\]]+id="([^"]+)"',
    content
):
    ext_resource_map[int(m.group(1))] = m.group(2)

# ── 5. Build new ext_resource lines ────────────────────────────────────────
new_ext_lines = []
res_counter = 200

for eid in unique_eids:
    if eid not in enemy_uid:
        continue  # file not found at all
    enemy_path = f"res://scenes/enemies/Enemy_{eid:03d}.tscn"
    if enemy_path in existing_paths:
        # Already declared – grab its id
        m = re.search(
            rf'\[ext_resource[^\]]+path="{re.escape(enemy_path)}"[^\]]+id="([^"]+)"',
            content,
        )
        if m:
            ext_resource_map[eid] = m.group(1)
        continue

    while f"e{res_counter}_{eid:03d}" in used_res_ids:
        res_counter += 1
    res_id = f"e{res_counter}_{eid:03d}"
    used_res_ids.add(res_id)
    ext_resource_map[eid] = res_id
    uid_attr = f' uid="{enemy_uid[eid]}"' if enemy_uid[eid] else ""
    new_ext_lines.append(
        f'[ext_resource type="PackedScene"{uid_attr}'
        f' path="{enemy_path}" id="{res_id}"]'
    )
    res_counter += 1

# ── 6. Build new node lines ─────────────────────────────────────────────────
def fresh_uid():
    while True:
        uid = random.randint(100_000_000, 999_999_999)
        if uid not in used_node_uids:
            used_node_uids.add(uid)
            return uid

instance_count = {}
new_node_lines = []

for spawn in spawns:
    eid = spawn["enemy_id"]
    if eid not in ext_resource_map:
        continue

    dist     = spawn["dist"]
    screen_x = spawn["screen_x"]
    screen_y = spawn["screen_y"]
    pos_x = screen_x * 4 + 100
    pos_y = -(dist + screen_y) * 4

    instance_count[eid] = instance_count.get(eid, 0) + 1
    node_name = f"Enemy_{eid:03d}_{instance_count[eid]}"
    res_id    = ext_resource_map[eid]

    new_node_lines.append(
        f'[node name="{node_name}" parent="LevelMap"'
        f' unique_id={fresh_uid()} instance=ExtResource("{res_id}")]\n'
        f"position = Vector2({pos_x}, {pos_y})\n"
        f"screen_y = {pos_y}"
    )

# ── 7. Splice into World.tscn ───────────────────────────────────────────────
# Godot TSCN order: ext_resource → sub_resource → node
# Insert new ext_resources before the first [sub_resource] (or [node] if none)
first_sub_match  = re.search(r'\n\[sub_resource ', content)
first_node_match = re.search(r'\n\[node ', content)
if first_sub_match:
    insert_ext_at = first_sub_match.start()
elif first_node_match:
    insert_ext_at = first_node_match.start()
else:
    insert_ext_at = len(content)

# Insert enemy nodes just before [node name="CanvasLayer"
canvas_match = re.search(r'\n\[node name="CanvasLayer"', content)
insert_nodes_at = canvas_match.start() if canvas_match else len(content)

ext_block   = ("\n" + "\n".join(new_ext_lines)) if new_ext_lines else ""
nodes_block = "\n\n" + "\n\n".join(new_node_lines) if new_node_lines else ""

new_content = (
    content[:insert_ext_at]
    + ext_block
    + content[insert_ext_at:insert_nodes_at]
    + nodes_block
    + "\n"
    + content[insert_nodes_at:]
)

# ── 8. Backup + write ───────────────────────────────────────────────────────
bak = WORLD + ".bak"
if not os.path.exists(bak):
    import shutil
    shutil.copy2(WORLD, bak)
    print(f"Backup: {bak}")

with open(WORLD, "w", encoding="utf-8") as f:
    f.write(new_content)

print(f"\nDone.")
print(f"  New ext_resources : {len(new_ext_lines)}")
print(f"  New enemy nodes   : {len(new_node_lines)}")
print(f"  Skipped (no scene): {missing}")
print(f"\nWorld.tscn updated. Open in Godot to verify.")
