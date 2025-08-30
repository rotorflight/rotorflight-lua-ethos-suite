# .vscode/scripts/kill-deploy.ps1

$deployPidFile = Join-Path $env:TEMP 'rfdeploy-copy.pid'
if (Test-Path $deployPidFile) {
    $deployPid = (Get-Content $deployPidFile | Out-String).Trim()
    if ($deployPid -match '^\d+$') {
        try { taskkill /PID $deployPid /T /F | Out-Null } catch {}
    }
    Remove-Item $deployPidFile -ErrorAction SilentlyContinue
}

# Optional: also kill any previous serial tail (your script already writes this file)
$serialPidFile = Join-Path $env:TEMP 'rfdeploy-serial.pid'
if (Test-Path $serialPidFile) {
    $serialPid = (Get-Content $serialPidFile | Out-String).Trim()
    if ($serialPid -match '^\d+$') {
        try { taskkill /PID $serialPid /T /F | Out-Null } catch {}
    }
    Remove-Item $serialPidFile -ErrorAction SilentlyContinue
}
