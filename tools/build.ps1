# Exports the Windows release build to build\purge.exe and copies the data, assets and mods folders beside it.
[CmdletBinding(PositionalBinding = $false)]
param([string]$Godot = "H:\temp\godot\Godot_v4.7.2-stable_win64_console.exe")
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
New-Item -ItemType Directory -Force (Join-Path $root "build") | Out-Null
& $Godot --headless --path (Join-Path $root "game") --export-release "Windows" (Join-Path $root "build\purge.exe")
foreach ($folder in @("data", "assets", "mods")) {
	Copy-Item -Recurse -Force (Join-Path $root $folder) (Join-Path $root "build")
}
Write-Host "Built $(Join-Path $root 'build\purge.exe')"
