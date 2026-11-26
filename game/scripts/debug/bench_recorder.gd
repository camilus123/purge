class_name BenchRecorder
extends RefCounted
## Collects frame times during a `--bench` run and prints a BENCH line (also written to
## user://bench_last.json): average fps, 1% low, worst frame, GPU and script time.

var seconds: float = 12.0
var warmup: float = 4.0
var frames: PackedFloat32Array = []
var peak_bullets: int = 0
var script_usec: int = 0
var over_budget: int = 0
var _gpu_world: float = 0.0
var _cpu_world: float = 0.0
var _gpu_ui: float = 0.0
var _cpu_ui: float = 0.0


func start(world: SubViewport, root: Viewport) -> void:
	RenderingServer.viewport_set_measure_render_time(world.get_viewport_rid(), true)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)


## Call once per frame. Returns true when the benchmark is finished.
func record(elapsed: float, frame_ms: float, frame_script_usec: int, sim: GameSim, world: SubViewport, root: Viewport,
		overlay: DebugOverlay) -> bool:
	if elapsed < warmup:
		return false
	frames.append(frame_ms)
	script_usec += frame_script_usec
	if frame_ms > 4.6:
		over_budget += 1
	_gpu_world = lerpf(_gpu_world, RenderingServer.viewport_get_measured_render_time_gpu(world.get_viewport_rid()), 0.02)
	_cpu_world = lerpf(_cpu_world, RenderingServer.viewport_get_measured_render_time_cpu(world.get_viewport_rid()), 0.02)
	_gpu_ui = lerpf(_gpu_ui, RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()), 0.02)
	_cpu_ui = lerpf(_cpu_ui, RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()), 0.02)
	peak_bullets = maxi(peak_bullets, sim.ebul.count + sim.pbul.count)
	if elapsed < warmup + seconds:
		return false
	var sorted := frames.duplicate()
	sorted.sort()
	var n := sorted.size()
	var total := 0.0
	for v in sorted:
		total += v
	var avg := total / n
	var p99 := sorted[mini(n - 1, int(n * 0.99))]
	var win := root.get_window().size
	var result := {
		"driver": RenderingServer.get_current_rendering_driver_name(),
		"adapter": RenderingServer.get_video_adapter_name(),
		"window": "%dx%d" % [win.x, win.y],
		"playfield": "%dx%d" % [world.size.x, world.size.y],
		"gpu_world_ms": snappedf(_gpu_world, 0.001), "cpu_world_ms": snappedf(_cpu_world, 0.001),
		"gpu_ui_ms": snappedf(_gpu_ui, 0.001), "cpu_ui_ms": snappedf(_cpu_ui, 0.001),
		"msaa": Settings.values["msaa"], "glow": Settings.values["glow"],
		"frames": n,
		"pct_frames_over_4_6ms": snappedf(100.0 * over_budget / n, 0.01),
		"script_ms_per_frame": snappedf(script_usec / 1000.0 / n, 0.001),
		"avg_fps": snappedf(1000.0 / avg, 0.1), "avg_ms": snappedf(avg, 0.001),
		"p99_ms": snappedf(p99, 0.001), "low_1pct_fps": snappedf(1000.0 / p99, 0.1),
		"worst_ms": snappedf(sorted[n - 1], 0.001),
		"sim_ms_per_frame": snappedf(overlay.sim_ms, 0.001), "view_ms_per_frame": snappedf(overlay.view_ms, 0.001),
		"enemies": sim.enemy_count, "peak_bullets": peak_bullets,
	}
	print("BENCH ", JSON.stringify(result))
	var f := FileAccess.open("user://bench_last.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(result, "\t"))
	return true
