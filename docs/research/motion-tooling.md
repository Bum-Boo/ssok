# Motion tooling research

Research date: 2026-09-15. Scope: Godot learning environments, existing Godot MCP
bridges, and the smallest tool boundary appropriate for ssok. This is a design
input, not evidence that a learned ssok gait already works.

Exa search coverage: `sources_reviewed = 29` (requested result counts 8 + 8 + 8 +
5 across four distinct queries). This count is search exposure, not 29 independent
validated projects. Author repositories and official documentation below were
then fetched; duplicate Godot documentation revisions and third-party MCP
directories were not treated as independent evidence.

## Findings

| Primary source | Verified year / license | Method | Limitation and ssok fit | Source quality |
|---|---|---|---|---|
| [Godot RL Agents](https://github.com/edbeeching/godot_rl_agents) | Repository created 2021; README cites AAAI 2022 workshop; MIT | Godot environments communicate with Python training code; wrappers support Stable Baselines3, Sample Factory, RLlib and CleanRL | Useful future observation/action/reward and episode-reset reference. Its documented experimental ONNX deployment uses Mono/C#; that path conflicts with ssok's GDScript-only web runtime. Do not install that inference layer into the app. | Authors maintain executable examples, custom-environment documentation and tests; claims here are from their README, not an independent performance benchmark. |
| [Coding-Solo Godot MCP](https://github.com/Coding-Solo/godot-mcp) | Repository created 2025; MIT | Node-side MCP server invokes Godot CLI and a bundled GDScript operations script; captures execution/debug feedback | Confirms an external bridge plus fixed Godot script is practical. Its editor launch, project discovery, scene creation and node-edit tools exceed motion-learning scope; do not copy its broad auto-approval configuration. | Original implementation with documented tool surface and architecture, not a server-directory listing. No ssok integration was tested from this project. |
| [MCP transport specification](https://modelcontextprotocol.io/specification/2026-07-28/basic/transports) and [2025 transport revision](https://modelcontextprotocol.io/specification/2025-11-25/basic/transports) | Versioned 2026-07-28 and 2025-11-25; no license conclusion needed for API use | stdio transports newline-delimited JSON-RPC between a host and its subprocess; Streamable HTTP serves remote clients | MCP is a tool protocol, not a learning algorithm or model API. A local stdio server is not a public endpoint that a remote model service can contact. Protocol eras differ; let a pinned official SDK handle compatibility. | Normative, versioned protocol documentation. |
| [Official Python MCP SDK](https://github.com/modelcontextprotocol/python-sdk), [client docs](https://py.sdk.modelcontextprotocol.io/client/) and [PyPI release](https://pypi.org/project/mcp/2.2.0/) | 2.2.0 uploaded 2026-09-07; MIT; Python >= 3.10 | Current v2 uses `MCPServer` and typed tool functions, with an in-memory/stdio-capable `Client`; supports the 2026-07-28 protocol and older revisions | Optional development-tool dependency only; not part of the Godot export. Pin the tested release. Earlier `FastMCP` examples belong to v1, so mixing cached pages and v2 imports is unsafe. | Author SDK plus direct current PyPI metadata. An Exa-cached PyPI response showed 2.1.1; direct metadata was checked before choosing 2.2.0. |
| [MCP security guidance](https://modelcontextprotocol.io/docs/2026-07-28/tutorials/security/security_best_practices.md) | Versioned 2026-07-28; no license conclusion needed for API use | Consent, least privilege, token audience separation, SSRF and local-server defenses | Keep API credentials in the operator-owned service environment. No credential fields, arbitrary URLs, file paths or shell commands in model-callable tools. Public hosting needs its own authentication/deployment work. | Official threat-model guidance; does not certify this implementation. |
| [Godot web export networking](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html) and [HTTPRequest](https://docs.godotengine.org/en/stable/classes/class_httprequest.html) | Versioned release year not asserted; Godot documentation | Async HTTP client supported in web exports; browser networking obeys same-origin restrictions and cannot use threaded/blocking HTTP | Keep the app's GDScript `HTTPRequest` asynchronous. A hosted HTTPS page needs an appropriately secured/reachable backend and CORS configuration; desktop localhost success is not web-export verification. | Official engine documentation; deployment behavior must still be tested in the target browser. |

## Recommendation for this slice

The following is an ssok-specific inference from the sources and accepted ADRs,
not a feature claimed by those upstream projects:

1. Preserve the graph-derived simulator and the replaceable movement-program
   boundary. Learn bounded movement-program parameters, not a model's weights.
2. Put the API client, credentials, request budget and fixed headless-trial worker
   in an optional operator-side service. The exported app stays GDScript-only.
3. Offer exactly four optional local MCP tools: describe the lab, start a bounded
   search, get its status and cancel it. Do not expose source execution, shell
   access, arbitrary file reads, scene mutation or automatic policy application.
4. Use one service implementation behind both ordinary HTTP and MCP adapters.
   MCP does not need to sit between the app and every model request.
5. Treat every generated proposal as untrusted data: strict finite-number bounds,
   fixed trial scripts, limited rounds and elapsed time, recorded metrics and a
   separate human Apply action. A successful API call is not a successful gait.
6. Default to a clearly labelled offline/mock proposal source. Paid requests
   require operator live-mode configuration and explicit per-search consent.

The optional MCP adapter should be tested through the real SDK, including stdio
launch, exact tool discovery, malformed arguments, unknown tools, cancellation and
absence of API-key fields. The research itself does not verify a real API account,
the requested model identifier, a production web deployment, or physical-robot
transfer.

## Search log

| Angle | Requested results |
|---|---:|
| Original Godot RL Agents Python/GDScript training framework and license | 8 |
| Original Godot MCP implementation, process/editor tools and license | 8 |
| Official MCP stdio/JSON-RPC lifecycle and security | 8 |
| Official Godot HTTPRequest and browser-network restrictions | 5 |

No upstream code was copied or dependencies installed merely to obtain these
research findings. Any later implementation or dependency installation is a
separate, testable development step.
