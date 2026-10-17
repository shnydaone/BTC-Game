# Run the headless GUT suite. Set $env:GODOT to your Godot 4.7 console binary if it is
# not at the default install path.
#   powershell -File tools/test.ps1
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$godot = if ($env:GODOT) { $env:GODOT } else { "C:\Program Files\Godot\Godot_v4.7.2-stable_win64_console.exe" }

# The import pass registers class_name scripts; needed on a fresh clone.
& $godot --headless --path $root --import
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

& $godot --headless --path $root -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
exit $LASTEXITCODE
