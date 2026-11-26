extends SceneTree
## Command-line data validator. Run with tools\validate.ps1, or:
##   godot --headless --path game -s res://tools/validate_data.gd
## Exit code 0 means no errors.


func _init() -> void:
	var ds := DataStore.new()
	ds.root_dir = DataStore.find_root()
	ds.reload()
	var validator := DataValidator.new()
	var ok := validator.run(ds)
	for w in validator.warnings:
		print("WARNING  ", w)
	for e in validator.errors:
		print("ERROR    ", e)
	print(validator.summary())
	ds.free()
	quit(0 if ok else 1)
