import json

# Read the JSON file
with open('data/lvl17.json', 'r', encoding='utf-8') as f:
    data = json.load(f)

# Filter out events with the unwanted event_names
original_count = len(data['lvl17']['events'])
data['lvl17']['events'] = [
    event for event in data['lvl17']['events']
    if event.get('event_name') not in ['enemy_global_accel', 'enemy_global_move']
]
new_count = len(data['lvl17']['events'])

# Write the modified JSON back to the file
with open('data/lvl17.json', 'w', encoding='utf-8') as f:
    json.dump(data, f, indent='\t', ensure_ascii=False)

print(f"Removed {original_count - new_count} events")
print(f"Original count: {original_count}")
print(f"New count: {new_count}")
