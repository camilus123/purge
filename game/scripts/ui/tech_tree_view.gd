class_name TechTreeView
extends Control
## Draws one category of the tech tree: a column per branch, a row per tier, a node per
## item, and lines from each item to its prerequisites. Node colours show the shop state.

signal item_selected(id: String)

const NODE := Vector2(196, 74)
const GAP := Vector2(26, 34)

var _positions: Dictionary = {}   # id -> Rect2
var _items: Dictionary = {}
var _run: RunState
var _buttons: Dictionary = {}
var _selected: String = ""


## Rebuilds the nodes for `category`. Branch columns follow the order items appear in the data.
func show_category(category: String, items: Dictionary, run: RunState) -> void:
	_items = items
	_run = run
	for c in get_children():
		c.queue_free()
	_buttons.clear()
	_positions.clear()
	var branches: Array = []
	var ids: Array = []
	for id: String in items:
		var it: Dictionary = items[id]
		if it.get("category", "") != category:
			continue
		ids.append(id)
		var b: String = it.get("branch", "")
		if not b in branches:
			branches.append(b)
	var max_tier := 1
	for id: String in ids:
		var it: Dictionary = items[id]
		var col := branches.find(it.get("branch", ""))
		var row := int(it.get("tier", 1)) - 1
		max_tier = maxi(max_tier, row + 1)
		var pos := Vector2(col * (NODE.x + GAP.x), row * (NODE.y + GAP.y)) + Vector2(10, 10)
		_positions[id] = Rect2(pos, NODE)
		var btn := Button.new()
		btn.position = pos
		btn.size = NODE
		btn.clip_text = true
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(func() -> void:
			Sfx.play_asset("sfx.ui.click")
			item_selected.emit(id))
		add_child(btn)
		_buttons[id] = btn
	custom_minimum_size = Vector2(branches.size() * (NODE.x + GAP.x) + 20, max_tier * (NODE.y + GAP.y) + 20)
	refresh()


func select(id: String) -> void:
	_selected = id
	refresh()


## Updates every node's text and colour from the run (after buying, selling or equipping).
func refresh() -> void:
	for id: String in _buttons:
		var btn: Button = _buttons[id]
		var it: Dictionary = _items[id]
		var st := ShopRules.state(_run, _items, id)
		var line2 := "%s cr" % UiTheme.format_int(int(it.get("cost", 0)))
		var fill := Color(0.07, 0.1, 0.16)
		var border := Color(UiTheme.ACCENT, 0.35)
		var font := UiTheme.TEXT
		match st:
			ShopRules.EQUIPPED:
				line2 = "EQUIPPED " + _slot_names(id)
				fill = Color(0.05, 0.2, 0.3)
				border = UiTheme.ACCENT
			ShopRules.OWNED:
				line2 = "OWNED"
				fill = Color(0.06, 0.16, 0.1)
				border = UiTheme.GOOD
			ShopRules.TOO_EXPENSIVE:
				font = UiTheme.WARN
			ShopRules.LOCKED:
				font = UiTheme.DIM
				border = Color(UiTheme.DIM, 0.3)
				fill = Color(0.04, 0.05, 0.08)
			ShopRules.EXCLUDED:
				line2 = "OTHER BRANCH CHOSEN"
				font = Color(UiTheme.BAD, 0.7)
				border = Color(UiTheme.BAD, 0.35)
				fill = Color(0.07, 0.04, 0.05)
		var width := 1
		if id == _selected:
			border = Color.WHITE
			width = 3
		btn.text = "%s\n%s" % [it.get("name", id), line2]
		for state_name: String in ["normal", "hover", "pressed", "focus"]:
			var box := UiTheme.box(fill.lightened(0.08) if state_name == "hover" else fill, border, width, 6, 8.0)
			btn.add_theme_stylebox_override(state_name, box)
		btn.add_theme_color_override("font_color", font)
		btn.add_theme_color_override("font_hover_color", font.lightened(0.2))
		btn.add_theme_font_size_override("font_size", 16)
	queue_redraw()


func _slot_names(id: String) -> String:
	var names := {"weapon1": "LMB", "weapon2": "RMB"}
	var out: Array = []
	for s: String in RunState.SLOTS:
		if _run.equipped[s] == id and names.has(s):
			out.append(names[s])
	return " ".join(out)


func _draw() -> void:
	for id: String in _positions:
		var to: Rect2 = _positions[id]
		for req: String in (_items[id] as Dictionary).get("requires", []):
			if not _positions.has(req):
				continue
			var from: Rect2 = _positions[req]
			var a := Vector2(from.get_center().x, from.end.y)
			var b := Vector2(to.get_center().x, to.position.y)
			var owned := _run.owned.has(req)
			var col := Color(UiTheme.ACCENT, 0.7) if owned else Color(UiTheme.DIM, 0.35)
			var mid := (a.y + b.y) * 0.5
			draw_polyline(PackedVector2Array([a, Vector2(a.x, mid), Vector2(b.x, mid), b]), col, 2.0, true)
