# Rojo development servers

Run these commands from the repository root:

```powershell
rojo serve default.project.json
rojo serve lobby.project.json
```

The projects already define separate ports:

- Expedition place: `34872`
- Lobby place: `34873`

To run both from one PowerShell window:

```powershell
Start-Process rojo -ArgumentList "serve default.project.json" -WorkingDirectory (Get-Location)
Start-Process rojo -ArgumentList "serve lobby.project.json" -WorkingDirectory (Get-Location)
```

Check the running servers with:

```powershell
Get-Process rojo
```

Connect each Roblox Studio place to its matching Rojo server through the Rojo Studio plugin.
