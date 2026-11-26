class_name EndScreen
extends Control
## Shown when the last stage of a set or the campaign is cleared: the run's statistics.

signal done

var _title: Label
var _grid: GridContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var m := UiTheme.modal(600.0, 0.6)
	add_child(m[0])
	var box: VBoxContainer = m[1]
	_title = UiTheme.label("", 34, UiTheme.ACCENT)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)
	box.add_child(HSeparator.new())
	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", 40)
	_grid.add_theme_constant_override("v_separation", 8)
	box.add_child(_grid)
	box.add_child(HSeparator.new())
	box.add_child(UiTheme.button("Main menu", func() -> void: done.emit(), 52))


func open(title: String, run: RunState) -> void:
	_title.text = title
	for c in _grid.get_children():
		c.queue_free()
	var st := run.stats
	var acc := 0.0
	if int(st["shots_fired"]) > 0:
		acc = 100.0 * float(st["shots_hit"]) / float(st["shots_fired"])
	var secs := int(st["play_time"])
	var rows := [
		["Difficulty", run.difficulty.capitalize()],
		["Stages cleared", str(st["stages_cleared"])],
		["Enemies destroyed", UiTheme.format_int(int(st["kills"]))],
		["Accuracy", "%d%%" % roundi(acc)],
		["Ships lost", str(st["deaths"])],
		["Credits earned", UiTheme.format_int(int(st["credits_earned"]))],
		["Tech owned", str(run.owned.size())],
		["Play time", "%d:%02d:%02d" % [secs / 3600, (secs / 60) % 60, secs % 60]],
	]
	for r: Array in rows:
		_grid.add_child(UiTheme.label(r[0], 18, UiTheme.DIM))
		_grid.add_child(UiTheme.label(r[1], 18))
