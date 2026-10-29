param([Parameter(Mandatory=$true)][string]$Godot)
$ErrorActionPreference = 'Stop'
$project = Split-Path -Parent $PSScriptRoot
& $Godot --headless --path $project --editor --quit
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $Godot --headless --path $project --script res://tests/run_tests.gd
exit $LASTEXITCODE
