# Smoke test: Boot Godot headless for 5 seconds and ensure no crash / errors
param(
    [string]$GodotExe = "C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
)

$ErrorActionPreference = "Stop"
Write-Host "=== SMOKE TEST: Booting Godot Headless (5s) ==="

if (-not (Test-Path $GodotExe)) {
    Write-Error "Godot executable not found at: $GodotExe"
    exit 1
}

$proc = Start-Process -FilePath $GodotExe -ArgumentList "--headless --path `"$PSScriptRoot/..`"" -PassThru -NoNewWindow
Start-Sleep -Seconds 5

if ($proc.HasExited) {
    if ($proc.ExitCode -ne 0) {
        Write-Error "Smoke test FAILED: Process exited unexpectedly with code $($proc.ExitCode)."
        exit $proc.ExitCode
    }
} else {
    Write-Host "Process running healthy after 5 seconds. Stopping process..."
    Stop-Process -Id $proc.Id -Force
}

Write-Host "=== SMOKE TEST PASSED: Engine booted cleanly ==="
exit 0
