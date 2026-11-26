# Runs purge from source. Extra arguments are passed to the game, for example:
#   .\tools\run.ps1                 play (borderless fullscreen)
#   .\tools\run.ps1 --windowed      play in a window
#   .\tools\run.ps1 --bench         15 second stress benchmark, prints a BENCH line
#   .\tools\run.ps1 --bench -Driver d3d12
[CmdletBinding(PositionalBinding = $false)]
param(
	[string]$Godot = "H:\temp\godot\Godot_v4.7.2-stable_win64_console.exe",
	[string]$Driver = "",
	[Parameter(ValueFromRemainingArguments = $true)][string[]]$GameArgs
)
$project = Join-Path $PSScriptRoot "..\game"
$engineArgs = @("--path", $project)
if ($Driver -ne "") { $engineArgs += @("--rendering-driver", $Driver) }
& $Godot @engineArgs "--" @GameArgs
