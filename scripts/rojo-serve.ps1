[CmdletBinding()]
param(
  [ValidateSet("Expedition", "Lobby")]
  [string]$Place = "Expedition"
)

Set-Location (Split-Path -Parent $PSScriptRoot)

# Aftman installs a rojo shim on PATH; it has no `run` subcommand.
if (Get-Command rojo -ErrorAction SilentlyContinue) {
  $project = if ($Place -eq "Lobby") { "lobby.project.json" } else { "default.project.json" }
  & rojo serve $project
  exit $LASTEXITCODE
}

Write-Error "Rojo is not installed and not available in PATH. Install it via Aftman or your package manager."
exit 1
