# Screenshot tool: Runs Godot with --shot=<name> argument
param(
    [Parameter(Mandatory=$true)]
    [string]$Name,
    [string]$Room = "",
    [int]$Stability = 60,
    [string]$GodotExe = "C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $GodotExe)) {
    Write-Error "Godot executable not found at: $GodotExe"
    exit 1
}

$argsList = @("--path `"$PSScriptRoot/..`"", "--shot=$Name")
if ($Room -ne "") {
    $argsList += "--room=$Room"
}
if ($Stability -ne 60) {
    $argsList += "--stability=$Stability"
}

Write-Host "Taking screenshot: $Name (Room: $Room, Stability: $Stability)..."
$proc = Start-Process -FilePath $GodotExe -ArgumentList ($argsList -join " ") -PassThru -NoNewWindow -Wait

if ($proc.ExitCode -ne 0) {
    Write-Error "Screenshot process failed with exit code $($proc.ExitCode)"
    exit $proc.ExitCode
}

$targetPath = Join-Path "$PSScriptRoot/../tests/screenshots" "$Name.png"
if (Test-Path $targetPath) {
    Write-Host "Screenshot saved successfully at: $targetPath"
} else {
    Write-Warning "Target file not found at: $targetPath (will be implemented in M2 runtime)"
}
