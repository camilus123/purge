class_name ResultsScreen
extends Control
## After a stage: each credit line appears in turn, then the total.

signal continue_requested

var _title: Label
var _grid: GridContainer
var _total: Label
var _continue: Button
var _lines: Array = []
var _shown: int = 999
var _timer: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var m := UiTheme.modal(640.0, 0.5)
	add_child(m[0])
	var box: VBoxContainer = m[1]
	_title = UiTheme.label("", 32, UiTheme.ACCENT)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)
	box.add_child(HSeparator.new())
	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.add_theme_constant_override("h_separation", 30)
	_grid.add_theme_constant_override("v_separation", 8)
	box.add_child(_grid)
	box.add_child(HSeparator.new())
	_total = UiTheme.label("", 30, UiTheme.GOOD)
	_total.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(_total)
	_continue = UiTheme.button("Continue", func() -> void: continue_requested.emit(), 52)
	box.add_child(_continue)


func open(title: String, results: Dictionary) -> void:
	_title.text = title
	for c in _grid.get_children():
		c.queue_free()
	_lines = results["lines"]
	_shown = 0
	_timer = 0.4
	_total.text = ""
	_total.set_meta("total", int(results["total"]))
	_continue.grab_focus.call_deferred()


func _process(delta: float) -> void:
	if not visible or _shown > _lines.size():
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = 0.18
	if _shown < _lines.size():
		var l: Array = _lines[_shown]
		_grid.add_child(UiTheme.label(l[0], 18))
		_grid.add_child(UiTheme.label(l[1], 18, UiTheme.DIM))
		var amount := UiTheme.label(("+" if int(l[2]) >= 0 else "") + UiTheme.format_int(int(l[2])), 18,
				UiTheme.GOOD if int(l[2]) > 0 else UiTheme.DIM)
		amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		amount.custom_minimum_size = Vector2(110, 0)
		_grid.add_child(amount)
		Sfx.play_asset("sfx.ui.click", 0.6, 1.0 + _shown * 0.05)
	else:
		_total.text = "Credits earned:  %s" % UiTheme.format_int(int(_total.get_meta("total")))
		Sfx.play_asset("sfx.ui.buy")
	_shown += 1
