# Original task CLI recovery on Windows / Ubuntu WSL r24

Source **b58b95408b1feb46c27370c6e7a328a44e067e59**, issue32,2026-10-11.
The current computer had no agent-task executable/source. Existing Freiren backup
snapshot12c49368 (2026-10-10T21:15:23+09:00) contained the original stdlib tool,
tests and agent-handoff skill. Scoped restore recovered them through the existing
configured Restic CLI; the coordinator did not inspect or emit credential contents.
Backup settings, personal vault material and other recovery data were excluded.

Original agent_task.py remains byte-identical:SHA b0d54fe24ef658c7ed34036297ad6d227a1d693af36d82a4c53609febe2d5ef0.
Windows/WSL entry wrappers supply the same configured vault default and preserve
explicit native --vault and AGENT_TASK_VAULT (use WSL-form paths on Windows).
The initial Windows env override read the default revision18 instead of the
requested fixture revision19. Process-local WSLENV forwarding corrected it;
five real read-only entry checks pass, including existing WSLENV entries,
spaces and explicit --vault precedence. Caller/global environment is unchanged.
The original failed receipt is retained outside Git. No schema or task database changed.
The existing sustainable-workflow caller now resolves agent-handoff locally;
a bounded Windows host guide and declared dependency rows were installed.
No live Claude hooks, settings, shell profiles, schedules or model service added.

Actual original20 behavioral regressions pass. Only test-runner CLI/HOOK path
globals were rebound for this host; source/test bytes were unchanged. Existing
hook-install and malformed-hook tests used restored helpers and temporary dummy
settings/stores, not live hook configuration. A full copied task on Windows DrvFS
completed official show/resume/checkpoint/release at revisions16/17/18/19 while
the real task remained unchanged. This covers atomic filesystem/event recovery,
leases/live-owner rejection, explicit checkpoints and interrupted-view behavior.

After checking actual authoritative event16 and stale lease, the real task was
explicitly resumed by the current coordinator (revision17), then checkpointed
(revision18). All original events1–16 are unchanged; generated views match the
committed event. Actual Windows and WSL commands both read the same revision18.
Final official release is recorded after exact final review by the coordinator;
this checkpoint does not claim the project complete. No generated field was
edited manually. The native CLI retains prior-host cwd because it has no cwd-update
option: actual current Windows checkout/branch is explicit in the checkpoint.
Local flock remains advisory; Syncthing is not a distributed lock.

[Observed summary](summary.json), [verification](verification.json),
[original regression results](original-regressions.json), [raw test log](original-regressions.log),
[Windows entry receipt](windows-entry-receipt.json), [Windows environment checks](windows-environment-regressions.json), [six source-copy identities](copy-manifest.json).
The user's private task state/backup/config is not part of repository onboarding.
External contributors use repository AGENTS/STATUS/issue ownership and this evidence.
Host-specific installation/rollback is in the existing coordinator backup; compare
post hashes before restoring affected installation files, and use official CLI for
ownership reversal. Do not restore old task events over current work.

Source426+operator7/appfa868ca/r14ZIP/frozen24–38px AND stopped4–14cm unchanged.
No UI/localization/provider/physics/actor/controller/goal change; no AI trial.
Docs maintenance/tests only; app import/fullnative/Web/export/installer unrun.
Original physical precision and pending12–20 calibration choice remain unresolved;
[r23 geometry diagnosis](../projection-r23/README.md), [actual r21 AI](../adaptive-ai-r21/README.md)
and [r22 rejected candidate](../brake-integral-r22/README.md) remain separate.
Native Mac, latest Arch camera raw, fresh account, human merge and exact-version
publication remain. The shared lab Mac received no vault/handoff/private data.
No push/merge/publication/service/schedule/paid fallback/external message.

The first Fable review identified literal question-mark corruption in the r24
STATUS line. It was corrected from the verified intended meaning with UTF-8 bytes
before a new exact-version review; the original review/HEAD remain in the backup.
