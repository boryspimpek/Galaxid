@tool
extends Control

const SETTING := "game/debug/start_dist"
const GAME_W   := 288
const LABEL_W  := 60
const BAR_H    := 12
const SPAWN_R  := 4.0
const MIN_SCALE := 0.02
const MAX_SCALE := 5.0

# Typy domyślnie ukryte (szum animacyjny, zwykle niepotrzebny w edytorze)
const DEFAULT_HIDDEN := ["enemy_global_accel", "enemy_global_move"]

var _spin_start:   SpinBox
var _spin_scale:   SpinBox
var _level_option: OptionButton
var _scroll:       ScrollContainer
var _timeline:     Control
var _detail:       RichTextLabel
var _filter_box:   HBoxContainer   # dynamiczne checkboxy filtrów

var _events:        Array      = []
var _max_dist:      int        = 0
var _selected:      int        = -1
var _event_draw:    Array      = []
var _visible_types: Dictionary = {}  # event_name -> bool

class _TL extends Control:
	var panel_ref: Control
	func _draw():       panel_ref._draw_tl()
	func _gui_input(e): panel_ref._tl_input(e)

# ---------------------------------------------------------------------------

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(vbox)
	_build_toolbar(vbox)
	_build_filter_bar(vbox)
	_build_main_area(vbox)
	_populate_levels()

# --- UI construction --------------------------------------------------------

func _build_toolbar(parent: Control) -> void:
	var top := HBoxContainer.new()
	top.custom_minimum_size.y = 28
	parent.add_child(top)

	_add_lbl(top, "Level:")
	_level_option = OptionButton.new()
	_level_option.custom_minimum_size.x = 90
	_level_option.item_selected.connect(_on_level_selected)
	top.add_child(_level_option)

	top.add_child(VSeparator.new())

	_add_lbl(top, "Start dist:")
	_spin_start = SpinBox.new()
	_spin_start.min_value = 0
	_spin_start.max_value = 99999
	_spin_start.step = 10
	_spin_start.value = ProjectSettings.get_setting(SETTING, 0)
	_spin_start.custom_minimum_size.x = 90
	_spin_start.value_changed.connect(func(_v): _timeline.queue_redraw())
	top.add_child(_spin_start)

	var b1 := Button.new()
	b1.text = "▶ Play from dist"
	b1.pressed.connect(_on_play_from)
	top.add_child(b1)

	var b2 := Button.new()
	b2.text = "▶ Play from start"
	b2.pressed.connect(_on_play_start)
	top.add_child(b2)

	top.add_child(VSeparator.new())

	_add_lbl(top, "Scale:")
	var bz_out := Button.new()
	bz_out.text = "−"
	bz_out.custom_minimum_size.x = 28
	bz_out.pressed.connect(func(): _zoom(1.0 / 1.5))
	top.add_child(bz_out)

	_spin_scale = SpinBox.new()
	_spin_scale.min_value = MIN_SCALE
	_spin_scale.max_value = MAX_SCALE
	_spin_scale.step = 0.01
	_spin_scale.value = 0.1
	_spin_scale.custom_minimum_size.x = 75
	_spin_scale.value_changed.connect(_on_scale_changed)
	top.add_child(_spin_scale)

	var bz_in := Button.new()
	bz_in.text = "+"
	bz_in.custom_minimum_size.x = 28
	bz_in.pressed.connect(func(): _zoom(1.5))
	top.add_child(bz_in)

func _build_filter_bar(parent: Control) -> void:
	# Poziomy scroll żeby nie pożerał wysokości gdy eventów jest dużo
	var sc := ScrollContainer.new()
	sc.custom_minimum_size.y = 26
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	parent.add_child(sc)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)
	sc.add_child(hbox)

	# Przyciski zbiorcze
	var btn_all := Button.new()
	btn_all.text = "Wszystkie"
	btn_all.custom_minimum_size.x = 70
	btn_all.pressed.connect(_on_filter_all.bind(true))
	hbox.add_child(btn_all)

	var btn_none := Button.new()
	btn_none.text = "Żaden"
	btn_none.custom_minimum_size.x = 55
	btn_none.pressed.connect(_on_filter_all.bind(false))
	hbox.add_child(btn_none)

	hbox.add_child(VSeparator.new())

	_filter_box = HBoxContainer.new()
	_filter_box.add_theme_constant_override("separation", 2)
	hbox.add_child(_filter_box)

func _add_lbl(parent: Control, text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	parent.add_child(lbl)

func _build_main_area(parent: Control) -> void:
	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.split_offset = 380
	parent.add_child(split)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	split.add_child(_scroll)

	var tl := _TL.new()
	tl.panel_ref    = self
	tl.mouse_filter = Control.MOUSE_FILTER_STOP
	_timeline = tl
	_scroll.add_child(_timeline)

	var pnl := PanelContainer.new()
	pnl.custom_minimum_size.x = 220
	split.add_child(pnl)

	_detail = RichTextLabel.new()
	_detail.bbcode_enabled        = true
	_detail.scroll_active         = true
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	pnl.add_child(_detail)

# --- Level loading ----------------------------------------------------------

func _populate_levels() -> void:
	_level_option.clear()
	var dir := DirAccess.open("res://data")
	if dir == null:
		return
	dir.list_dir_begin()
	var fn := dir.get_next()
	var files: Array[String] = []
	while fn != "":
		if fn.begins_with("lvl") and fn.ends_with(".json"):
			files.append(fn)
		fn = dir.get_next()
	dir.list_dir_end()
	files.sort()
	for f in files:
		_level_option.add_item(f.trim_suffix(".json"))
	var sel := 0
	for i in _level_option.item_count:
		if _level_option.get_item_text(i) == "lvl17":
			sel = i
			break
	if _level_option.item_count > 0:
		_level_option.select(sel)
		_load_level(_level_option.get_item_text(sel) + ".json")

func _load_level(filename: String) -> void:
	var path := "res://data/" + filename
	if not FileAccess.file_exists(path):
		return
	var f := FileAccess.open(path, FileAccess.READ)
	var json = JSON.parse_string(f.get_as_text())
	f.close()
	if json == null:
		return
	var key: String = (json as Dictionary).keys()[0]
	_events   = json[key].get("events", [])
	_max_dist = 0
	for ev in _events:
		if int(ev["dist"]) > _max_dist:
			_max_dist = int(ev["dist"])
	_selected = -1
	_detail.text = ""
	_populate_filter_bar()
	_rebuild_draw_data()

# --- Filter bar -------------------------------------------------------------

func _populate_filter_bar() -> void:
	for child in _filter_box.get_children():
		child.queue_free()
	_visible_types.clear()

	# Zbierz unikalne event_name w kolejności wystąpienia
	var seen: Dictionary = {}
	var names: Array[String] = []
	for ev in _events:
		var n: String = ev.get("event_name", "")
		if n != "" and not seen.has(n):
			seen[n] = true
			names.append(n)
	names.sort()

	for name in names:
		var visible: bool = name not in DEFAULT_HIDDEN
		_visible_types[name] = visible

		var btn := CheckButton.new()
		btn.text = name
		btn.button_pressed = visible
		btn.add_theme_font_size_override("font_size", 10)
		# Kolorowy pasek jako modulate ikony — prościej: tylko tekst
		btn.toggled.connect(func(on: bool): _on_filter_toggled(name, on))
		_filter_box.add_child(btn)

func _on_filter_toggled(event_name: String, visible: bool) -> void:
	_visible_types[event_name] = visible
	_rebuild_draw_data()

func _on_filter_all(visible: bool) -> void:
	for key in _visible_types.keys():
		_visible_types[key] = visible
	for child in _filter_box.get_children():
		if child is CheckButton:
			child.set_block_signals(true)
			child.button_pressed = visible
			child.set_block_signals(false)
	_rebuild_draw_data()

# --- Draw data --------------------------------------------------------------

func _rebuild_draw_data() -> void:
	_event_draw.clear()
	var scale: float = _spin_scale.value
	var ctx_count: Dictionary = {}

	for i in _events.size():
		var ev: Dictionary  = _events[i]
		var name: String    = ev.get("event_name", "")

		# Filtr — pomiń jeśli typ jest wyłączony
		if not _visible_types.get(name, true):
			continue

		var dist: int = int(ev["dist"])
		var y         := _dist_to_y(dist)

		if ev.get("category", "") == "spawn":
			var sx := LABEL_W + float(ev.get("screen_x", 0))
			_event_draw.append({"spawn": true, "cx": sx, "cy": y, "idx": i})
		else:
			if not ctx_count.has(dist):
				ctx_count[dist] = 0
			var bar_y := y - float(ctx_count[dist] + 1) * BAR_H
			ctx_count[dist] += 1
			_event_draw.append({
				"spawn": false,
				"rx": float(LABEL_W), "ry": bar_y,
				"rw": float(GAME_W),  "rh": float(BAR_H - 1),
				"idx": i
			})

	_timeline.custom_minimum_size = Vector2(
		LABEL_W + GAME_W + 20.0,
		_max_dist * scale + 100.0
	)
	_timeline.queue_redraw()

# --- Drawing ----------------------------------------------------------------

func _draw_tl() -> void:
	var font  := ThemeDB.fallback_font
	var fs    := 10
	var sz    := _timeline.size
	var scale := _spin_scale.value

	_timeline.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.13, 0.13, 0.13))
	_timeline.draw_line(Vector2(LABEL_W, 0), Vector2(LABEL_W, sz.y), Color(0.35, 0.35, 0.35))

	# Siatka
	var step := _grid_step(scale)
	var d    := 0
	while d <= _max_dist + step:
		var gy := _dist_to_y(d)
		_timeline.draw_line(
			Vector2(LABEL_W, gy), Vector2(sz.x, gy),
			Color(0.25, 0.25, 0.25, 0.7)
		)
		_timeline.draw_string(
			font, Vector2(2.0, gy - 2.0),
			str(d), HORIZONTAL_ALIGNMENT_LEFT, LABEL_W - 4, fs,
			Color(0.6, 0.6, 0.6)
		)
		d += step

	# Eventy
	for dd in _event_draw:
		var idx: int       = dd["idx"]
		var ev: Dictionary = _events[idx]
		var is_sel         := (idx == _selected)

		if dd["spawn"]:
			var cx: float = dd["cx"]
			var cy: float = dd["cy"]
			var col := _spawn_color(ev.get("enemy_id", 0))
			if is_sel:
				_timeline.draw_circle(Vector2(cx, cy), SPAWN_R + 2.5, Color.WHITE)
			_timeline.draw_circle(Vector2(cx, cy), SPAWN_R, col)
		else:
			var r   := Rect2(dd["rx"], dd["ry"], dd["rw"], dd["rh"])
			var col := _ctx_color(ev.get("event_name", ""))
			_timeline.draw_rect(r, col)
			if is_sel:
				_timeline.draw_rect(r, Color(1.0, 1.0, 0.0, 0.35))
			_timeline.draw_string(
				font, Vector2(r.position.x + 3.0, r.position.y + r.size.y - 2.0),
				ev.get("event_name", "?"),
				HORIZONTAL_ALIGNMENT_LEFT, int(r.size.x) - 6, fs - 1,
				Color.WHITE
			)

	# Marker start_dist
	var sd  := int(_spin_start.value)
	var sy  := _dist_to_y(sd)
	_timeline.draw_line(Vector2(0, sy), Vector2(sz.x, sy), Color(0.1, 0.9, 0.5, 0.9), 1.5)
	_timeline.draw_string(
		font, Vector2(2.0, sy + fs),
		str(sd), HORIZONTAL_ALIGNMENT_LEFT, LABEL_W - 4, fs,
		Color(0.1, 0.9, 0.5)
	)

func _dist_to_y(dist: int) -> float:
	return (_max_dist - dist) * _spin_scale.value

func _y_to_dist(y: float) -> int:
	var scale := _spin_scale.value
	return int(_max_dist - y / scale) if scale > 0.001 else 0

func _grid_step(scale: float) -> int:
	if scale >= 0.5: return 100
	if scale >= 0.1: return 500
	return 1000

func _spawn_color(eid: int) -> Color:
	const P := [
		Color(1.0, .35, .35), Color(.35, 1.0, .35), Color(.35, .55, 1.0),
		Color(1.0, 1.0, .35), Color(1.0, .55, .10), Color(.85, .35, 1.0),
		Color(.35, 1.0, 1.0), Color(1.0, .70, .70),
	]
	return P[eid % P.size()]

func _ctx_color(name: String) -> Color:
	match name:
		"scroll_speed":         return Color(.30, .60, 1.0, .85)
		"load_enemy_shapes":    return Color(1.0, .65, .10, .85)
		"disable_random_spawn": return Color(.90, .30, .90, .85)
		"enable_random_spawn":  return Color(.40, .90, .40, .85)
		"starfield":            return Color(.30, .80, .90, .85)
		"global_enemy_move":    return Color(.90, .70, .30, .85)
		_:                      return Color(.55, .55, .55, .85)

# --- Input ------------------------------------------------------------------

func _tl_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	if (event as InputEventMouseButton).button_index != MOUSE_BUTTON_LEFT:
		return

	var mp           := (event as InputEventMouseButton).position
	var clicked_dist := _y_to_dist(mp.y)
	_spin_start.value = snappedf(float(clicked_dist), 10.0)

	var best_idx   := -1
	var best_score := INF

	for dd in _event_draw:
		var idx: int = dd["idx"]
		if dd["spawn"]:
			var dx := mp.x - float(dd["cx"])
			var dy := mp.y - float(dd["cy"])
			var d  := sqrt(dx * dx + dy * dy)
			if d < 12.0 and d < best_score:
				best_score = d
				best_idx   = idx
		else:
			var r := Rect2(dd["rx"], dd["ry"], dd["rw"], dd["rh"])
			if r.has_point(mp) and best_score > 0.0:
				best_score = 0.0
				best_idx   = idx

	_selected = best_idx
	_show_detail(best_idx)
	_timeline.queue_redraw()

func _show_detail(idx: int) -> void:
	if idx < 0 or idx >= _events.size():
		_detail.text = ""
		return
	var ev: Dictionary = _events[idx]
	var bb := "[b][color=#ffdd88]" + str(ev.get("event_name", "?")) + "[/color][/b]\n\n"
	for k in ev.keys():
		bb += "[color=#888888]" + str(k) + ":[/color]  " + str(ev[k]) + "\n"
	_detail.parse_bbcode(bb)

# --- Playback ---------------------------------------------------------------

func _on_play_from() -> void:
	ProjectSettings.set_setting(SETTING, int(_spin_start.value))
	ProjectSettings.save()
	EditorInterface.play_main_scene()

func _on_play_start() -> void:
	ProjectSettings.set_setting(SETTING, 0)
	ProjectSettings.save()
	EditorInterface.play_main_scene()

func _on_level_selected(idx: int) -> void:
	_load_level(_level_option.get_item_text(idx) + ".json")

func _on_scale_changed(_v: float) -> void:
	_rebuild_draw_data()

func _zoom(factor: float) -> void:
	var old_scale    := _spin_scale.value
	var vp_h         := _scroll.size.y
	var center_y     := _scroll.scroll_vertical + vp_h * 0.5
	var center_dist  := _max_dist - center_y / old_scale
	_spin_scale.value = clampf(old_scale * factor, MIN_SCALE, MAX_SCALE)
	var new_center_y := (_max_dist - center_dist) * _spin_scale.value
	_scroll.call_deferred("set_scroll_vertical", maxi(int(new_center_y - vp_h * 0.5), 0))
