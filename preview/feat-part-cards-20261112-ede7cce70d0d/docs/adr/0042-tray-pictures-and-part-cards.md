# 0042 — Show tray parts as pictures and name the real product behind each

- Status: accepted
- Date: 2026-11-12
- Implements: owner feedback of 2026-11-11 that parts must be grounded in products that are actually sold, and step E2 of [ssok-redesign-20261111](../design/ssok-redesign-20261111.md).
- Extends: 0039, 0040 and 0041. The curated tray, electrical tiers and docked panels remain accepted. No accepted scope is superseded.

## Context

The tray listed 49 parts as text with one of three generic icons, so a learner could not tell a
gear motor from a servo before placing it. Nothing told a learner which purchasable product a part
stands for, or what that product can take electrically.

## Decision

- **Pictures.** Each tray row shows a 128 px picture rendered from the part's own mesh by
  `tools/godot/make_part_thumbnails.gd` into `assets/part_thumbnails/`. The pictures are generated
  files: rerun the tool when a mesh changes. A part without a picture keeps its generic icon.
- **Part card.** The tray shows a card for the part under the pointer or keyboard focus: picture,
  name, the real product, its ratings and where the numbers come from.
- **Ratings data.** `assets/part_specs.json` holds the product and ratings per part id. A value is
  listed only if it was read on the cited page; unknown values are left out, not estimated. Row
  labels are translation keys and values are numbers with units, so one file serves every language.
- **Tiles by category.** Tray parts are picture tiles, three to a row, under a heading for each
  category (structure, motion, electronics, sensors, environment). A category with nothing to
  show hides its heading. The tray is 292 px wide.
- **Blocks as cards.** Each program block is a filled card with a colour bar for its kind: action,
  wait and control, sensor reading, or connection. Removing a block is an icon button.
- **Dark theme reflections.** Kit metal mirrors the sky, so a dark sky turned plates and beams
  black. The dark theme draws a plain dark background and keeps a lit neutral sky for reflections.
  Part pictures use a near-white tint that the theme does not treat as a palette colour.
- **No behaviour yet.** The card informs. Electrical tiers 2 and 3 will read the same numbers when
  they are implemented.

## Consequences

- Placeholder meshes still look like placeholders in their pictures.
- Branch previews leave out `docs/evidence` (see `docs/BUILD.md`) so that several previews fit the
  Pages size limit.
