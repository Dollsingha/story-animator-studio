param([Parameter(Mandatory=$true)][string]$Godot)
$ErrorActionPreference = 'Stop'
$project = Split-Path -Parent $PSScriptRoot
New-Item -ItemType Directory -Path (Join-Path $project 'build') -Force | Out-Null
& $Godot --headless --path $project --export-release 'Windows Desktop' 'build/StoryAnimatorStudio.exe'
exit $LASTEXITCODE
