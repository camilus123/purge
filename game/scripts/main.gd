extends Node
## The game's top level. Owns the simulation, the 3D view, the HUD and every menu, and moves
## between them: main menu -> shop -> stage -> results -> shop ... -> end screen.
## The simulation runs on a fixed 240 Hz tick; the view draws an interpolated frame.
## Every way into play starts from a click or key press (see docs/DECISIONS.md, cursor).
##
## Command line (after `--`): --windowed, --level=<set id>/<number> (quick play, no shop),
## --bench[=seconds], --light, --demo, --stress, --set=<key>=<value>, --shot=<png path>,
## --shot-delay=<seconds>, --next-after=<seconds>, --screen=<menu|shop|results|end> (screenshots)

enum Mode { MENU, SHOP, PLAY, RESULTS, END }

## Loadout for quick play (test range, --level, benchmarks).
const QUICK_LOADOUT := {
	"reactor": "reactor.core.t1", "shield": "shield.bulwark.t1", "armor": "armor.standard.t1",
	"weapon1": "weapon.laser.t1", "weapon2": "weapon.chaingun.t1",
}
const CLEAR_DELAY := 2.5   # seconds between the last enemy going and the results screen

var sim: GameSim
var view: WorldView
var world_viewport: SubViewport
var playfield: TextureRect
var hud_left: HudPanel
var hud_right: HudPanel
var overlay: DebugOverlay
var pause_menu: PauseMenu
var main_menu: MainMenu
var shop: ShopScreen
var results: ResultsScreen
var end_screen: EndScreen

var mode: Mode = Mode.MENU
var paused: bool = false
var run: RunState
var economy: Dictionary = {}

var _quick: bool = false            # quick play: no shop, no saving
var _mouse_accum: Vector2 = Vector2.ZERO
var _field_rect: Rect2
var _data_errors: int = 0
var _sim_usec: int = 0
var _tick_dt: float = 1.0 / 240.0
var _banner: Label
var _banner_time: float = 0.0
var _elapsed: float = 0.0
var _last_usec: int = 0
var _no_save: bool = false          # command-line overrides must not end up in the saved settings

# Command-line modes
var _demo: bool = false
var _bench: BenchRecorder = null
var _bench_light: bool = false
var _level_arg: String = ""
var _screen_arg: String = ""
var _shot_path: String = ""
var _shot_delay: float = 6.0
var _next_after: float = 0.0
var _force_windowed: bool = false
var _loadout_arg: PackedStringArray = []   # quick play: item ids to fit instead of QUICK_LOADOUT
var _special_at: float = -1.0              # demo: fire the special at this time
var _flow_test: bool = false               # plays a whole campaign by itself at 4x speed, then quits
var _flow_timer: float = 0.0


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
	economy = Data.load_dict("economy.json")

	sim = GameSim.new()
	_show_backdrop(_first_set(), 0)
	_build_screen()
	get_viewport().size_changed.connect(_layout)
	Settings.changed.connect(_on_settings_changed)
	_layout()
	_last_usec = Time.get_ticks_usec()

	if _flow_test:
		Engine.time_scale = 4.0
		_on_new_game("campaign", "", "normal", -1)
		print("FLOW shop opened: ", _stage_title(), " credits ", run.credits)
	elif _bench != null or _demo or _level_arg != "":
		var set_id := "sandbox" if _level_arg == "" else _level_arg.get_slice("/", 0)
		_start_quick(set_id, maxi(int(_level_arg.get_slice("/", 1)) - 1, 0) if _level_arg.contains("/") else 0)
		if _bench != null:
			sim.stress = not _bench_light
			_bench.start(world_viewport, get_viewport())
	elif _screen_arg != "":
		_debug_screen(_screen_arg)
	else:
		_go_menu()


func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		_no_save = true
		if arg == "--windowed":
			_force_windowed = true
		elif arg == "--demo":
			_demo = true
		elif arg == "--stress":
			_demo = true
		elif arg.begins_with("--level="):
			_level_arg = arg.get_slice("=", 1)
		elif arg.begins_with("--next-after="):
			_next_after = float(arg.get_slice("=", 1))
		elif arg.begins_with("--loadout="):
			_loadout_arg = arg.get_slice("=", 1).split(",")
		elif arg.begins_with("--special-at="):
			_special_at = float(arg.get_slice("=", 1))
		elif arg == "--flow-test":
			_flow_test = true
			_demo = true
		elif arg.begins_with("--screen="):
			_screen_arg = arg.get_slice("=", 1)
		elif arg == "--light":
			_bench_light = true
		elif arg.begins_with("--bench"):
			# Uncapped by default; a later --set=fps_cap=... or --set=vsync=true overrides this.
			if _bench == null:
				Settings.values["vsync"] = false
				Settings.values["fps_cap"] = 0
				_bench = BenchRecorder.new()
			_demo = true
			if arg.contains("="):
				_bench.seconds = float(arg.get_slice("=", 1))
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


func _first_set() -> Dictionary:
	for s: Dictionary in Data.sets:
		if not s.get("hidden", false):
			return s
	return Data.sets[0] if not Data.sets.is_empty() else {}


func _visible_set_ids() -> Array:
	var out: Array = []
	for s: Dictionary in Data.sets:
		if not s.get("hidden", false):
			out.append(s["id"])
	return out


# ---------------------------------------------------------------- screen construction

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
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.theme = UiTheme.build()
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

	_banner = Label.new()
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override("font_size", 34)
	_banner.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	_banner.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_banner.add_theme_constant_override("outline_size", 8)
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.visible = false
	ui.add_child(_banner)

	results = ResultsScreen.new()
	results.continue_requested.connect(_on_results_continue)
	ui.add_child(results)
	shop = ShopScreen.new()
	shop.launch_requested.connect(_on_launch)
	shop.menu_requested.connect(func() -> void:
		_save()
		_go_menu())
	ui.add_child(shop)
	end_screen = EndScreen.new()
	end_screen.done.connect(_go_menu)
	ui.add_child(end_screen)
	main_menu = MainMenu.new()
	main_menu.new_game_requested.connect(_on_new_game)
	main_menu.load_requested.connect(_on_load)
	main_menu.test_range_requested.connect(func() -> void: _start_quick("sandbox", 0))
	main_menu.quit_requested.connect(_quit)
	main_menu.display_changed.connect(_apply_display)
	ui.add_child(main_menu)

	pause_menu = PauseMenu.new()
	pause_menu.resume_requested.connect(func() -> void: _set_paused(false))
	pause_menu.restart_requested.connect(func() -> void:
		sim.restart()
		_set_paused(false))
	pause_menu.menu_requested.connect(_go_menu)
	pause_menu.quit_requested.connect(_quit)
	pause_menu.display_changed.connect(_apply_display)
	ui.add_child(pause_menu)

	overlay = DebugOverlay.new()
	overlay.sim = sim
	overlay.world_viewport = world_viewport
	overlay.position = Vector2(8, 8)
	overlay.visible = _bench != null
	ui.add_child(overlay)
	_set_mode(Mode.MENU)


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
	_banner.position = _field_rect.position + Vector2(0, _field_rect.size.y * 0.3)
	_banner.size = Vector2(_field_rect.size.x, 100)
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
	_update_mouse_mode()


# ---------------------------------------------------------------- modes

func _set_mode(m: Mode) -> void:
	mode = m
	paused = false
	main_menu.visible = m == Mode.MENU
	shop.visible = m == Mode.SHOP
	results.visible = m == Mode.RESULTS
	end_screen.visible = m == Mode.END
	pause_menu.visible = false
	hud_left.visible = m == Mode.PLAY or m == Mode.RESULTS
	hud_right.visible = hud_left.visible
	view.show_player = hud_left.visible
	_mouse_accum = Vector2.ZERO
	_update_mouse_mode()


func _update_mouse_mode() -> void:
	if mode != Mode.PLAY or paused or _demo:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif String(Settings.values["mouse_mode"]) == "absolute":
		Input.mouse_mode = Input.MOUSE_MODE_CONFINED_HIDDEN
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _set_paused(p: bool) -> void:
	if mode != Mode.PLAY:
		return
	paused = p
	pause_menu.visible = p
	_mouse_accum = Vector2.ZERO
	_update_mouse_mode()
	if not p and not _no_save:
		Settings.save_settings()


## Shows a level's scenery with no enemies, behind the menus and the shop.
func _show_backdrop(set_def: Dictionary, index: int) -> void:
	var level := Data.load_level(set_def, index).duplicate()
	level["waves"] = []
	var r := RunState.create("single", [], "normal", economy, {}, 0.0, QUICK_LOADOUT)
	sim.setup(StageConfig.build(r, Data, level))
	if view != null:
		_refresh_stage_views()


func _refresh_stage_views() -> void:
	view.refresh_sprite_table()
	view.refresh_loadout()
	view.rebuild_background()
	hud_left.refresh_loadout()


func _go_menu() -> void:
	run = null
	_quick = false
	_show_backdrop(_first_set(), 0)
	_set_mode(Mode.MENU)
	main_menu.show_page("home")


func _quit() -> void:
	if not _no_save:
		Settings.save_settings()
	get_tree().quit()


func _save() -> void:
	if run != null and not _quick and not _no_save:
		SaveSystem.save(run)


# ---------------------------------------------------------------- run flow

func _on_new_game(p_mode: String, set_id: String, difficulty: String, slot: int) -> void:
	var diff := StageConfig.difficulty_def(Data, difficulty)
	if p_mode == "campaign":
		run = RunState.create("campaign", _visible_set_ids(), difficulty, economy, diff)
	else:
		var s := Data.find_set(set_id)
		var single: Dictionary = s.get("single_set", {})
		run = RunState.create("single", [set_id], difficulty, economy, diff,
				float(single.get("credits", economy.get("starting_credits", 3000))), single.get("loadout", {}))
	run.slot = slot
	_quick = false
	_open_shop()


func _on_load(slot: int) -> void:
	var r := SaveSystem.load_slot(slot)
	if r == null:
		push_warning("Could not load slot %d" % slot)
		return
	run = r
	_quick = false
	_open_shop()


## Quick play: straight into a level with the quick loadout; no shop, nothing saved.
func _start_quick(set_id: String, index: int) -> void:
	var ids: Array = []
	for s: Dictionary in Data.sets:
		ids.append(s["id"])
	run = RunState.create("campaign", ids, "normal", economy, {}, 0.0, QUICK_LOADOUT)
	run.set_pos = maxi(ids.find(set_id), 0)
	run.level_index = index
	run.credits = 1000000
	# --loadout fits the listed items directly, ignoring prices and prerequisites;
	# the first weapon goes on LMB and the second on RMB.
	var weapon_slot := 0
	for id in _loadout_arg:
		if not Data.items.has(id):
			push_warning("--loadout: unknown item %s" % id)
			continue
		var item: Dictionary = Data.items[id]
		run.owned[id] = 0
		var slots := ShopRules.slots_for(item)
		var slot: String = slots[0]
		if item.get("category", "") == "weapon":
			slot = slots[mini(weapon_slot, 1)]
			weapon_slot += 1
		if item.get("category", "") == "special":
			run.ammo[id] = int(item.get("ammo", 0))
		run.equipped[slot] = id
	_quick = true
	_start_stage()


func _current_set() -> Dictionary:
	return Data.find_set(run.current_set_id())


func _stage_title() -> String:
	var s := _current_set()
	var level := Data.load_level(s, run.level_index)
	return "%s %d: %s" % [s.get("name", ""), run.level_index + 1, level.get("name", "")]


func _open_shop() -> void:
	_save()
	_show_backdrop(_current_set(), run.level_index)
	_set_mode(Mode.SHOP)
	shop.open(run, Data.items, economy, _stage_title())


func _on_launch() -> void:
	_save()
	_start_stage()


func _start_stage() -> void:
	var was_stress := sim.stress
	var was_invincible := sim.invincible
	var s := _current_set()
	sim.setup(StageConfig.build(run, Data, Data.load_level(s, run.level_index)))
	sim.set_power_step(float(Settings.values["power_step"]))
	sim.stress = was_stress
	sim.invincible = was_invincible
	_refresh_stage_views()
	hud_left.bank_credits = run.credits
	hud_right.bank_credits = run.credits
	hud_right.set_title(sim.level_name.to_upper())
	hud_right.data_errors = _data_errors
	_banner.text = "%s  -  STAGE %d\n%s" % [String(s.get("name", "")).to_upper(), run.level_index + 1, sim.level_name.to_upper()]
	_banner_time = 3.5
	_set_mode(Mode.PLAY)


## The stage is cleared: bank the results into the run and show them.
func _finish_stage() -> void:
	if _quick:
		_change_level(1)
		return
	var stats := StageConfig.stage_stats(sim)
	var diff := StageConfig.difficulty_def(Data, run.difficulty)
	var res := Economy.stage_results(stats, economy, diff)
	run.credits += int(res["total"])
	run.hull_damage = maxf(0.0, sim.player.armor_max - sim.player.armor)
	if sim.player.special != null:
		run.ammo[run.equipped["special"]] = sim.player.special.ammo
	var st := run.stats
	st["stages_cleared"] += 1
	st["kills"] += sim.kills
	st["credits_earned"] += int(res["total"])
	st["shots_fired"] += sim.shots_fired
	st["shots_hit"] += sim.shots_hit
	_set_mode(Mode.RESULTS)
	results.open("%s  CLEAR" % _stage_title().to_upper(), res)


func _on_results_continue() -> void:
	var s := _current_set()
	var set_id: String = s.get("id", "")
	var old_pos := run.set_pos
	var more := run.advance((s.get("levels", []) as Array).size())
	if run.set_pos != old_pos:
		SaveSystem.mark_set_completed(set_id)
	if not more:
		_save()
		_set_mode(Mode.END)
		end_screen.open("CAMPAIGN COMPLETE" if run.mode == "campaign" else "%s COMPLETE" % String(s.get("name", "")).to_upper(), run)
		return
	run.shop_visit += 1
	_open_shop()


## Debug level select (PgUp / PgDn): steps through every level of the run's sets.
func _change_level(step: int) -> void:
	var s := _current_set()
	run.level_index += step
	if run.level_index >= (s.get("levels", []) as Array).size():
		run.set_pos = posmod(run.set_pos + 1, run.set_ids.size())
		run.level_index = 0
	elif run.level_index < 0:
		run.set_pos = posmod(run.set_pos - 1, run.set_ids.size())
		run.level_index = maxi((_current_set().get("levels", []) as Array).size() - 1, 0)
	_start_stage()


## Re-reads every data and asset file without restarting the game (debug builds, F6).
func _hot_reload() -> void:
	Data.reload()
	Assets.reload()
	economy = Data.load_dict("economy.json")
	_validate_data()
	view.reset_models()
	_start_stage()
	print("Data reloaded")


## --flow-test: buys something, launches, lets the demo pilot clear each stage, continues
## through results and shops, and prints what happened at each step.
func _step_flow_test(delta: float) -> void:
	_flow_timer += delta
	if _flow_timer < 0.5:
		return
	match mode:
		Mode.SHOP:
			_flow_timer = 0.0
			ShopRules.buy(run, Data.items, "weapon.chaingun.t1")
			ShopRules.buy(run, Data.items, "special.cluster.t1")
			print("FLOW launch ", _stage_title(), " loadout ", run.equipped, " credits ", run.credits)
			_on_launch()
		Mode.PLAY:
			if _flow_timer > 600.0:
				print("FLOW FAIL: stage did not finish")
				get_tree().quit(1)
		Mode.RESULTS:
			_flow_timer = 0.0
			print("FLOW results: credits now ", run.credits, " hull damage ", run.hull_damage, " ammo ", run.ammo)
			_on_results_continue()
		Mode.END:
			print("FLOW end: ", run.stats)
			get_tree().quit(0)


## For screenshots and checks: --screen=menu|shop|results|end opens that screen with a sample run.
func _debug_screen(which: String) -> void:
	run = RunState.create("campaign", _visible_set_ids(), "normal", economy, {})
	run.slot = -1
	_quick = true
	ShopRules.buy(run, Data.items, "shield.bulwark.t1")
	ShopRules.buy(run, Data.items, "weapon.chaingun.t1")
	ShopRules.buy(run, Data.items, "special.seeker.t1")
	run.hull_damage = 35.0
	match which:
		"shop":
			_open_shop()
		"results":
			_set_mode(Mode.RESULTS)
			var stats := {"kills": 41, "spawned": 47, "kill_credits": 930, "shots_fired": 860, "shots_hit": 517,
				"hull_damage": 24.0, "armor_start": 100.0, "boss_spawned": false}
			results.open("FRONTIER 1: COASTAL APPROACH  CLEAR", Economy.stage_results(stats, economy, {"credit_mult": 1.0}))
		"end":
			_set_mode(Mode.END)
			end_screen.open("FRONTIER COMPLETE", run)
		_:
			_go_menu()


# ---------------------------------------------------------------- input and loop

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and sim != null and not _demo and mode == Mode.PLAY:
		_set_paused(true)
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		_quit()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if mode == Mode.PLAY and not paused and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			# screen_relative is raw mouse movement, unaffected by UI scaling.
			_mouse_accum += (event as InputEventMouseMotion).screen_relative
		return
	if event.is_action_pressed("debug_overlay"):
		overlay.visible = not overlay.visible
		return
	if mode != Mode.PLAY:
		return
	if event.is_action_pressed("pause"):
		_set_paused(not paused)
	elif paused:
		return
	elif event.is_action_pressed("power_weapons"):
		sim.shift_power(-1 if Settings.values["invert_wheel"] else 1)
	elif event.is_action_pressed("power_shields"):
		sim.shift_power(1 if Settings.values["invert_wheel"] else -1)
	elif event.is_action_pressed("special"):
		sim.fire_special()
	elif OS.is_debug_build():
		if event.is_action_pressed("debug_stress"):
			sim.stress = not sim.stress
		elif event.is_action_pressed("debug_invincible"):
			sim.invincible = not sim.invincible
		elif event.is_action_pressed("debug_next_level"):
			_change_level(1)
		elif event.is_action_pressed("debug_prev_level"):
			_change_level(-1)
		elif event.is_action_pressed("debug_reload"):
			_hot_reload()


func _physics_process(delta: float) -> void:
	if mode != Mode.PLAY or paused:
		return
	if _demo:
		sim.invincible = true
		sim.in_absolute = true
		sim.in_target = Vector2(sin(sim.time * 0.9) * 30.0, 34.0 + sin(sim.time * 0.37) * 10.0)
		sim.in_fire_1 = true
		sim.in_fire_2 = fmod(sim.time, 6.0) < 4.0
		if _special_at >= 0.0 and sim.time >= _special_at:
			_special_at = -1.0
			sim.fire_special()
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
	sim.step(delta)
	_sim_usec += Time.get_ticks_usec() - t0


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
	var frame_ms := (now - _last_usec) / 1000.0
	_last_usec = now
	overlay.push_frame(frame_ms)
	overlay.sim_ms = lerpf(overlay.sim_ms, _sim_usec / 1000.0, 0.05)
	var frame_script_usec := _sim_usec
	_sim_usec = 0

	var playing := mode == Mode.PLAY and not paused
	if playing and run != null:
		run.stats["play_time"] += delta
	if mode == Mode.PLAY and sim.state == GameSim.STATE_CLEAR and sim.clear_time > CLEAR_DELAY:
		_finish_stage()
	if mode != Mode.PLAY:
		# Keep the scenery drifting behind the menus.
		sim.scroll += delta * 8.0
		sim.time += delta

	var t0 := Time.get_ticks_usec()
	_drain_events()
	var alpha := Engine.get_physics_interpolation_fraction()
	view.render(alpha if playing else 1.0, delta, _tick_dt, playing)
	var view_usec := Time.get_ticks_usec() - t0
	overlay.view_ms = lerpf(overlay.view_ms, view_usec / 1000.0, 0.05)
	frame_script_usec += view_usec

	_elapsed += delta
	if _flow_test:
		_step_flow_test(delta)
	if _next_after > 0.0 and _elapsed >= _next_after:
		_next_after = 0.0
		_change_level(1)
	if _banner_time > 0.0:
		_banner_time -= delta
		_banner.modulate.a = clampf(_banner_time, 0.0, 1.0)
		_banner.visible = _banner_time > 0.0 and mode == Mode.PLAY
	if _bench != null and _bench.record(_elapsed, frame_ms, frame_script_usec, sim, world_viewport, get_viewport(), overlay):
		get_tree().quit()
	if _shot_path != "" and _elapsed >= _shot_delay:
		var img := get_viewport().get_texture().get_image()
		img.save_png(_shot_path)
		print("Saved screenshot to ", _shot_path)
		_shot_path = ""
		if _bench == null:
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
				var w := sim.player.weapons[int(value)]
				if w != null:
					Sfx.play_asset(w.sound, 1.0, randf_range(0.95, 1.05), 0.045)
			GameSim.EV_SPECIAL:
				if value > 0.5 and sim.player.special != null:
					Sfx.play_asset(sim.player.special.sound, 1.0, randf_range(0.95, 1.05))
				else:
					Sfx.play_asset("sfx.special.empty")
			GameSim.EV_SPLASH:
				Sfx.play_asset("sfx.explosion", clampf(value * 0.08, 0.15, 0.5), randf_range(1.2, 1.5), 0.05)
			GameSim.EV_EXPLOSION:
				Sfx.play_asset("sfx.explosion", clampf(value * 0.2, 0.4, 1.0), randf_range(0.8, 1.2), 0.03)
			GameSim.EV_SHIELD_HIT:
				Sfx.play_asset("sfx.shield.hit", 1.0, 1.0, 0.05)
			GameSim.EV_HULL_HIT:
				Sfx.play_asset("sfx.hull.hit", 1.0, 1.0, 0.05)
			GameSim.EV_PLAYER_DEAD:
				if run != null:
					run.stats["deaths"] += 1
			GameSim.EV_POWER:
				hud_left.power_flash = 1.0
				Sfx.play_asset("sfx.ui.power", 1.0, 0.8 + (1.0 - value) * 0.7)
	sim.event_count = 0
