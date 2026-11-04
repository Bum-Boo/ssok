# CLI terminal diagnostics r40

2026-10-11 local issue32 draft. Base f3741c8, run_goal SHA4987b77a81b5842b827a7d2e67ffb45296a5d387cd642955ccaae5c54363d2d4. No app or optical change.

The r37 case5 CLIexit1 cause was lost because the collector only handled item.error. It is historically unrecoverable. Official [Codex non-interactive documentation](https://learn.chatgpt.com/docs/non-interactive-mode), accessed2026-10-11, lists top-level error and turn.failed. The new collector retains their bounded diagnostic messages plus legacy item errors, type/tool labels and integer token usage. It drops assistant/reasoning payloads, IDs, encoded images and raw stderr. Token/whole-goal/Bearer/key/UUID/URL/path/data redaction precedes the400character cap. Redaction is not universal: transformed or partial goal echoes can survive; row count is not capped. Stderr-only causes remain unavailable.

Independent actual Fable5-1 first review PASS found a pre-existing race: CLI could exit between communicate timeout and context polling, leaving stdout unbound and losing result.json. The v2 drain always collects after the loop. A precise runner fixture covers timeout→stoppedcontext→already-exitedCLI, scopedStop, terminalreceipt andexit1. MalformedJSON is also fed through the runner. Actual stdlib child-process pipes independently confirm timeout/partial output and repeated communicate on an already-exited process return identical bytes. This is not a live Codex/provider failure reproduction.

Actual r40 cwd/source binding and receipts beside this note:26session tests (MCP SDK present),32client,13operator and10docs tests PASS; independent separate Fable5-1 final code review PASS. Actor/provider/requestedgpt-6-astra/retry0/budgets/scopedStop/physics/goal unchanged. Backend identity and the historical precision failure remain uncertified. No model trial retry was made.

Coordinator prepares a uniquely versioned operator archive after commit; latest Fable owns actualfetch/rebase, human merges. No push/publication. Original r14 archives remain unchanged. Exact review artifacts and recovery backups are linked from the existing task handoff, never sent to the shared Mac.
