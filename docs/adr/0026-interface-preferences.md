# 0026 — Local interface preferences without rebuilding learner work

- Status: accepted
- Date: 2026-09-30
- Implements: issue #38 and the owner's instruction to implement the settings/theme/locale audit recommendations.
- Extends: 0007 (input ownership), 0016 (native/browser behavior), 0023 (bounded running VM). No engine, physics, graph or board decisions change.

## Decision

Keep interface appearance, separate UI/code text scales and effects audio in a validated local ConfigFile, outside project/graph/challenge records. Retain the existing language preference file and supported locales. Restore defaults preserves language and learner work.

Use system appearance by default where supported, explicit light/dark overrides, and the existing dark appearance when native detection is unsupported. Web uses a bounded, once-per-second matchMedia check; native uses the supported DisplayServer callback. No network/provider is needed.

Update the shared Theme resource and existing semantic overrides in place. Never reconstruct the workshop or block draft to change theme, scale or language. Block headings retain original translation keys; formatted raw captions bind a source and preserve learner content. Keep language focus and restore the settings entry focus on close.

Settings stop manual input and camera/assembly manipulation while open, without cancelling a running learner VM or rebuilding physics. Resume manual availability on close with neutral input; focused UI controls still block movement. Changing preferences never changes the physical success predicate or 3D materials.

Small windows show one starting instruction instead of overlapping duplicate cards. Larger text can scroll; long toolbar actions retain tooltips when compacted to icons. UI/code scales are independently bounded to the declared options, including 200%.

## Consequences

Saving failure keeps the applied value and shows a localized recovery message. Invalid saved types/ranges fall back independently. Browser storage clearing removes preferences; no account synchronization is claimed. CJK catalogs, actual native screenshots, keyboard/draft/run preservation and Web/Linux verification accompany the implementation. Source-specific verification is documented separately from accessibility compliance and public release.
