class_name DebugOverlay
extends Control
## F3 performance overlay: fps, frame-time graph, simulation cost, entity counts, draw calls.

const SAMPLES := 300

var sim: GameSim
var world_viewport: SubViewport
var frame_ms: PackedFloat32Array
var head: int = 0
var sim_ms: float = 0.0      # smoothed simulation cost per rendered frame
var view_ms: float = 0.0     # smoothed presentation script cost per rendered frame

var _font: Font
var _text_timer: float = 0.0
var _draw_timer: float = 0.0
var _lines: PackedStringArray = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame_ms.resize(SAMPLES)
	_font = ThemeDB.fallback_font
	custom_minimum_size = Vector2(380, 250)
	size = custom_minimum_size


func push_frame(ms: float) -> void:
	frame_ms[head] = ms
	head = (head + 1) % SAMPLES


func _process(delta: float) -> void:
	if not visible:
		return
	_text_timer -= delta
	if _text_timer <= 0.0:
		_text_timer = 0.25
		_refresh_text()
	# The graph is redrawn 20 times a second so the overlay itself does not distort the numbers.
	_draw_timer -= delta
	if _draw_timer <= 0.0:
		_draw_timer = 0.05
		queue_redraw()


func _refresh_text() -> void:
	var sum := 0.0
	var worst := 0.0
	for v in frame_ms:
		sum += v
		worst = maxf(worst, v)
	var avg := sum / SAMPLES
	var draw_calls := 0
	var prims := 0
	if world_viewport != null:
		var rid := world_viewport.get_viewport_rid()
		draw_calls = RenderingServer.viewport_get_render_info(rid,
				RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
		prims = RenderingServer.viewport_get_render_info(rid,
				RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)
	var win := get_window().size
	var vp := world_viewport.size if world_viewport != null else Vector2i.ZERO
	_lines = PackedStringArray([
		"%d fps   avg %.2f ms   worst %.2f ms" % [Engine.get_frames_per_second(), avg, worst],
		"sim %.2f ms   view %.2f ms   (%d ticks/s)" % [sim_ms, view_ms, Engine.physics_ticks_per_second],
		"enemies %d   bullets %d + %d" % [sim.enemy_count, sim.pbul.count, sim.ebul.count],
		"draw calls %d   primitives %d" % [draw_calls, prims],
		"window %dx%d   playfield %dx%d" % [win.x, win.y, vp.x, vp.y],
		"%s  %s" % [RenderingServer.get_current_rendering_driver_name(), RenderingServer.get_video_adapter_name()],
	])


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.72))
	var y := 22.0
	for line in _lines:
		draw_string(_font, Vector2(10, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.8, 1.0, 0.8))
		y += 19.0

	# Frame-time graph: full height = 8.33 ms; the green line is the 240 fps budget (4.17 ms).
	var g := Rect2(10, y + 4.0, size.x - 20.0, size.y - y - 14.0)
	draw_rect(g, Color(1, 1, 1, 0.06))
	var scale_ms := 8.333
	var budget_y := g.position.y + g.size.y * (1.0 - 4.167 / scale_ms)
	draw_line(Vector2(g.position.x, budget_y), Vector2(g.end.x, budget_y), Color(0.3, 1.0, 0.4, 0.7), 1.0)
	var bar_w := g.size.x / SAMPLES
	for i in SAMPLES:
		var v := frame_ms[(head + i) % SAMPLES]
		var h := minf(v / scale_ms, 1.0) * g.size.y
		var c := Color(0.4, 0.9, 1.0) if v <= 4.167 else (Color(1.0, 0.8, 0.2) if v <= 8.333 else Color(1.0, 0.3, 0.2))
		draw_rect(Rect2(g.position.x + i * bar_w, g.end.y - h, maxf(bar_w, 1.0), h), c)
