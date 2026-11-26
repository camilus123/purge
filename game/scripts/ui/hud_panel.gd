class_name HudPanel
extends Control
## One of the two HUD side panels beside the playfield.
## Built from retained nodes (labels and colour rects) that are only touched when
## their value changes, so the HUD costs almost nothing per frame at 240 fps.

const COL_W := 320.0
const PAD := 36.0
const C_BG := Color(0.035, 0.045, 0.07)
const C_FRAME := Color(0.2, 0.75, 1.0)
const C_TEXT := Color(0.82, 0.9, 1.0)
const C_DIM := Color(0.45, 0.55, 0.68)
const C_ARMOR := Color(0.95, 0.75, 0.25)
const C_SHIELD := Color(0.25, 0.65, 1.0)
const C_WEAPON := Color(1.0, 0.5, 0.15)
const C_ENERGY := Color(0.55, 0.95, 0.5)
const C_BAD := Color(1.0, 0.25, 0.2)
const C_TRACK := Color(0.1, 0.13, 0.19)
const TEXT_INTERVAL := 0.1   # seconds between number/text refreshes

var sim: GameSim
var is_left: bool = true
var power_flash: float = 0.0   # set to 1 when the split changes, fades out

var _column: VBoxContainer
var _text_timer: float = 0.0
var _last_split: float = -1.0

# Left panel widgets
var _armor_bar: ColorRect
var _armor_val: Label
var _shield_bar: ColorRect
var _shield_name: Label
var _shield_val: Label
var _reactor_val: Label
var _split_shield: ColorRect
var _split_marker: ColorRect
var _split_flash: ReferenceRect
var _split_left: Label
var _split_right: Label
var _pool_bar: ColorRect
var _pool_val: Label
var _weapon_rows: Array = []   # per weapon: [name Label, status Label, bar ColorRect, note Label]
var _weapon_box: VBoxContainer

# Right panel widgets
var _stat_values: Dictionary = {}
var _status: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	var bg := ColorRect.new()
	bg.color = C_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	# Bright frame line and a soft glow along the playfield edge.
	var glow := ColorRect.new()
	glow.color = Color(C_FRAME, 0.08)
	var edge := ColorRect.new()
	edge.color = Color(C_FRAME, 0.9)
	for r: ColorRect in [glow, edge]:
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var w := 14.0 if r == glow else 3.0
		if is_left:
			r.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
			r.offset_left = -w
		else:
			r.set_anchors_preset(Control.PRESET_LEFT_WIDE)
			r.offset_right = w
		add_child(r)

	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation", 4)
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_column)
	if is_left:
		_build_left()
	else:
		_build_right()
	resized.connect(_place_column)
	_place_column()
	refresh_loadout()


func _place_column() -> void:
	var w := minf(COL_W, size.x - PAD * 2.0)
	_column.visible = w > 120.0
	_column.size = Vector2(w, size.y - 60.0)
	_column.position = Vector2(size.x - PAD - w if is_left else PAD, 26.0)


# ---------------------------------------------------------------- construction

func _label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _spacer(h: float) -> void:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, h)
	_column.add_child(s)


func _title(text: String) -> void:
	_column.add_child(_label(text, 30, C_FRAME))
	var line := ColorRect.new()
	line.color = Color(C_FRAME, 0.5)
	line.custom_minimum_size = Vector2(0, 2)
	_column.add_child(line)
	_spacer(14)


## A "NAME ........ value" row. Returns [left Label, right Label].
func _row(left: String, right: String, parent: Control = null, right_size: int = 13, right_col: Color = C_DIM) -> Array:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var a := _label(left, 14, C_TEXT)
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var b := _label(right, right_size, right_col)
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(a)
	row.add_child(b)
	(parent if parent != null else _column).add_child(row)
	return [a, b]


## A horizontal bar. Returns the fill rect; set its anchor_right to the fraction.
func _bar(color: Color, h: float, parent: Control = null) -> ColorRect:
	var track := ColorRect.new()
	track.color = C_TRACK
	track.custom_minimum_size = Vector2(0, h)
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := ColorRect.new()
	fill.color = color
	fill.anchor_bottom = 1.0
	fill.anchor_right = 1.0
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_child(fill)
	(parent if parent != null else _column).add_child(track)
	return fill


func _build_left() -> void:
	_title("PURGE")
	_armor_val = _row("ARMOR", "")[1]
	_armor_bar = _bar(C_ARMOR, 20)
	_spacer(6)
	var sr := _row("SHIELD", "")
	_shield_name = sr[0]
	_shield_val = sr[1]
	_shield_bar = _bar(C_SHIELD, 20)
	_spacer(16)

	_reactor_val = _row("REACTOR POWER", "")[1]
	# Power split gauge: shields fill from the left, weapons from the right.
	var gauge := ColorRect.new()
	gauge.color = Color(C_WEAPON, 0.85)
	gauge.custom_minimum_size = Vector2(0, 34)
	gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_split_shield = ColorRect.new()
	_split_shield.color = Color(C_SHIELD.r, C_SHIELD.g, C_SHIELD.b, 1.0)
	_split_shield.anchor_bottom = 1.0
	_split_shield.anchor_right = 0.5
	gauge.add_child(_split_shield)
	for i in range(1, 10):
		var tick := ColorRect.new()
		tick.color = Color(C_BG, 0.9)
		tick.anchor_left = i / 10.0
		tick.anchor_right = i / 10.0
		tick.anchor_bottom = 1.0
		tick.offset_left = -1.0
		tick.offset_right = 1.0
		gauge.add_child(tick)
	_split_marker = ColorRect.new()
	_split_marker.color = Color.WHITE
	_split_marker.anchor_bottom = 1.0
	_split_marker.offset_left = -2.0
	_split_marker.offset_right = 2.0
	_split_marker.offset_top = -5.0
	_split_marker.offset_bottom = 5.0
	gauge.add_child(_split_marker)
	_split_flash = ReferenceRect.new()
	_split_flash.editor_only = false
	_split_flash.border_width = 3.0
	_split_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_split_flash.offset_left = -4.0
	_split_flash.offset_top = -4.0
	_split_flash.offset_right = 4.0
	_split_flash.offset_bottom = 4.0
	_split_flash.visible = false
	gauge.add_child(_split_flash)
	_column.add_child(gauge)
	_spacer(4)
	var pr := _row("", "", null, 18, C_WEAPON)
	_split_left = pr[0]
	_split_left.add_theme_font_size_override("font_size", 18)
	_split_left.add_theme_color_override("font_color", C_SHIELD)
	_split_right = pr[1]
	var hint := _row("wheel down", "wheel up", null, 12)
	(hint[0] as Label).add_theme_font_size_override("font_size", 12)
	(hint[0] as Label).add_theme_color_override("font_color", C_DIM)
	_spacer(16)

	_pool_val = _row("WEAPON ENERGY", "")[1]
	_pool_bar = _bar(C_ENERGY, 16)
	_spacer(12)
	_weapon_box = VBoxContainer.new()
	_weapon_box.add_theme_constant_override("separation", 3)
	_column.add_child(_weapon_box)
	_spacer(10)
	_row("MMB  SPECIAL", "not fitted")


func _build_right() -> void:
	_title("TEST RANGE")
	for key: String in ["SCORE", "CREDITS", "KILLS", "ACCURACY", "WAVE LOOP"]:
		var r := _row(key, "0", null, 24, C_TEXT)
		(r[0] as Label).add_theme_color_override("font_color", C_DIM)
		_stat_values[key] = r[1]
		var line := ColorRect.new()
		line.color = Color(1, 1, 1, 0.08)
		line.custom_minimum_size = Vector2(0, 1)
		_column.add_child(line)
	_spacer(20)
	_status = _label("", 20, C_BAD)
	_column.add_child(_status)
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_column.add_child(fill)
	var help := _label("\n".join([
		"Mouse  -  fly",
		"LMB / RMB  -  weapon 1 / weapon 2",
		"Wheel  -  shift power",
		"MMB  -  special",
		"Esc  -  pause and settings",
		"F3  -  performance overlay",
		"F4 / F5  -  stress test / invincible",
	]), 13, C_DIM)
	help.add_theme_constant_override("line_spacing", 6)
	_column.add_child(help)


## Rebuilds the parts that depend on the equipped items. Call after a loadout change.
func refresh_loadout() -> void:
	if sim == null or not is_left or _weapon_box == null:
		return
	for c in _weapon_box.get_children():
		c.queue_free()
	_weapon_rows.clear()
	var buttons := ["LMB", "RMB"]
	for i in sim.player.weapons.size():
		var wp := sim.player.weapons[i]
		var r := _row("%s  %s" % [buttons[i], wp.name.to_upper()], "", _weapon_box, 13, C_BAD)
		var bar := _bar(C_WEAPON, 10, _weapon_box)
		var note := _label("heat" if wp.heat_capacity > 0.0 else "", 11, C_DIM)
		_weapon_box.add_child(note)
		_weapon_rows.append([r[0], r[1], bar, note])
	_shield_name.text = "SHIELD  " + sim.player.shield_name.to_upper()
	_reactor_val.text = "%d MW" % int(sim.player.reactor_output)
	_text_timer = 0.0


# ---------------------------------------------------------------- updates

func _set_frac(bar: ColorRect, frac: float) -> void:
	frac = clampf(frac, 0.0, 1.0)
	if absf(bar.anchor_right - frac) > 0.002:
		bar.anchor_right = frac


func _set_text(l: Label, text: String) -> void:
	if l.text != text:
		l.text = text


func _process(delta: float) -> void:
	if sim == null or not _column.visible:
		return
	_text_timer -= delta
	var update_text := _text_timer <= 0.0
	if update_text:
		_text_timer = TEXT_INTERVAL
	if is_left:
		_update_left(delta, update_text)
	elif update_text:
		_update_right()


func _update_left(delta: float, update_text: bool) -> void:
	var p := sim.player
	var armor_frac := p.armor / maxf(p.armor_max, 1.0)
	_set_frac(_armor_bar, armor_frac)
	var shield_frac := 0.0
	if p.shield_max > 0.0:
		shield_frac = p.shield / p.shield_max
	_set_frac(_shield_bar, shield_frac)
	_set_frac(_pool_bar, p.pool / maxf(p.pool_max, 1.0))

	var s := p.shield_share
	if absf(_last_split - s) > 0.0005:
		_last_split = s
		_split_shield.anchor_right = s
		_split_marker.anchor_left = s
		_split_marker.anchor_right = s
		_split_left.text = "SHIELDS %d%%" % roundi(s * 100.0)
		_split_right.text = "WEAPONS %d%%" % roundi((1.0 - s) * 100.0)
	if power_flash > 0.0:
		power_flash = maxf(0.0, power_flash - delta * 3.0)
		_split_flash.visible = power_flash > 0.0
		_split_flash.border_color = Color(1, 1, 1, power_flash * 0.85)

	var share := 1.0 - s
	for i in mini(_weapon_rows.size(), p.weapons.size()):
		var wp := p.weapons[i]
		var row: Array = _weapon_rows[i]
		var bar: ColorRect = row[2]
		if wp.heat_capacity > 0.0:
			_set_frac(bar, wp.heat / wp.heat_capacity)
		else:
			_set_frac(bar, wp.current_damage(share) / maxf(wp.damage * wp.dmg_scale_1, 0.001))

	if not update_text:
		return
	# Low armor blinks red.
	var low := armor_frac < 0.3 and fmod(Time.get_ticks_msec() / 1000.0, 0.5) < 0.25
	_armor_bar.color = C_BAD if low else C_ARMOR
	_set_text(_armor_val, "%d / %d" % [ceili(p.armor), int(p.armor_max)])
	var shield_note := "%d / %d" % [ceili(p.shield), int(p.shield_max)]
	if p.shield_timer > 0.0 and p.shield < p.shield_max:
		shield_note = "recharge in %.1fs   %s" % [p.shield_timer, shield_note]
	_set_text(_shield_val, shield_note)
	_set_text(_pool_val, "%d / %d" % [int(p.pool), int(p.pool_max)])
	for i in mini(_weapon_rows.size(), p.weapons.size()):
		var wp := p.weapons[i]
		var row: Array = _weapon_rows[i]
		var status := ""
		if wp.overheated:
			status = "OVERHEATED"
		elif wp.starved:
			status = "LOW POWER"
		_set_text(row[1], status)
		var bar: ColorRect = row[2]
		if wp.heat_capacity > 0.0:
			bar.color = C_BAD if wp.overheated else C_WEAPON.lerp(C_BAD, wp.heat / wp.heat_capacity)
		else:
			bar.color = C_SHIELD.lerp(C_WEAPON, share)
			_set_text(row[3], "output %d%%" % roundi(wp.current_damage(share) / maxf(wp.damage, 0.001) * 100.0))


func _update_right() -> void:
	_set_text(_stat_values["SCORE"], str(sim.score))
	_set_text(_stat_values["CREDITS"], str(sim.credits))
	_set_text(_stat_values["KILLS"], str(sim.kills))
	var acc := 0.0
	if sim.shots_fired > 0:
		acc = 100.0 * sim.shots_hit / sim.shots_fired
	_set_text(_stat_values["ACCURACY"], "%d%%" % roundi(acc))
	_set_text(_stat_values["WAVE LOOP"], str(sim.loop_index + 1))
	var status := ""
	if sim.state == GameSim.STATE_DEAD:
		status = "SHIP DESTROYED\nrestarting stage..."
	if sim.stress:
		status += "\nSTRESS TEST (F4)"
	if sim.invincible:
		status += "\nINVINCIBLE (F5)"
	_set_text(_status, status.strip_edges())
