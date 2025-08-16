$ErrorActionPreference = 'SilentlyContinue'

# Kill simulator.exe if present
Get-Process -Name simulator -ErrorAction SilentlyContinue | ForEach-Object {
    try { Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue } catch {}
}

# Match deploy.py (full path or plain filename)
$patterns = @(
  'bin[\\/]+deploy[\\/]+deploy\.py',
  'deploy\.py'
)

$procs = Get-CimInstance Win32_Process |
  Where-Object {
    $cl = $_.CommandLine
    if (-not $cl) { return $false }
    foreach ($pat in $patterns) {
      if ($cl -match $pat) { return $true }
    }
    return $false
  }

if ($procs) {
  foreach ($p in $procs) {
    try { Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue } catch {}
  }
}

exit 0
