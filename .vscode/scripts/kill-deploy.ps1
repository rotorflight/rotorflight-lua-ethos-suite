# .vscode/scripts/kill-deploy.ps1
# Safe, quiet killer for Windows that never uses taskkill and never fails VS Code

$ErrorActionPreference = 'SilentlyContinue'

function Kill-FromPidFile {
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) { return }

    # Read all lines; keep only numeric PIDs; de-dupe
    $pids =
        Get-Content -LiteralPath $Path |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -match '^\d+$' } |
        ForEach-Object { [int]$_ } |
        Select-Object -Unique

    foreach ($pid in $pids) {
        $proc = Get-Process -Id $pid -ErrorAction SilentlyContinue
        if ($proc) {
            # Kill the process and any children if possible
            Stop-Process -Id $pid -Force -ErrorAction SilentlyContinue
        }
    }

    # Clean up the PID file regardless
    Remove-Item -LiteralPath $Path -ErrorAction SilentlyContinue
}

# === Update these paths if yours differ ===
$deployPidFile = Join-Path $env:TEMP 'rfdeploy-copy.pid'
$serialPidFile = Join-Path $env:TEMP 'rfdeploy-serial.pid'

Kill-FromPidFile -Path $deployPidFile
Kill-FromPidFile -Path $serialPidFile

# From VS Code's perspective this task always succeeds
exit 0
