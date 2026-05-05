import json
import sys

# Kolejność kluczy per event_name (na podstawie event_model.json)
KEY_ORDERS = {
    "scroll_speed":          ["dist", "category", "event_name", "event_type", "back_move", "back_move2", "back_move3"],
    "starfield":             ["dist", "category", "event_name", "event_type", "star_active"],
    "starfield_speed":       ["dist", "category", "event_name", "event_type", "starfield_speed"],
    "disable_random_spawn":  ["dist", "category", "event_name", "event_type", "enemies_active"],
    "enable_random_spawn":   ["dist", "category", "event_name", "event_type", "enemies_active"],
    "global_enemy_move":     ["dist", "category", "event_name", "event_type", "link_num", "new_exc", "new_eyc", "new_fixed_move_y", "scope_selector"],
    "global_enemy_accel":    ["dist", "category", "event_name", "event_type", "link_num", "new_excc", "new_eycc"],
    "global_enemy_accelrev": ["dist", "category", "event_name", "event_type", "link_num", "new_exrev", "new_eyrev"],
    "small_enemy_adjust":    ["dist", "category", "event_name", "event_type", "small_enemy_adjust"],
    "enemy_fire_override":   ["dist", "category", "event_name", "event_type", "link_num", "new_freq"],
    "enemy_fire_power":      ["dist", "category", "event_name", "event_type", "link_num", "new_tur", "new_freq"],
    "enemy_from_enemy":      ["dist", "category", "event_name", "event_type", "link_num", "spawn_on_death_id"],
    "assign_special_enemy":  ["dist", "category", "event_name", "event_type", "link_num", "dat", "dat2", "dat4"],
    "enemy_continual_damage":["dist", "category", "event_name", "event_type"],
    "spawn_ground":          ["dist", "enemy_id", "category", "event_name", "event_type", "link_num", "screen_x", "screen_y"],
    "spawn_top":             ["dist", "enemy_id", "category", "event_name", "event_type", "link_num", "screen_x", "screen_y"],
    "spawn_sky":             ["dist", "enemy_id", "category", "event_name", "event_type", "link_num", "screen_x", "screen_y"],
    "spawn_enemy":           ["dist", "enemy_id", "category", "event_name", "event_type", "vel_x", "vel_y", "link_num", "screen_x", "screen_y", "y_vel"],
    "spawn_sky_bottom":      ["dist", "enemy_id", "category", "event_name", "event_type", "link_num", "screen_x", "screen_y"],
    "spawn_sky_bottom2":     ["dist", "enemy_id", "category", "event_name", "event_type", "link_num", "screen_x", "screen_y"],
    "spawn_free_enemy":      ["dist", "enemy_id", "category", "event_name", "event_type", "vel_x", "vel_y", "link_num", "screen_x", "screen_y"],
    "spawn_free_4x4":        ["dist", "category", "event_name", "event_type", "enemy_ids", "vel_x", "vel_y", "link_num", "screen_x", "screen_y"],
    "spawn_group_enemy":     ["dist", "category", "event_name", "event_type", "vel_x", "vel_y", "link_num", "screen_x", "screen_y", "enemy_id"],
    "spawn_formation":       ["dist", "enemy_id", "category", "event_name", "event_type", "vel_x", "vel_y", "link_num", "screen_x", "screen_y"],
    "spawn_path_enemy":      ["dist", "enemy_id", "category", "event_name", "event_type", "path", "link_num", "screen_x", "screen_y"],
    "just_spawn_enemy":      ["dist", "enemy_id", "category", "event_name", "event_type", "vel_x", "vel_y", "link_num", "screen_x", "screen_y"],
    "spawn_enemy_special":   ["dist", "enemy_id", "category", "event_name", "event_type", "vel_x", "vel_y", "link_num", "screen_x", "screen_y"],
    "spawn_ground_2":        ["dist", "enemy_id", "category", "event_name", "event_type", "link_num", "screen_x", "screen_y"],
    "spawn_ground2_bottom":  ["dist", "enemy_id", "category", "event_name", "event_type", "link_num", "screen_x", "screen_y"],
    "path_enemy":            ["dist", "enemy_id", "category", "event_name", "event_type", "path", "link_num", "screen_x", "screen_y"],
}

FALLBACK_PREFIX = ["dist", "category", "event_name", "event_type"]


def reorder_event(event):
    event_name = event.get("event_name", "")
    order = KEY_ORDERS.get(event_name, FALLBACK_PREFIX)
    result = {}
    for key in order:
        if key in event:
            result[key] = event[key]
    for key in event:
        if key not in result:
            result[key] = event[key]
    return result


def serialize_value(value, depth):
    if isinstance(value, bool):
        return "true" if value else "false"
    if value is None:
        return "null"
    if isinstance(value, str):
        return json.dumps(value, ensure_ascii=False)
    if isinstance(value, float):
        # Preserve float representation (60.0 stays 60.0, not 60)
        r = repr(value)
        # Python repr may produce e.g. "60.0" or "1e-05"; keep as-is
        return r
    if isinstance(value, int):
        return str(value)
    if isinstance(value, list):
        # Simple list (all scalars) → one line
        if all(isinstance(item, (bool, int, float, str, type(None))) for item in value):
            items = [serialize_value(item, 0) for item in value]
            return "[" + ", ".join(items) + "]"
        # Complex list → multi-line
        tab = "\t" * depth
        tab1 = "\t" * (depth + 1)
        items = [tab1 + serialize_value(item, depth + 1) for item in value]
        return "[\n" + ",\n".join(items) + "\n" + tab + "]"
    if isinstance(value, dict):
        return serialize_dict(value, depth)
    return json.dumps(value, ensure_ascii=False)


def serialize_dict(d, depth):
    if not d:
        return "{}"
    tab = "\t" * depth
    tab1 = "\t" * (depth + 1)
    lines = []
    items = list(d.items())
    for i, (key, value) in enumerate(items):
        comma = "," if i < len(items) - 1 else ""
        val_str = serialize_value(value, depth + 1)
        lines.append(f'{tab1}{json.dumps(key)}: {val_str}{comma}')
    return "{\n" + "\n".join(lines) + "\n" + tab + "}"


def main():
    path = r"C:\Users\borys\projekty\Galaxid\data\lvl17.json"

    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)

    level_key = list(data.keys())[0]
    level_data = data[level_key]

    events = level_data["events"]

    # Stable sort by dist
    events_sorted = sorted(events, key=lambda e: int(e.get("dist", 0)))

    # Reorder keys per schema
    events_reordered = [reorder_event(e) for e in events_sorted]

    level_data["events"] = events_reordered

    # Serialize
    output = serialize_value(data, 0)

    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(output)
        f.write("\n")

    print(f"OK: {len(events_reordered)} events posortowanych i poukładanych.")

    # Wykryj event_names bez zdefiniowanego schematu
    unknown = set()
    for e in events_reordered:
        name = e.get("event_name", "")
        if name not in KEY_ORDERS:
            unknown.add(name)
    if unknown:
        print(f"UWAGA: brak schematu dla: {sorted(unknown)}")


if __name__ == "__main__":
    main()
