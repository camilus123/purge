# Validates every data file against its schema and checks all cross-references. Exit code 0 = no errors.
[CmdletBinding(PositionalBinding = $false)]
param([string]$Godot = "H:\temp\godot\Godot_v4.7.2-stable_win64_console.exe")
& $Godot --headless --path (Join-Path $PSScriptRoot "..\game") -s res://tools/validate_data.gd
exit $LASTEXITCODE
