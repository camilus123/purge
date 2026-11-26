class_name MainMenu
extends Control
## Title screen: continue, new game (campaign or a single set, difficulty, save slot),
## load, settings, and in debug builds the endless test range.

signal new_game_requested(mode: String, set_id: String, difficulty: String, slot: int)
signal load_requested(slot: int)
signal test_range_requested
signal quit_requested
signal display_changed

var _pages: Dictionary = {}
var _continue: Button
var _continue_slot: int = -1
# New game choices
var _mode: String = "campaign"
var _set_id: String = ""
var _difficulty: String = "normal"
var _slot: int = 0
var _new_box: VBoxContainer
var _load_box: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.45)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_pages["home"] = _page_home()
	_pages["new"] = _page_new()
	_pages["load"] = _page_load()
	_pages["settings"] = _page_settings()
	for p: Control in _pages.values():
		center.add_child(p)
	show_page("home")


func _panel(width: float) -> Array:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(width, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	return [panel, box]


func show_page(name: String) -> void:
	for k: String in _pages:
		(_pages[k] as Control).visible = k == name
	match name:
		"home":
			_refresh_home()
		"new":
			_refresh_new()
		"load":
			_refresh_load()


func _page_home() -> Control:
	var p := _panel(460.0)
	var box: VBoxContainer = p[1]
	var title := UiTheme.label("PURGE", 64, UiTheme.ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var sub := UiTheme.label("a vertical shooter", 16, UiTheme.DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	box.add_child(HSeparator.new())
	_continue = UiTheme.button("Continue", func() -> void: load_requested.emit(_continue_slot), 52)
	box.add_child(_continue)
	box.add_child(UiTheme.button("New game", func() -> void: show_page("new"), 48))
	box.add_child(UiTheme.button("Load game", func() -> void: show_page("load"), 48))
	box.add_child(UiTheme.button("Settings", func() -> void: show_page("settings"), 48))
	if OS.is_debug_build():
		box.add_child(UiTheme.button("Test range (debug)", func() -> void: test_range_requested.emit(), 40))
	box.add_child(UiTheme.button("Quit", func() -> void: quit_requested.emit(), 44))
	return p[0]


func _refresh_home() -> void:
	# Continue loads the most recently saved run that is not finished.
	_continue_slot = -1
	var newest := ""
	for s: Dictionary in SaveSystem.list_slots():
		if s.get("empty", true) or not s.has("data"):
			continue
		var d: Dictionary = s["data"]
		if d.get("finished", false):
			continue
		if String(s["saved_at"]) > newest:
			newest = s["saved_at"]
			_continue_slot = s["slot"]
	_continue.visible = _continue_slot >= 0
	if _continue.visible:
		_continue.grab_focus.call_deferred()


func _page_new() -> Control:
	var p := _panel(620.0)
	_new_box = p[1]
	return p[0]


func _choice_row(box: VBoxContainer, title: String, options: Array, current: String, on_pick: Callable) -> void:
	box.add_child(UiTheme.label(title, 15, UiTheme.DIM))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	for o: Array in options:
		var value: String = o[0]
		var b := UiTheme.button(o[1], func() -> void: on_pick.call(value), 46)
		b.toggle_mode = true
		b.button_pressed = value == current
		b.disabled = o.size() > 2 and o[2] == false
		if o.size() > 3:
			b.tooltip_text = o[3]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
	box.add_child(row)


## Sets the player may start on their own: the first set always, later ones once the set
## before them is completed (or all of them when economy.json says unlock_all_sets).
func _unlocked_sets() -> Array:
	var econ := Data.load_dict("economy.json")
	var done: Array = SaveSystem.load_profile().get("completed_sets", [])
	var out: Array = []
	var prev_done := true
	for s: Dictionary in Data.sets:
		if s.get("hidden", false):
			continue
		var ok := prev_done or bool(econ.get("unlock_all_sets", false)) or OS.is_debug_build()
		out.append([s["id"], s.get("name", s["id"]), ok, "" if ok else "Complete the previous set to unlock it."])
		prev_done = s["id"] in done
	return out


func _refresh_new() -> void:
	for c in _new_box.get_children():
		c.queue_free()
	var title := UiTheme.label("NEW GAME", 30, UiTheme.ACCENT)
	_new_box.add_child(title)
	_choice_row(_new_box, "Mode", [["campaign", "Campaign (every set)"], ["single", "Single set"]], _mode,
			func(v: String) -> void:
				_mode = v
				_refresh_new())
	var sets := _unlocked_sets()
	if _mode == "single":
		if _set_id == "" and not sets.is_empty():
			_set_id = sets[0][0]
		_choice_row(_new_box, "Level set", sets, _set_id, func(v: String) -> void:
			_set_id = v
			_refresh_new())
	var diffs: Array = []
	for d: Dictionary in Data.load_dict("difficulty.json").get("levels", []):
		diffs.append([d["id"], d.get("name", d["id"])])
	_choice_row(_new_box, "Difficulty", diffs, _difficulty, func(v: String) -> void:
		_difficulty = v
		_refresh_new())
	var slots: Array = []
	for s: Dictionary in SaveSystem.list_slots():
		slots.append([str(s["slot"]), "Slot %d%s" % [int(s["slot"]) + 1, "" if s["empty"] else " (in use)"]])
	_choice_row(_new_box, "Save slot", slots, str(_slot), func(v: String) -> void:
		_slot = int(v)
		_refresh_new())
	var in_use: bool = not (SaveSystem.list_slots()[_slot] as Dictionary)["empty"]
	if in_use:
		_new_box.add_child(UiTheme.label("Starting will overwrite the game saved in this slot.", 15, UiTheme.WARN))
	_new_box.add_child(HSeparator.new())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var back := UiTheme.button("Back", func() -> void: show_page("home"), 50)
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(back)
	var start := UiTheme.button("Start", func() -> void:
		new_game_requested.emit(_mode, _set_id, _difficulty, _slot), 50)
	start.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(start)
	_new_box.add_child(row)
	start.grab_focus.call_deferred()


func _page_load() -> Control:
	var p := _panel(620.0)
	_load_box = p[1]
	return p[0]


func _refresh_load() -> void:
	for c in _load_box.get_children():
		c.queue_free()
	_load_box.add_child(UiTheme.label("LOAD GAME", 30, UiTheme.ACCENT))
	var set_names: Dictionary = {}
	for s: Dictionary in Data.sets:
		set_names[s["id"]] = s.get("name", s["id"])
	for s: Dictionary in SaveSystem.list_slots():
		var slot: int = s["slot"]
		var text := "Slot %d:  empty" % (slot + 1)
		var usable := false
		if s.has("data"):
			var d: Dictionary = s["data"]
			var ids: Array = d.get("set_ids", [])
			var pos := int(d.get("set_pos", 0))
			var where := "finished" if d.get("finished", false) else "%s, stage %d" % [
					set_names.get(ids[pos] if pos < ids.size() else "", "?"), int(d.get("level_index", 0)) + 1]
			text = "Slot %d:  %s  -  %s  -  %s  -  %s cr\n%s" % [slot + 1, "Campaign" if d.get("mode", "") == "campaign" else "Single set",
					String(d.get("difficulty", "")).capitalize(), where, UiTheme.format_int(int(d.get("credits", 0))), s["saved_at"]]
			usable = not d.get("finished", false)
		elif not s["empty"]:
			text = "Slot %d:  damaged save" % (slot + 1)
		var b := UiTheme.button(text, func() -> void: load_requested.emit(slot), 64)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.disabled = not usable
		_load_box.add_child(b)
	_load_box.add_child(HSeparator.new())
	_load_box.add_child(UiTheme.button("Back", func() -> void: show_page("home"), 48))


func _page_settings() -> Control:
	var p := _panel(520.0)
	var box: VBoxContainer = p[1]
	box.add_child(UiTheme.label("SETTINGS", 30, UiTheme.ACCENT))
	var s := SettingsPanel.new()
	s.display_changed.connect(func() -> void: display_changed.emit())
	box.add_child(s)
	box.add_child(HSeparator.new())
	box.add_child(UiTheme.button("Back", func() -> void:
		Settings.save_settings()
		show_page("home"), 48))
	return p[0]
