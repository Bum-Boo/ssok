# Foreground AI operator archive

This optional developer tool connects to ssok's existing rendered desktop camera.
It runs one intentionally submitted app goal, then exits. It is a local draft;
it does not install a service or include the Godot application.

Requirements: Python 3.11 or newer, the pinned `requirements.txt` installed in
that Python environment, and Codex CLI on PATH with your existing ChatGPT login.
The archive includes no Python, Codex binary, account, credentials or environment.
Provider login remains external. API-key fallback and automatic retries are disabled.

Extract the archive anywhere. No Git checkout is needed. `operator-source.json`
records the operator version, committed source and eight module SHA-256 values.
The runner checks those module bytes before starting the model. These hashes
detect changes relative to the included record; they are not a publisher signature.

On Windows, in PowerShell:

```powershell
.\tools\app_control\setup-operator.ps1
.\tools\app_control\start-operator.ps1 -CheckOnly
$env:SSOK_AGENT_TOKEN = [Guid]::NewGuid().ToString('N')
Start-Process -FilePath 'C:\path\to\ssok.exe' -ArgumentList @('--', '--ssok-agent-bridge')
.\tools\app_control\start-operator.ps1 -Out .\evidence\first-goal
```

Setup creates or reuses only this archive's `.operator-venv`, installs its pinned
MCP requirement and checks imports. It needs network access for Python packages;
it installs no global packages and starts no app, model, browser or login flow.
The launcher automatically selects that local environment. You can still select
another prepared interpreter with `-Python C:\path\to\python.exe`.
`-CheckOnly` needs no app or token and never starts a goal. It classifies missing
dependencies, missing Codex, unsuitable login and login-status timeout, with
steps to fix them. It never prints raw login output or token values. Passing
these local checks does not prove model availability, quota, billing or inference.

If the login check fails, run `codex login` yourself and complete ChatGPT sign-in,
then repeat `-CheckOnly`. Setup never signs you in, switches credentials or
enables an API-key fallback. The command/status behavior was checked against
installed Codex0.159.0-alpha.9 and [official OpenAI documentation](https://learn.chatgpt.com/docs/developer-commands?surface=cli#codex-login)
on2026-10-11. Use the [official Codex CLI setup guide](https://learn.chatgpt.com/docs/codex/cli) if Codex
is missing. New-account browser sign-in is separate from the existing-account check.

Use the **same shell token** for the app and operator; do not paste it into a goal
or save it in a project. Import your supported graph car project, open the camera
panel, enter your goal, read the existing disclosure and click Run with AI.
Typing/Enter alone does not run a goal. The foreground operator waits at most
15 minutes. Close the app and remove the shell token when finished:

```powershell
Remove-Item Env:SSOK_AGENT_TOKEN
```

With Python and MCP already available, Linux/macOS use the archive root as cwd
and `python -m tools.app_control.run_operator --out /path/to/new-evidence`.
Those portable operating-system flows are not verified by the Windows archive check.

Stop in the app is local and requires no provider request. Ctrl+C also cancels
the operator's owned context. Each goal retains the existing bounds of eight
actions, nine images and 300 seconds. Those are tool/time limits, not a billing
or model-request cap. Sent data are the goal, robot camera PNGs, public frame
context, concise visual summaries and actual tool results. Requested model:
`gpt-6-astra`; CLI JSON does not attest the serving model's identity.

Public evidence is written only to your new output directory. Wall-distance
precision, arbitrary-robot navigation and a fresh-account browser sign-in remain
unverified. Preparation does not claim those capabilities.
