class_name PauseMenu
extends Control
## Esc menu during a stage: resume, restart the stage, leave, and the settings.

signal resume_requested
signal restart_requested
signal menu_requested
signal quit_requested
signal display_changed


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var m := UiTheme.modal(480.0, 0.55)
	add_child(m[0])
	var box: VBoxContainer = m[1]
	var title := UiTheme.label("PAUSED", 32, UiTheme.ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var resume := UiTheme.button("Resume", func() -> void: resume_requested.emit())
	box.add_child(resume)
	box.add_child(UiTheme.button("Restart stage", func() -> void: restart_requested.emit()))
	var menu := UiTheme.button("Quit to main menu", func() -> void: menu_requested.emit())
	menu.tooltip_text = "Progress in this stage is lost; the run continues from the last shop visit."
	box.add_child(menu)
	box.add_child(HSeparator.new())
	var settings := SettingsPanel.new()
	settings.display_changed.connect(func() -> void: display_changed.emit())
	box.add_child(settings)
	box.add_child(HSeparator.new())
	box.add_child(UiTheme.button("Quit to desktop", func() -> void: quit_requested.emit()))
	visibility_changed.connect(func() -> void:
		if visible:
			resume.grab_focus.call_deferred())
