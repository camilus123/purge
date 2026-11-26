class_name UiTheme
extends RefCounted
## The shared look of every menu: dark panels with a cyan accent, matching the HUD.

const BG := Color(0.035, 0.045, 0.07)
const PANEL := Color(0.05, 0.065, 0.1, 0.96)
const ACCENT := Color(0.2, 0.75, 1.0)
const TEXT := Color(0.82, 0.9, 1.0)
const DIM := Color(0.45, 0.55, 0.68)
const GOOD := Color(0.45, 0.95, 0.55)
const BAD := Color(1.0, 0.35, 0.3)
const WARN := Color(1.0, 0.75, 0.3)


static func box(fill: Color, border: Color = Color(0, 0, 0, 0), width: int = 0, radius: int = 4, pad: float = 10.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad * 0.6
	s.content_margin_bottom = pad * 0.6
	return s


static func build() -> Theme:
	var t := Theme.new()
	t.default_font_size = 18
	t.set_color("font_color", "Label", TEXT)
	t.set_stylebox("panel", "PanelContainer", box(PANEL, Color(ACCENT, 0.35), 1, 6, 18.0))
	t.set_stylebox("panel", "Panel", box(PANEL, Color(ACCENT, 0.35), 1, 6))

	for cls: String in ["Button", "OptionButton"]:
		t.set_stylebox("normal", cls, box(Color(0.07, 0.1, 0.16), Color(ACCENT, 0.35), 1))
		t.set_stylebox("hover", cls, box(Color(0.09, 0.15, 0.24), ACCENT, 1))
		t.set_stylebox("pressed", cls, box(Color(0.12, 0.25, 0.38), ACCENT, 2))
		t.set_stylebox("disabled", cls, box(Color(0.05, 0.06, 0.09), Color(DIM, 0.25), 1))
		t.set_stylebox("focus", cls, box(Color(0, 0, 0, 0), Color(ACCENT, 0.8), 2))
		t.set_color("font_color", cls, TEXT)
		t.set_color("font_hover_color", cls, Color.WHITE)
		t.set_color("font_pressed_color", cls, Color.WHITE)
		t.set_color("font_disabled_color", cls, Color(DIM, 0.6))
	t.set_color("font_color", "CheckButton", TEXT)
	t.set_color("font_hover_color", "CheckButton", Color.WHITE)
	t.set_stylebox("normal", "CheckButton", box(Color(0, 0, 0, 0)))
	t.set_stylebox("hover", "CheckButton", box(Color(1, 1, 1, 0.04)))
	t.set_stylebox("pressed", "CheckButton", box(Color(0, 0, 0, 0)))
	t.set_stylebox("focus", "CheckButton", box(Color(0, 0, 0, 0), Color(ACCENT, 0.6), 1))
	t.set_stylebox("slider", "HSlider", box(Color(0.1, 0.13, 0.19), Color(0, 0, 0, 0), 0, 3, 3.0))
	t.set_stylebox("grabber_area", "HSlider", box(Color(ACCENT, 0.7), Color(0, 0, 0, 0), 0, 3, 3.0))
	t.set_stylebox("grabber_area_highlight", "HSlider", box(ACCENT, Color(0, 0, 0, 0), 0, 3, 3.0))
	t.set_stylebox("separator", "HSeparator", box(Color(ACCENT, 0.25), Color(0, 0, 0, 0), 0, 0, 0.0))
	t.set_constant("separation", "HSeparator", 12)
	t.set_stylebox("panel", "PopupMenu", box(Color(0.06, 0.08, 0.12), ACCENT, 1))
	t.set_stylebox("hover", "PopupMenu", box(Color(0.12, 0.25, 0.38)))
	t.set_color("font_color", "PopupMenu", TEXT)
	t.set_stylebox("panel", "ScrollContainer", box(Color(0, 0, 0, 0)))
	t.set_stylebox("panel", "TooltipPanel", box(Color(0.05, 0.07, 0.11), ACCENT, 1))
	return t


## A plain label with a size and colour.
static func label(text: String, size: int = 18, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func button(text: String, on_press: Callable, min_height: float = 44.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, min_height)
	b.pressed.connect(func() -> void:
		Sfx.play_asset("sfx.ui.click")
		on_press.call())
	return b


## A full-screen dimmed layer with a centred panel; returns [root, content VBox].
static func modal(min_width: float, dim: float = 0.65) -> Array:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, dim)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(min_width, 0)
	center.add_child(panel)
	var box_v := VBoxContainer.new()
	box_v.add_theme_constant_override("separation", 10)
	panel.add_child(box_v)
	return [root, box_v]


static func format_int(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.right(3) + out
		s = s.left(s.length() - 3)
	return ("-" if n < 0 else "") + s + out
