# 0043 — Light the bench as a miniature workshop with a studio part shader and run-mode feedback

- Status: accepted
- Date: 2026-11-26
- Implements: owner's graphics direction A ("미니어처 공작실 / Tinker Workbench") of 2026-11-26: a desk-lamp lit cutting mat, metal that does not go black in GL Compatibility, and functional LED, sonar and snap feedback.
- Partially supersedes: [0031](0031-workshop-presentation-corrections.md), only "Keep light colors" for the mat, grid, sky and fog values and the line-mesh grid. Immediate appearance switching, finite mat edges and thickness, and the collision-free decoration remain.
- Partially supersedes: [0042](0042-tray-pictures-and-part-cards.md), only the "Dark theme reflections" mechanism (a lit neutral sky reflected by kit metal). The plain dark background remains.
- Extends: 0001, 0030, 0031 and 0039. Engine, renderer, graph, physics, runtime APIs and stage rules are unchanged.

## Context

In GL Compatibility (and on the Web) the bench read flat: one directional light without
tuned biases, a colour ambient, and a light mat that clipped to white. Metallic kit parts have no
diffuse term, so they only showed what the sky gave them to reflect; ADR 0042 kept a lit sky for
that, which tied part brightness to the backdrop. Run mode gave no visible cue that a sensor was
reading or an LED was lit beyond its small lens, and snap rings were thin flat discs.

## Decision

- **Lighting (`WorkshopLook`).** A warm key "desk lamp" with two-split shadows (biases chosen on
  close renders against acne and detached contact shadows), a cool fill and a faint rim, both
  without shadow maps and with low specular so they cannot glare on the matte mat. Colour
  ambient, no radiance map, Reinhard tonemapping. Energies are balanced on actual Compatibility
  renders. Light and dark palettes are data in one place.
- **Part surfaces (`WorkshopMaterials`, `workshop_part.gdshader`).** Each catalog
  `StandardMaterial3D` that the shader can reproduce (opaque, per-pixel, at most a triplanar normal
  map) is shown through one shared shader: Godot's direct lights and shadows plus a studio
  hemisphere and lamp reflection in place of ambient light, a split-sum Fresnel, a brighter
  metal reflectance, a small dark-albedo floor and a faint grazing sheen. The catalog stays the
  only source of colour, metallic, roughness and normal values: conversion is deterministic,
  cached per source material and applied as per-instance surface overrides; catalog meshes and
  materials are never modified. Anything else keeps its `StandardMaterial3D`.
- **Cutting mat (`cutting_mat.gdshader`, `workbench_desk.gdshader`).** The mat is a lit procedural
  shader: 1 cm and 5 cm lines filtered against their own screen footprint (no moire), a ruler band
  with 1/5/10 cm ticks, a soft fade where the grid meets the band, and low mottling. A desk plane
  under the rim fades into the theme's backdrop. Light theme: soft sage; dark theme: deep slate.
- **Run-mode feedback.** A lit LED adds an additive camera-facing halo over its lens. When the
  learner's program reads an ultrasonic sensor (`distance_cm`, `distance`, `time_pulse_us`), a
  translucent cone with travelling pulses is drawn from the sensor's ray origin to the measured
  echo, fading shortly after the last reading. Evaluators read with `measure_cm()` and draw
  nothing. The cone lives on visual layer 20, which the robot camera does not render.
- **Snap feedback.** Free-hole rings get a crisp core and a soft halo; the snap target adds a white
  inner edge and a slow pulse. The placement ghost is a translucent tint with a bright Fresnel
  edge, in the accent colour when valid and the error colour when blocked.
- **WebGL2 limits.** Only directional lights, shadow maps, colour ambient, the tonemapper and
  unshaded/alpha or additive materials are used. No SDFGI, SSAO, SSIL, SSR, glow, volumetric fog
  or screen textures; shaders use no loops and take derivatives only in uniform control flow.

## Consequences

- Visual only: no graph, physics, observation, stage rule, project schema or locale change.
- New part materials are converted automatically when they stay within the supported features;
  part meshes can be replaced without touching the look.
- Placeholder geometry (for example the flat 90 mm wheel, whose faces receive no direct light)
  still looks like a placeholder; fixing meshes is separate work.
- Before/after renders come from `tools/lookdev/capture_look.gd`. Web export and low-end GPU
  frame times were not measured for this decision.
