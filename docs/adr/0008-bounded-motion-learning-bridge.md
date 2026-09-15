# 0008 — Bounded motion search through an optional external bridge

- Status: accepted
- Date: 2026-09-15

## Context

The user requested GPT-5.6 Luna API/MCP integration, prior research and implementation
for learning robot movement. Existing WASD commands already feed a replaceable joint
program. The experimental biped gait is a useful evaluation target, but an API call
cannot replace the real-time physics loop and a model proposal is not a verified skill.

## Decision

- Keep ADR 0001's Godot runtime unchanged: GDScript, GL Compatibility, web and desktop,
  asynchronous HTTPRequest only. Add an **optional external Python developer service**
  under `tools/motion_lab/`, not a Python runtime dependency of exported Godot clients.
  Like Blender build tooling, its native process/file capabilities are outside the client.
- The service owns `OPENAI_API_KEY` and calls the Responses API using `gpt-5.6-luna`.
  No silent model fallback, client-side API keys, model-generated code execution, or
  general shell/file tools. Structured proposals are four bounded biped gait parameters.
- Interpret this slice's learning as feedback-guided parameter search, not GPT fine-tuning
  or reinforcement learning. Evaluate the baseline and each candidate using the same
  graph-derived Godot physics, duration and scoring rule. Keep measured history and best
  result, including failure. No success claim without observed displacement/stability.
- Graph snapshots contain catalog IDs, rigid transforms and validated links only. They
  are a transport representation of ConnectionGraph, not a second assembly authority.
  No arbitrary resource paths or modifications to the assembly/board/language layer.
- Each evaluation starts an isolated simulation. Limit iterations, output tokens, request
  sizes, simultaneous jobs, process runtime and total live calls per service session.
  Cancellation prevents later evaluations/proposals; an in-flight API request may still
  be billed. Do not automatically retry paid requests.
- Local HTTP binds loopback with bearer-token authentication and explicit browser-origin
  allowlists; production web needs a separately deployed authenticated HTTPS service.
  Optional MCP uses the official Python SDK over stdio and exposes only describe,
  start, inspect and cancel. It is not advertised as a remote Responses MCP endpoint.
- Applying the best evaluated policy is an explicit action in the Godot UI, only while
  editing and only if the assembly snapshot still matches. Save/load of a learned policy
  stays under `user://`; saved parameters never silently replace user source code.

## Consequences

- Existing ADRs remain accepted; this is an optional service boundary, not an engine,
  renderer, physics, board API, or language-runtime migration.
- The first policy family supports the wired biped only. Other robots need their own
  bounded program and evaluator. The service does not promise universal locomotion,
  better movement on every search, sim-to-real transfer or physical robot safety.
- Mock mode tests the complete proposal/evaluation workflow without claiming GPT usage.
  Live verification additionally requires a user-provided key and model access.
- General RL (e.g. Godot RL Agents), arbitrary generated-code sandboxing, remote MCP,
  authentication for multi-user hosting, and sim-to-real are future independent scopes.
