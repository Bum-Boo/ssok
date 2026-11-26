# 0004 — Three-layer hardware abstraction: board profile / language runtime / block set

- Status: accepted
- Date: 2026-09-10

## Context

The target board is deliberately undecided (see "Open questions" in 0000 and the board-survey
issue), and the learner must be able to choose both a language and, eventually, a board — with
the platform recommending sensible defaults. A single hardcoded board+language pair would have to
be torn out the moment either choice changes.

## Decision

Three layers, and **each must stay ignorant of the other two**:

1. **Board profile** — pin list (number, capability: PWM/DIGITAL/ANALOG), exposed API, a
   recommended language. Knows nothing about interpreters.
2. **Language runtime** — parses source, calls the board profile's API by name and arguments.
   Knows nothing about a specific board or pin numbers.
3. **Block set** — generated from a board profile's exposed API. Never hand-written per language;
   block ↔ code text conversion must round-trip.

The first concrete instances: a virtual `GenericBoard` profile, and a Python/MicroPython-style
runtime as the first language (recommended default; the user can pick others once more runtimes
exist).

## Consequences

- Adding a real board later (Arduino, ESP32, ...) means writing a new board profile only — no
  runtime or block-set changes.
- Adding a language means writing a new runtime that targets the existing board-profile API
  surface — it must not special-case any board.
- More upfront structure than a single hardcoded `Servo.write(pin, angle)` demo would need; this
  is intentional given the user-selectable-language requirement.
