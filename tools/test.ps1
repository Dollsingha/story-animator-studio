param([Parameter(Mandatory=$true)][string]$Godot)
$ErrorActionPreference = 'Stop'
$project = Split-Path -Parent $PSScriptRoot
function Invoke-GodotCheck {
    param([string[]]$Arguments, [switch]$RequireResult)
    $logPath = Join-Path ([IO.Path]::GetTempPath()) ('story-animator-' + [guid]::NewGuid().ToString() + '.log')
    try {
        & $Godot --headless --path $project --log-file $logPath @Arguments
        $code = $LASTEXITCODE
        $log = if (Test-Path -LiteralPath $logPath) { Get-Content -LiteralPath $logPath -Raw } else { '' }
        # Godot can exit 0 after a script parse/runtime error. Check its log too.
        if ($code -ne 0 -or $log -match 'SCRIPT ERROR:|Parse Error:|FAIL:|timed out') {
            throw 'Godot validation failed; see output above.'
        }
        if ($RequireResult -and $log -notmatch 'RESULT: \d+ checks, 0 failures') {
            throw 'Godot suite did not reach a successful result.'
        }
    } finally {
        if (Test-Path -LiteralPath $logPath) { Remove-Item -LiteralPath $logPath }
    }
}
Invoke-GodotCheck -Arguments @('--editor', '--quit')
Invoke-GodotCheck -Arguments @('--script', 'res://tests/run_tests.gd') -RequireResult
Invoke-GodotCheck -Arguments @('--script', 'res://tests/regressions.gd') -RequireResult
exit 0
