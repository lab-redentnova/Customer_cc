# scripts/resolve_python.ps1
$ErrorActionPreference = "Stop"

function Is-WindowsAppsStub($exe) {
  return $exe -match "\\WindowsApps\\python(\.exe)?$"
}

function Resolve-Python {
  # 1) Prefer Python Launcher (most stable on Windows)
  $py = Get-Command py -ErrorAction SilentlyContinue
  if ($py) {
    # Use py -3 to always pick a Python 3.x
    return @("py", "-3")
  }

  # 2) Try python from PATH
  $python = Get-Command python -ErrorAction SilentlyContinue
  if ($python -and -not (Is-WindowsAppsStub $python.Source)) {
    return @($python.Source)
  }

  # 3) Try python3 from PATH
  $python3 = Get-Command python3 -ErrorAction SilentlyContinue
  if ($python3 -and -not (Is-WindowsAppsStub $python3.Source)) {
    return @($python3.Source)
  }

  # 4) Search common install locations (system-wide)
  $candidates = @(
    "$env:ProgramFiles\Python*\python.exe",
    "${env:ProgramFiles(x86)}\Python*\python.exe",
    "$env:LocalAppData\Programs\Python\Python*\python.exe"
  )

  $found = Get-ChildItem -Path $candidates -ErrorAction SilentlyContinue |
           Sort-Object FullName -Descending |
           Select-Object -First 1

  if ($found) {
    return @($found.FullName)
  }

  throw "Python not found. Install Python 3.x and ensure it's accessible to the runner service user."
}

$cmd = Resolve-Python

# Print and validate
Write-Host "Resolved Python command: $($cmd -join ' ')"
& $cmd --version

# Export for later workflow steps
"PYTHON_CMD=$($cmd -join ' ')" | Out-File -FilePath $env:GITHUB_ENV -Append -Encoding utf8
