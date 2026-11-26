class_name PauseMenu
extends Control
## Pause menu with the handful of settings that matter for judging control feel.
## The full options menu comes in a later milestone.

signal resume_requested
signal restart_requested
signal quit_requested
signal shield_selected(shield_id: String)
signal display_changed

var _sens_label: Label
var _shield_ids: Array[String] = []


func build(shield_ids: Array[String], shield_names: Array[String], current_shield: String) -> void:
	_shield_ids = shield_ids
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(460, 0)
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)

	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	box.add_child(title)

	_button(box, "Resume", func() -> void: resume_requested.emit())
	_button(box, "Restart stage", func() -> void: restart_requested.emit())
	box.add_child(HSeparator.new())

	_sens_label = Label.new()
	box.add_child(_sens_label)
	var sens := HSlider.new()
	sens.min_value = 0.02
	sens.max_value = 0.3
	sens.step = 0.005
	sens.value = float(Settings.values["mouse_sensitivity"])
	sens.value_changed.connect(func(v: float) -> void:
		Settings.set_value("mouse_sensitivity", v)
		_update_sens_label())
	box.add_child(sens)
	_update_sens_label()

	_check(box, "Absolute mouse mode (ship follows the cursor)", String(Settings.values["mouse_mode"]) == "absolute",
			func(on: bool) -> void: Settings.set_value("mouse_mode", "absolute" if on else "relative"))
	_check(box, "Invert wheel direction", bool(Settings.values["invert_wheel"]),
			func(on: bool) -> void: Settings.set_value("invert_wheel", on))
	_check(box, "VSync", bool(Settings.values["vsync"]), func(on: bool) -> void:
		Settings.set_value("vsync", on)
		display_changed.emit())
	_check(box, "Glow", bool(Settings.values["glow"]), func(on: bool) -> void:
		Settings.set_value("glow", on)
		display_changed.emit())

	var row := HBoxContainer.new()
	var cap_label := Label.new()
	cap_label.text = "Framerate cap"
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
	box.add_child(row)

	var row2 := HBoxContainer.new()
	var sh_label := Label.new()
	sh_label.text = "Shield to try"
	sh_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row2.add_child(sh_label)
	var shields := OptionButton.new()
	for n in shield_names:
		shields.add_item(n)
	shields.selected = maxi(shield_ids.find(current_shield), 0)
	shields.item_selected.connect(func(i: int) -> void: shield_selected.emit(_shield_ids[i]))
	row2.add_child(shields)
	box.add_child(row2)

	box.add_child(HSeparator.new())
	_button(box, "Quit to desktop", func() -> void: quit_requested.emit())


func _update_sens_label() -> void:
	_sens_label.text = "Mouse sensitivity: %.3f" % float(Settings.values["mouse_sensitivity"])


func _button(parent: Control, text: String, on_press: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 40)
	b.pressed.connect(on_press)
	parent.add_child(b)


func _check(parent: Control, text: String, value: bool, on_toggle: Callable) -> void:
	var c := CheckButton.new()
	c.text = text
	c.button_pressed = value
	c.toggled.connect(on_toggle)
	parent.add_child(c)
