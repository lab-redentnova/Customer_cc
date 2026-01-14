Write-Host "Resolving system Python (enterprise-safe, version-agnostic)..."

# Get all python candidates
$pythonCandidates = Get-Command python -All -ErrorAction SilentlyContinue |
    Where-Object {
        $_.Source -notmatch "WindowsApps"
    }

if (-not $pythonCandidates) {
    # Fallback: search common install locations
    $fallbacks = @(
        "C:\Program Files\Python*\python.exe",
        "C:\Program Files (x86)\Python*\python.exe",
        "C:\Users\*\AppData\Local\Programs\Python\Python*\python.exe"
    )

    foreach ($pattern in $fallbacks) {
        $found = Get-ChildItem $pattern -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($found) {
            $pythonExe = $found.FullName
            break
        }
    }
} else {
    $pythonExe = $pythonCandidates[0].Source
}

if (-not $pythonExe) {
    throw @"
Real Python executable not found.

Avoid Microsoft Store Python.
Install Python from python.org and ensure it is available system-wide.
"@
}

Write-Host "Using Python executable:"
Write-Host $pythonExe

# Verify it actually runs
& $pythonExe --version

# Export for workflow
"PYTHON_EXE=$pythonExe" | Out-File -FilePath $env:GITHUB_ENV -Append -Encoding utf8
