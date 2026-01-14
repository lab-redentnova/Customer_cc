Write-Host "Resolving system Python (PATH-based, version-agnostic)..."

# Try python first (most corporate installs)
$pythonCmd = Get-Command python -ErrorAction SilentlyContinue

if (-not $pythonCmd) {
    throw "Python executable not found in PATH. Please install Python and ensure it is available as 'python'."
}

$pythonExe = $pythonCmd.Source
Write-Host "Using Python executable: $pythonExe"

# Sanity check
& $pythonExe --version

# Export for later steps
echo "PYTHON_EXE=$pythonExe" | Out-File -FilePath $env:GITHUB_ENV -Append -Encoding utf8
