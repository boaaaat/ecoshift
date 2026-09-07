[CmdletBinding()]
param(
  [string]$Output = "build/Ecoshift.rbxl"
)

Set-Location (Split-Path -Parent $PSScriptRoot)

$outputDir = Split-Path -Parent $Output
if ($outputDir -and -not (Test-Path $outputDir)) {
  New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
}

# Aftman installs a rojo shim on PATH; it has no `run` subcommand.
if (Get-Command rojo -ErrorAction SilentlyContinue) {
  & rojo build default.project.json --output $Output
  exit $LASTEXITCODE
}

Write-Error "Rojo is not installed and not available in PATH. Install it via Aftman or your package manager."
exit 1
