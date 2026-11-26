# Runs the headless rule tests. Exit code 0 means every test passed.
[CmdletBinding(PositionalBinding = $false)]
param([string]$Godot = "H:\temp\godot\Godot_v4.7.2-stable_win64_console.exe")
& $Godot --headless --path (Join-Path $PSScriptRoot "..\game") -s res://tests/run_tests.gd
exit $LASTEXITCODE
