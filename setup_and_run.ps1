<#
Automates local setup for CollegeManagement-Django on Windows.

Usage (run from project root or double-click in Explorer):
  powershell -ExecutionPolicy Bypass -File .\setup_and_run.ps1

This script will:
- check for a real Python installation (not the Microsoft Store stub)
- optionally install Python using winget when available
- create a virtualenv at .venv
- install packages from requirements.txt
- run migrations and optionally create a superuser
- start the Django development server
#>

param(
    [switch]$NoCreateSuperUser
)

function Write-Info($m){ Write-Host "[INFO] $m" -ForegroundColor Cyan }
function Write-Err($m){ Write-Host "[ERROR] $m" -ForegroundColor Red }

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

Write-Info "Project root: $root"

function Get-PythonPath {
    $where = & where.exe python 2>$null
    if (-not $where) { return $null }
    # take first path
    $p = $where -split "`r?`n" | Select-Object -First 1
    return $p
}

$pythonPath = Get-PythonPath
if ($pythonPath) {
    Write-Info "Found python at: $pythonPath"
    if ($pythonPath -match "WindowsApps") {
        Write-Err "Detected Microsoft Store python launcher. This is not a real interpreter."
        $pythonPath = $null
    }
}

if (-not $pythonPath) {
    Write-Info "No usable Python found."
    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if ($winget) {
        $ans = Read-Host "Install Python via winget now? (Y/N)"
        if ($ans -match '^[Yy]') {
            Write-Info "Running: winget install --id=Python.Python.3 -e"
            winget install --id=Python.Python.3 -e
            Start-Sleep -Seconds 2
            $pythonPath = Get-PythonPath
        }
    } else {
        Write-Info "winget not available. Please install Python from https://python.org and re-run this script."
        Start-Process "https://www.python.org/downloads/windows/"
        exit 1
    }
}

if (-not $pythonPath) {
    Write-Err "Python installation not detected. Aborting."
    exit 2
}

Write-Info "Using python: $pythonPath"

$venvPython = Join-Path $root ".venv\Scripts\python.exe"
if (-not (Test-Path $venvPython)) {
    Write-Info "Creating virtualenv at .venv"
    & $pythonPath -m venv .venv
    if ($LASTEXITCODE -ne 0) {
        Write-Err "Failed to create virtualenv."
        exit 3
    }
}

Write-Info "Upgrading pip and installing requirements"
& $venvPython -m pip install -U pip
& $venvPython -m pip install -r requirements.txt
if ($LASTEXITCODE -ne 0) {
    Write-Err "Failed to install requirements. Check the output for errors."
    exit 4
}

Write-Info "Applying database migrations"
& $venvPython manage.py migrate
if ($LASTEXITCODE -ne 0) {
    Write-Err "Migrations failed."
    exit 5
}

if (-not $NoCreateSuperUser) {
    Write-Info "You can create a superuser now."
    & $venvPython manage.py createsuperuser
}

Write-Info "Starting development server on 0.0.0.0:8000"
& $venvPython manage.py runserver 0.0.0.0:8000
