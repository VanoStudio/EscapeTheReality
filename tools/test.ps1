# Test runner: Runs Godot unit tests headless
param(
    [string]$GodotExe = "C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
)

$ErrorActionPreference = "Stop"
Write-Host "=== RUNNING GODOT TESTS ==="

if (-not (Test-Path $GodotExe)) {
    Write-Error "Godot executable not found at: $GodotExe"
    exit 1
}

$proc = Start-Process -FilePath $GodotExe -ArgumentList "--headless --path `"$PSScriptRoot/..`" -s tests/run_tests.gd" -PassThru -NoNewWindow -Wait

if ($proc.ExitCode -ne 0) {
    Write-Error "Tests FAILED with exit code $($proc.ExitCode)"
    exit $proc.ExitCode
}

Write-Host "=== ALL TESTS PASSED ==="
exit 0
