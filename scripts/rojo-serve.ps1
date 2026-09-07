[CmdletBinding()]
param()

Set-Location (Split-Path -Parent $PSScriptRoot)

# Aftman installs a rojo shim on PATH; it has no `run` subcommand.
if (Get-Command rojo -ErrorAction SilentlyContinue) {
  & rojo serve default.project.json
  exit $LASTEXITCODE
}

Write-Error "Rojo is not installed and not available in PATH. Install it via Aftman or your package manager."
exit 1
