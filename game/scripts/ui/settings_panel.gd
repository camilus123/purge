class_name SettingsPanel
extends VBoxContainer
## The settings that are adjustable today (the full options menu arrives in Milestone 8).
## Used by the pause menu and the main menu. Changes apply at once and are saved by the caller.

signal display_changed


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	var sens_label := UiTheme.label("", 16)
	add_child(sens_label)
	var sens := HSlider.new()
	sens.min_value = 0.02
	sens.max_value = 0.3
	sens.step = 0.005
	sens.value = float(Settings.values["mouse_sensitivity"])
	var update_sens := func() -> void:
		sens_label.text = "Mouse sensitivity: %.3f" % float(Settings.values["mouse_sensitivity"])
	sens.value_changed.connect(func(v: float) -> void:
		Settings.set_value("mouse_sensitivity", v)
		update_sens.call())
	update_sens.call()
	add_child(sens)

	_slider("Master volume", "volume_master", 0.0, 1.0)
	_slider("Effects volume", "volume_sfx", 0.0, 1.0)
	_slider("Screen shake", "screen_shake", 0.0, 1.5)

	_check("Absolute mouse mode (ship follows the cursor)", "mouse_mode", func(on: bool) -> void:
		Settings.set_value("mouse_mode", "absolute" if on else "relative"), String(Settings.values["mouse_mode"]) == "absolute")
	_check("Invert wheel direction", "invert_wheel", func(on: bool) -> void: Settings.set_value("invert_wheel", on))
	_check("VSync", "vsync", func(on: bool) -> void:
		Settings.set_value("vsync", on)
		display_changed.emit())
	_check("Glow", "glow", func(on: bool) -> void:
		Settings.set_value("glow", on)
		display_changed.emit())

	var row := HBoxContainer.new()
	var cap_label := UiTheme.label("Framerate cap", 16)
	cap_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(cap_label)
	var caps := OptionButton.new()
	var cap_values := [0, 60, 120, 144, 165, 240]
	for c: int in cap_values:
		caps.add_item("Uncapped" if c == 0 else str(c))
	caps.selected = maxi(cap_values.find(int(Settings.values["fps_cap"])), 0)
	caps.item_selected.connect(func(i: int) -> void:
		Settings.set_value("fps_cap", cap_values[i])
		display_changed.emit())
	row.add_child(caps)
	add_child(row)


func _slider(title: String, key: String, lo: float, hi: float) -> void:
	var l := UiTheme.label("", 16)
	add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 0.05
	s.value = float(Settings.values[key])
	var update := func() -> void:
		l.text = "%s: %d%%" % [title, roundi(float(Settings.values[key]) * 100.0)]
	s.value_changed.connect(func(v: float) -> void:
		Settings.set_value(key, v)
		update.call())
	update.call()
	add_child(s)


func _check(text: String, key: String, on_toggle: Callable, value: Variant = null) -> void:
	var c := CheckButton.new()
	c.text = text
	c.button_pressed = bool(Settings.values[key]) if value == null else bool(value)
	c.toggled.connect(on_toggle)
	add_child(c)
