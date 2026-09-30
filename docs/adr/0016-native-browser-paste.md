# 0016 — Preserve native browser paste before Godot text editing

- Status: accepted
- Date: 2026-09-22
- Extends: 0001 and 0007; engine, renderer and application language remain unchanged.

## Context

In the pinned Godot 4.7.2 Web export, keyboard handlers prevent the browser's default paste.
The engine's clipboard getter starts an asynchronous browser read and immediately returns its
previous cached text. A first Ctrl+V can therefore leave project names and JSON transfer fields
unchanged. Real Chromium 151 and 153 checks reproduced the failure; ordinary HTML text fields
in the same test environment accepted the same clipboard text.

## Decision

- Keep the application in GDScript and the exact engine pin. A small `WebClipboard` node installs
  constant JavaScript through Godot's existing `JavaScriptBridge` only on the Web target.
- Capture a trusted Ctrl/Meta+V directed at the Godot canvas or its IME element before the engine
  key handler. Stop propagation without cancelling the browser's native paste operation.
- Handle the resulting trusted paste after Godot's existing listener has populated its clipboard
  cache. Dispatch one synthetic paste shortcut to the original element so Godot still performs
  text insertion, selection replacement, signals and undo through its normal editor action.
- Ignore synthetic shortcuts during interception. Leave unrelated page inputs and other shortcuts
  alone. Make installation idempotent and remove the listeners when the owning node exits.
- Do not read the clipboard proactively, request clipboard permissions in the product, evaluate
  learner text as JavaScript, or replace text fields through a separate DOM editing model.

## Consequences

This is a browser input compatibility boundary, not another language runtime or an engine
migration. Desktop input keeps its native path. Browser tests must exercise actual trusted paste,
saved project names and shared JSON import; synthetic DOM text insertion cannot certify this fix.
No new user-facing text is introduced, so language-pack updates are unnecessary.

Pinned upstream behavior:
[Web display server clipboard implementation](https://github.com/godotengine/godot/blob/4.7.2-stable/platform/web/display_server_web.cpp),
[Web JavaScript input handlers](https://github.com/godotengine/godot/blob/4.7.2-stable/platform/web/js/libs/library_godot_input.js).
