extends Node
## Game loop for the Milestone 2 playable core. Feeds input into the fixed-step
## simulation, lets the view draw an interpolated frame, and lays out the screen:
## a fixed-aspect playfield in the centre with HUD panels on both sides.
##
## Command line (after `--`): --windowed, --level=<set id>/<number>, --bench[=seconds], --light,
## --demo, --stress, --set=<key>=<value>, --shot=<png path>, --shot-delay=<seconds>

var sim: GameSim
var view: WorldView
var world_viewport: SubViewport
var playfield: TextureRect
var hud_left: HudPanel
var hud_right: HudPanel
var overlay: DebugOverlay
var pause_menu: PauseMenu

var paused: bool = false
var _mouse_accum: Vector2 = Vector2.ZERO
var _field_rect: Rect2
var _loadout_ids: Dictionary = {}
var _set: Dictionary = {}        # the level set being played
var _level_index: int = 0
var _level_arg: String = ""
var _data_errors: int = 0
var _sim_usec: int = 0
var _tick_dt: float = 1.0 / 240.0

# Command-line modes
var _demo: bool = false
var _bench: bool = false
var _bench_seconds: float = 12.0
var _bench_warmup: float = 4.0
var _bench_frames: PackedFloat32Array = []
var _bench_bullets: int = 0
var _bench_light: bool = false
var _bench_script_usec: int = 0
var _bench_over_budget: int = 0
var _ticks_this_frame: int = 0
var _prev_stats: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0]
var _proc_end_usec: int = 0
var _tick_end_usec: int = 0
var _gap_a: int = 0
var _gap_b: int = 0
var _slow := {"n": 0, "sim": 0.0, "view": 0.0, "ticks": 0.0, "frame": 0.0}
var _fast := {"n": 0, "sim": 0.0, "view": 0.0, "ticks": 0.0, "frame": 0.0}
var _gpu_world: float = 0.0
var _cpu_world: float = 0.0
var _gpu_ui: float = 0.0
var _cpu_ui: float = 0.0
var _shot_path: String = ""
var _shot_delay: float = 6.0
var _elapsed: float = 0.0
var _force_windowed: bool = false
var _last_usec: int = 0
var _mouse_reapply: int = 41   # frames; re-applies at 40, 30, 20, 10 and 0
var _no_save: bool = false   # command-line overrides must not end up in the saved settings


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_parse_args()
	Input.use_accumulated_input = false
	_tick_dt = 1.0 / Engine.physics_ticks_per_second

	if _force_windowed:
		Settings.values["window_mode"] = "windowed"
	Settings.apply_display()

	if OS.is_debug_build():
		_validate_data()
	sim = GameSim.new()
	_loadout_ids = (Data.load_dict("economy.json").get("starting_loadout", {}) as Dictionary).duplicate()
	_pick_start_level()
	sim.setup(_build_config())
	sim.set_power_step(float(Settings.values["power_step"]))
	if _bench and not _bench_light:
		sim.stress = true

	_build_screen()
	get_viewport().size_changed.connect(_layout)
	Settings.changed.connect(_on_settings_changed)
	_layout()
	_set_paused(false)
	_last_usec = Time.get_ticks_usec()
	if _bench:
		RenderingServer.viewport_set_measure_render_time(world_viewport.get_viewport_rid(), true)
		RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)


func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		_no_save = true
		if arg == "--windowed":
			_force_windowed = true
		elif arg == "--demo":
			_demo = true
		elif arg == "--stress":
			_demo = true
			_bench_warmup = -1.0
		elif arg.begins_with("--level="):
			_level_arg = arg.get_slice("=", 1)
		elif arg == "--light":
			_bench_light = true
		elif arg.begins_with("--bench"):
			# Uncapped by default; a later --set=fps_cap=... or --set=vsync=true overrides this.
			if not _bench:
				Settings.values["vsync"] = false
				Settings.values["fps_cap"] = 0
			_bench = true
			_demo = true
			if arg.contains("="):
				_bench_seconds = float(arg.get_slice("=", 1))
		elif arg.begins_with("--set="):
			# --set=key=value overrides one setting for this run, e.g. --set=msaa=0
			var key := arg.get_slice("=", 1)
			var raw := arg.get_slice("=", 2)
			if Settings.values.has(key):
				var cur: Variant = Settings.values[key]
				if cur is bool:
					Settings.values[key] = raw == "true" or raw == "1"
				elif cur is int:
					Settings.values[key] = int(raw)
				elif cur is float:
					Settings.values[key] = float(raw)
				else:
					Settings.values[key] = raw
		elif arg.begins_with("--shot="):
			_shot_path = arg.get_slice("=", 1)
		elif arg.begins_with("--shot-delay="):
			_shot_delay = float(arg.get_slice("=", 1))


## Runs the data validator and prints what it finds (debug builds, and after a hot reload).
func _validate_data() -> void:
	var validator := DataValidator.new()
	validator.run(Data)
	_data_errors = validator.errors.size()
	for e in validator.errors:
		push_error("DATA: " + e)
		print("DATA ERROR: ", e)
	for w in validator.warnings:
		print("DATA WARNING: ", w)
	print("Data check: ", validator.summary())


## Start level: --level=<set id>/<number>, else the test range for benchmarks, else the first set.
func _pick_start_level() -> void:
	_level_index = 0
	_set = {}
	if _level_arg != "":
		_set = Data.find_set(_level_arg.get_slice("/", 0))
		_level_index = maxi(int(_level_arg.get_slice("/", 1)) - 1, 0)
		if _set.is_empty():
			push_warning("Unknown level set in --level=%s" % _level_arg)
	elif _bench:
		_set = Data.find_set("sandbox")
	if _set.is_empty():
		for s: Dictionary in Data.sets:
			if not s.get("hidden", false):
				_set = s
				break
	if _set.is_empty() and not Data.sets.is_empty():
		_set = Data.sets[0]


func _build_config() -> Dictionary:
	return {
		"power": Data.load_dict("tech/power_model.json"),
		"ship": Data.load_dict("tech/ship.json"),
		"reactor": Data.item(_loadout_ids.get("reactor", "")),
		"shield": Data.item(_loadout_ids.get("shield", "")),
		"armor": Data.item(_loadout_ids.get("armor", "")),
		"weapon1": Data.item(_loadout_ids.get("weapon1", "")),
		"weapon2": Data.item(_loadout_ids.get("weapon2", "")),
		"enemies": Data.items_with_prefix("enemy."),
		"movement": Data.movement,
		"attack": Data.attack,
		"level": Data.load_level(_set, _level_index),
	}


## Loads the current level into the simulation and refreshes everything that depends on it.
func _start_level() -> void:
	var was_stress := sim.stress
	var was_invincible := sim.invincible
	sim.setup(_build_config())
	sim.stress = was_stress
	sim.invincible = was_invincible
	view.refresh_sprite_table()
	view.refresh_loadout()
	view.rebuild_background()
	hud_left.refresh_loadout()
	_update_hud_title()


func _update_hud_title() -> void:
	hud_right.set_title(sim.level_name.to_upper())
	hud_right.data_errors = _data_errors


## Moves through every level of every set, in order (debug level select).
func _change_level(step: int) -> void:
	var set_i := Data.sets.find(_set)
	_level_index += step
	if _level_index >= (_set.get("levels", []) as Array).size():
		set_i = posmod(set_i + 1, Data.sets.size())
		_set = Data.sets[set_i]
		_level_index = 0
	elif _level_index < 0:
		set_i = posmod(set_i - 1, Data.sets.size())
		_set = Data.sets[set_i]
		_level_index = (_set.get("levels", []) as Array).size() - 1
	_start_level()


## Re-reads every data and asset file without restarting the game (debug builds, F6).
func _hot_reload() -> void:
	var set_id: String = _set.get("id", "")
	Data.reload()
	Assets.reload()
	_validate_data()
	_set = Data.find_set(set_id)
	if _set.is_empty():
		_pick_start_level()
	view.reset_models()
	_start_level()
	print("Data reloaded")


func _build_screen() -> void:
	world_viewport = SubViewport.new()
	world_viewport.own_world_3d = true
	world_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	world_viewport.msaa_3d = int(Settings.values["msaa"]) as Viewport.MSAA
	world_viewport.use_hdr_2d = false
	world_viewport.positional_shadow_atlas_size = 0
	add_child(world_viewport)
	view = WorldView.new()
	world_viewport.add_child(view)
	view.setup(sim)

	var ui := Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui)

	playfield = TextureRect.new()
	playfield.texture = world_viewport.get_texture()
	playfield.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	playfield.stretch_mode = TextureRect.STRETCH_SCALE
	playfield.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(playfield)

	hud_left = HudPanel.new()
	hud_left.sim = sim
	hud_left.is_left = true
	ui.add_child(hud_left)
	hud_right = HudPanel.new()
	hud_right.sim = sim
	hud_right.is_left = false
	ui.add_child(hud_right)

	overlay = DebugOverlay.new()
	overlay.sim = sim
	overlay.world_viewport = world_viewport
	overlay.position = Vector2(8, 8)
	overlay.visible = _bench
	ui.add_child(overlay)

	var shield_ids: Array[String] = []
	var shield_names: Array[String] = []
	for id: String in Data.items:
		if id.begins_with("shield."):
			shield_ids.append(id)
			shield_names.append(Data.items[id].get("name", id))
	pause_menu = PauseMenu.new()
	pause_menu.build(shield_ids, shield_names, _loadout_ids.get("shield", ""))
	pause_menu.resume_requested.connect(func() -> void: _set_paused(false))
	pause_menu.restart_requested.connect(func() -> void:
		sim.restart()
		_set_paused(false))
	pause_menu.quit_requested.connect(_quit)
	pause_menu.shield_selected.connect(_on_shield_selected)
	pause_menu.display_changed.connect(_apply_display)
	ui.add_child(pause_menu)
	_update_hud_title()


func _layout() -> void:
	var vs := get_viewport().get_visible_rect().size
	var aspect := WorldView.playfield_aspect()
	var h := vs.y
	var w := h * aspect
	if w > vs.x:
		w = vs.x
		h = w / aspect
	_field_rect = Rect2((vs.x - w) * 0.5, (vs.y - h) * 0.5, w, h)
	playfield.position = _field_rect.position
	playfield.size = _field_rect.size
	hud_left.position = Vector2.ZERO
	hud_left.size = Vector2(_field_rect.position.x, vs.y)
	hud_right.position = Vector2(_field_rect.end.x, 0)
	hud_right.size = Vector2(vs.x - _field_rect.end.x, vs.y)

	# Render the playfield at real pixel size (times render scale), not at UI size.
	var px_per_unit := float(get_window().size.y) / vs.y
	var rs := clampf(float(Settings.values["render_scale"]), 0.25, 2.0)
	world_viewport.size = Vector2i(maxi(16, roundi(w * px_per_unit * rs)), maxi(16, roundi(h * px_per_unit * rs)))


func _apply_display() -> void:
	Settings.apply_display()
	view.environment.glow_enabled = bool(Settings.values["glow"])
	_layout()


func _on_settings_changed() -> void:
	if not paused:
		_update_mouse_mode()


func _on_shield_selected(shield_id: String) -> void:
	_loadout_ids["shield"] = shield_id
	_start_level()


func _update_mouse_mode() -> void:
	if paused or _demo:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif String(Settings.values["mouse_mode"]) == "absolute":
		Input.mouse_mode = Input.MOUSE_MODE_CONFINED_HIDDEN
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _set_paused(p: bool) -> void:
	paused = p
	pause_menu.visible = p
	_mouse_accum = Vector2.ZERO
	_update_mouse_mode()
	if not p and not _no_save:
		Settings.save_settings()


func _quit() -> void:
	if not _no_save:
		Settings.save_settings()
	get_tree().quit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and sim != null and not _demo:
		_set_paused(true)
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN and sim != null and not paused:
		_mouse_reapply = 3
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		_quit()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if not paused and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			# screen_relative is raw mouse movement, unaffected by UI scaling.
			_mouse_accum += (event as InputEventMouseMotion).screen_relative
		return
	if event.is_action_pressed("pause"):
		_set_paused(not paused)
	elif event.is_action_pressed("debug_overlay"):
		overlay.visible = not overlay.visible
	elif paused:
		return
	elif event.is_action_pressed("power_weapons"):
		sim.shift_power(-1 if Settings.values["invert_wheel"] else 1)
	elif event.is_action_pressed("power_shields"):
		sim.shift_power(1 if Settings.values["invert_wheel"] else -1)
	elif event.is_action_pressed("special"):
		sim.fire_special()
	elif event.is_action_pressed("debug_stress"):
		sim.stress = not sim.stress
	elif event.is_action_pressed("debug_invincible"):
		sim.invincible = not sim.invincible
	elif event.is_action_pressed("debug_next_level"):
		_change_level(1)
	elif event.is_action_pressed("debug_prev_level"):
		_change_level(-1)
	elif event.is_action_pressed("debug_reload") and OS.is_debug_build():
		_hot_reload()


func _physics_process(delta: float) -> void:
	if paused:
		return
	if _demo:
		sim.invincible = true
		sim.in_absolute = true
		sim.in_target = Vector2(sin(sim.time * 0.9) * 30.0, 34.0 + sin(sim.time * 0.37) * 10.0)
		sim.in_fire_1 = true
		sim.in_fire_2 = fmod(sim.time, 6.0) < 4.0
	else:
		sim.in_absolute = String(Settings.values["mouse_mode"]) == "absolute"
		if sim.in_absolute:
			sim.in_target = _mouse_on_playfield()
		else:
			sim.in_move = _mouse_accum * float(Settings.values["mouse_sensitivity"])
		_mouse_accum = Vector2.ZERO
		sim.in_fire_1 = Input.is_action_pressed("fire_1")
		sim.in_fire_2 = Input.is_action_pressed("fire_2")
	var t0 := Time.get_ticks_usec()
	if _ticks_this_frame == 0:
		_gap_a = t0 - _proc_end_usec
	sim.step(delta)
	_tick_end_usec = Time.get_ticks_usec()
	_sim_usec += _tick_end_usec - t0
	_ticks_this_frame += 1


## Where the mouse cursor points on the gameplay plane (absolute mouse mode).
func _mouse_on_playfield() -> Vector2:
	var m := get_viewport().get_mouse_position()
	var u := (m.x - _field_rect.position.x) / _field_rect.size.x
	var v := (m.y - _field_rect.position.y) / _field_rect.size.y
	var pt := Vector2(u * world_viewport.size.x, v * world_viewport.size.y)
	var origin := view.camera.project_ray_origin(pt)
	var dir := view.camera.project_ray_normal(pt)
	if absf(dir.y) < 0.0001:
		return Vector2(sim.player.x, sim.player.y)
	var t := -origin.y / dir.y
	return Vector2(origin.x + dir.x * t, origin.z + dir.z * t)


func _process(delta: float) -> void:
	var now := Time.get_ticks_usec()
	if _ticks_this_frame == 0:
		_gap_a = now - _proc_end_usec
		_gap_b = 0
	else:
		_gap_b = now - _tick_end_usec
	var frame_ms := (now - _last_usec) / 1000.0
	_last_usec = now
	overlay.push_frame(frame_ms)
	overlay.sim_ms = lerpf(overlay.sim_ms, _sim_usec / 1000.0, 0.05)
	if _bench and _elapsed >= _bench_warmup:
		_bench_script_usec += _sim_usec
	var sim_usec_frame := _sim_usec
	var ticks_frame := _ticks_this_frame
	_ticks_this_frame = 0
	_sim_usec = 0

	# A cleared stage rolls on to the next level of the set after a short pause.
	# (The results screen and shop take over this hand-off in Milestone 4.)
	if sim.state == GameSim.STATE_CLEAR and sim.clear_time > 3.5 and not paused:
		_change_level(1)

	var t0 := Time.get_ticks_usec()
	_drain_events()
	var alpha := Engine.get_physics_interpolation_fraction()
	view.render(alpha if not paused else 1.0, delta, _tick_dt, not paused)
	var view_usec := Time.get_ticks_usec() - t0
	overlay.view_ms = lerpf(overlay.view_ms, view_usec / 1000.0, 0.05)
	if _bench and _elapsed >= _bench_warmup:
		_bench_script_usec += view_usec
		# frame_ms measured now is the length of the previous frame, so bucket the previous frame's numbers.
		var b: Dictionary = _slow if frame_ms > 4.6 else _fast
		b["n"] += 1
		b["sim"] += _prev_stats[0]
		b["view"] += _prev_stats[1]
		b["ticks"] += _prev_stats[2]
		b["frame"] += frame_ms
		_prev_stats[0] = sim_usec_frame / 1000.0
		_prev_stats[1] = view_usec / 1000.0
		_prev_stats[2] = ticks_frame
		b["gap_a"] = b.get("gap_a", 0.0) + _prev_stats[3]
		b["gap_b"] = b.get("gap_b", 0.0) + _prev_stats[4]
		_prev_stats[3] = _gap_a / 1000.0
		_prev_stats[4] = _gap_b / 1000.0

	_elapsed += delta
	# The OS can ignore a cursor capture requested before the window is fully up or focused,
	# so the mouse mode is applied again shortly after start and after regaining focus.
	if _mouse_reapply > 0:
		_mouse_reapply -= 1
		if _mouse_reapply % 10 == 0 and not paused and not _demo:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			_update_mouse_mode()
	if _bench:
		_run_bench(frame_ms)
	_proc_end_usec = Time.get_ticks_usec()
	if _shot_path != "" and _elapsed >= _shot_delay:
		var img := get_viewport().get_texture().get_image()
		img.save_png(_shot_path)
		print("Saved screenshot to ", _shot_path)
		_shot_path = ""
		if not _bench:
			get_tree().quit()


func _drain_events() -> void:
	var ev := sim.events
	for i in sim.event_count:
		var o := i * 4
		var type := int(ev[o])
		var value := ev[o + 3]
		view.handle_event(type, ev[o + 1], ev[o + 2], value)
		match type:
			GameSim.EV_SHOT:
				Sfx.play_asset(sim.player.weapons[int(value)].sound, 1.0, randf_range(0.95, 1.05), 0.045)
			GameSim.EV_EXPLOSION:
				Sfx.play_asset("sfx.explosion", clampf(value * 0.2, 0.4, 1.0), randf_range(0.8, 1.2), 0.03)
			GameSim.EV_SHIELD_HIT:
				Sfx.play_asset("sfx.shield.hit", 1.0, 1.0, 0.05)
			GameSim.EV_HULL_HIT:
				Sfx.play_asset("sfx.hull.hit", 1.0, 1.0, 0.05)
			GameSim.EV_POWER:
				hud_left.power_flash = 1.0
				Sfx.play_asset("sfx.ui.power", 1.0, 0.8 + (1.0 - value) * 0.7)
	sim.event_count = 0


func _run_bench(frame_ms: float) -> void:
	if _elapsed < _bench_warmup:
		return
	_bench_frames.append(frame_ms)
	if frame_ms > 4.6:
		_bench_over_budget += 1
	var wrid := world_viewport.get_viewport_rid()
	var rrid := get_viewport().get_viewport_rid()
	_gpu_world = lerpf(_gpu_world, RenderingServer.viewport_get_measured_render_time_gpu(wrid), 0.02)
	_cpu_world = lerpf(_cpu_world, RenderingServer.viewport_get_measured_render_time_cpu(wrid), 0.02)
	_gpu_ui = lerpf(_gpu_ui, RenderingServer.viewport_get_measured_render_time_gpu(rrid), 0.02)
	_cpu_ui = lerpf(_cpu_ui, RenderingServer.viewport_get_measured_render_time_cpu(rrid), 0.02)
	_bench_bullets = maxi(_bench_bullets, sim.ebul.count + sim.pbul.count)
	if _elapsed < _bench_warmup + _bench_seconds:
		return
	var frames := _bench_frames.duplicate()
	frames.sort()
	var n := frames.size()
	var total := 0.0
	for v in frames:
		total += v
	var avg := total / n
	var p99 := frames[mini(n - 1, int(n * 0.99))]
	var p999 := frames[mini(n - 1, int(n * 0.999))]
	var win := get_window().size
	var result := {
		"driver": RenderingServer.get_current_rendering_driver_name(),
		"adapter": RenderingServer.get_video_adapter_name(),
		"window": "%dx%d" % [win.x, win.y],
		"screen": str(DisplayServer.screen_get_size()),
		"gpu_world_ms": snappedf(_gpu_world, 0.001),
		"cpu_world_ms": snappedf(_cpu_world, 0.001),
		"gpu_ui_ms": snappedf(_gpu_ui, 0.001),
		"cpu_ui_ms": snappedf(_cpu_ui, 0.001),
		"msaa": Settings.values["msaa"],
		"glow": Settings.values["glow"],
		"playfield": "%dx%d" % [world_viewport.size.x, world_viewport.size.y],
		"frames": n,
		"pct_frames_over_4_6ms": snappedf(100.0 * _bench_over_budget / n, 0.01),
		"script_ms_per_frame_true_avg": snappedf(_bench_script_usec / 1000.0 / n, 0.001),
		"avg_fps": snappedf(1000.0 / avg, 0.1),
		"avg_ms": snappedf(avg, 0.001),
		"p99_ms": snappedf(p99, 0.001),
		"low_1pct_fps": snappedf(1000.0 / p99, 0.1),
		"p999_ms": snappedf(p999, 0.001),
		"worst_ms": snappedf(frames[n - 1], 0.001),
		"sim_ms_per_frame": snappedf(overlay.sim_ms, 0.001),
		"view_ms_per_frame": snappedf(overlay.view_ms, 0.001),
		"enemies": sim.enemy_count,
		"peak_bullets": _bench_bullets,
	}
	for b: Dictionary in [_slow, _fast]:
		var c: float = maxf(b["n"], 1.0)
		print("  %s frames: n=%d frame=%.2f sim=%.2f view=%.2f ticks=%.2f render_gap=%.2f tick_gap=%.2f" % [
			"slow" if b == _slow else "fast", b["n"], b["frame"] / c, b["sim"] / c, b["view"] / c, b["ticks"] / c,
			b.get("gap_a", 0.0) / c, b.get("gap_b", 0.0) / c])
	var seq := PackedStringArray()
	for i in range(_bench_frames.size() - 150, _bench_frames.size() - 10):
		seq.append("%.1f" % _bench_frames[i])
	print("  seq: ", " ".join(seq))
	print("  monitors: process=%.3f ms  physics_process=%.3f ms  navigation=%.3f ms  frame_setup_cpu=%.3f ms" % [
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.TIME_NAVIGATION_PROCESS) * 1000.0,
		RenderingServer.get_frame_setup_time_cpu()])
	print("BENCH ", JSON.stringify(result))
	var f := FileAccess.open("user://bench_last.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(result, "	"))
		f.close()
	get_tree().quit()
