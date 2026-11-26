extends Node
## User settings (saved as JSON in the user folder) and input actions. Autoloaded as `Settings`.

const PATH := "user://settings.json"

var values: Dictionary = {
	"mouse_sensitivity": 0.085,   # playfield units per mouse count (relative mode)
	"mouse_mode": "relative",     # "relative" or "absolute"
	"invert_wheel": false,
	"power_step": 0.0,            # 0 = use data/tech/power_model.json
	"window_mode": "borderless",  # "windowed", "borderless", "exclusive"
	"vsync": false,
	"fps_cap": 0,                 # 0 = uncapped
	"render_scale": 1.0,
	"msaa": 1,                    # 0 off, 1 = 2x, 2 = 4x, 3 = 8x
	"glow": true,
	"screen_shake": 1.0,
	"volume_master": 0.8,
	"volume_sfx": 0.7,
}

signal changed


func _ready() -> void:
	load_settings()
	_register_actions()


func set_value(key: String, v: Variant) -> void:
	values[key] = v
	changed.emit()


func load_settings() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not (d is Dictionary):
		return
	for k: String in d:
		if not values.has(k):
			continue
		var cur: Variant = values[k]
		var v: Variant = d[k]
		# JSON numbers always come back as float.
		if cur is int and v is float:
			values[k] = int(v)
		elif typeof(cur) == typeof(v):
			values[k] = v


func save_settings() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(values, "\t"))


func apply_display() -> void:
	var win := get_window()
	match String(values["window_mode"]):
		"windowed":
			win.mode = Window.MODE_WINDOWED
		"exclusive":
			win.mode = Window.MODE_EXCLUSIVE_FULLSCREEN
		_:
			win.mode = Window.MODE_FULLSCREEN
	if values["vsync"]:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = int(values["fps_cap"])


## Default bindings. Every gameplay input goes through an action so it can be rebound later.
func _register_actions() -> void:
	_mouse_action("fire_1", MOUSE_BUTTON_LEFT)
	_mouse_action("fire_2", MOUSE_BUTTON_RIGHT)
	_mouse_action("special", MOUSE_BUTTON_MIDDLE)
	_mouse_action("power_weapons", MOUSE_BUTTON_WHEEL_UP)
	_mouse_action("power_shields", MOUSE_BUTTON_WHEEL_DOWN)
	_key_action("pause", KEY_ESCAPE)
	_key_action("debug_overlay", KEY_F3)
	_key_action("debug_stress", KEY_F4)
	_key_action("debug_invincible", KEY_F5)


func _mouse_action(action: String, button: MouseButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)


func _key_action(action: String, key: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = key
	InputMap.action_add_event(action, ev)
