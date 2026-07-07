# ADR-002: Adopt V4.0 Open Source Fusion, Node Exit And Dual-Platform First Release

## Status

Accepted

## Date

2026-07-06

## Context

V2.0 established the Flutter Desktop Mac App and Dart Runtime as the main path. V3.0 established the cross-platform mobile runtime direction. The next product goal is larger: iOS Assist Studio should become a local visual mobile automation workstation that can absorb mature ideas from strong open source projects instead of rebuilding every capability from scratch.

The four core projects selected for V4.0 fusion are:

- Airtest
- Pyxelator
- Appium Inspector
- appium-mcp

The project also has a legacy Node history, but Node no longer supports the desired 4.0 shape. Keeping Node as a possible fallback would create architecture drift, duplicated state machines and unclear ownership.

V4.0 also cannot treat Android as a second-class future placeholder. The product remains iOS-first in verification depth, but the architecture and first release must include an Android true-device smoke path.

## Decision

Adopt V4.0 open source fusion with the following non-negotiable decisions:

1. Flutter Desktop Mac App remains the product entry.
2. Dart Runtime remains the main orchestration layer.
3. Appium remains the main automation protocol for both iOS and Android.
4. Python Sidecar is accepted as a formal V4.0 component for Airtest, Pyxelator, CV and OCR.
5. Node middleware is not restored. No new Node API, Node runner or Node MCP service may enter the main path.
6. Android must be part of the V4.0 first release smoke acceptance.
7. Open source absorption follows this order: dependency, adapter, port, small-module copy, product reference, self-build.
8. Any copied or vendored third-party code must live under `third_party/` and be recorded in `THIRD_PARTY_NOTICES.md`.
9. AppiumAir is not a V4.0 core fusion project; it remains a historical reference only.

V4.0 absorbs the four projects as follows:

| Project | Decision |
|---|---|
| Airtest | Use as Python Sidecar dependency and report / visual automation reference. Do not make `.air` the workflow source of truth. |
| Pyxelator | Use as lightweight image target resolver. Prefer dependency; allow copying small stable modules with notice. |
| Appium Inspector | Recreate Inspector capabilities in Flutter. Do not embed Electron or copy the UI. |
| appium-mcp | Port the tool model and permission ideas. Do not introduce Node MCP runtime. |

## Alternatives Considered

### Copy all four projects directly

Pros:

- Maximum short-term reuse.
- Faster access to existing behavior.

Cons:

- Mixed languages and UI stacks would become unmaintainable.
- Electron, Node, Python and Dart would all own parts of the product UI or runtime.
- Runtime safety and Project DSL ownership would fragment.

Rejected because V4.0 needs integration, not accumulation.

### Keep Node as an optional AI or MCP layer

Pros:

- appium-mcp could be used with less porting work.
- Existing JavaScript ecosystem would be convenient for some integrations.

Cons:

- Reintroduces the exact middle layer the project has already moved away from.
- Creates competing runtime ownership.
- Makes future deletion harder.

Rejected. appium-mcp is absorbed at the protocol and tool-model level only.

### Keep Android as architecture-only future work

Pros:

- Faster iOS delivery.
- Less initial testing burden.

Cons:

- Android would again become a delayed sidecar.
- DSL and Runtime decisions could accidentally remain iOS-shaped.
- 4.0 would fail the Mobile First ambition.

Rejected. Android must pass true-device smoke in the first 4.0 release.

### Make Airtest the universal engine

Pros:

- Mature visual automation and reporting.
- Strong cross-platform story.

Cons:

- Would replace Appium/WDA and Appium/UiAutomator2 as the main driver path.
- Would make Project DSL secondary.
- Would turn visual automation into an execution path instead of a resolver.

Rejected for core execution. Airtest is accepted as a sidecar capability.

## Consequences

Positive:

- The project can absorb mature solutions without losing its own architecture.
- Python visual capabilities become first-class but isolated.
- Android becomes a real product path from the first 4.0 release.
- Node drift is stopped explicitly.
- Third-party code governance is clear before copying begins.

Trade-offs:

- Some appium-mcp features must be ported instead of reused directly.
- Appium Inspector UI value must be rebuilt in Flutter.
- Python Sidecar adds dependency probing and error handling requirements.
- Android smoke adds hardware and environment validation burden.

## Follow-Up Work

- Add V4.0 docs and route them from `docs/README.md`, `AI_PROJECT_CONTEXT.md` and `AGENTS.md`.
- Add `THIRD_PARTY_NOTICES.md`.
- Add a V4 boundary check before code fusion begins.
- Design Python Sidecar contract.
- Design TargetResolver and VisionProvider contracts.
- Plan Legacy Node deletion after Dart Runtime coverage is complete.
- Add Android true-device smoke checklist.

## References

- `docs/V4.0-PRD-Mobile-Automation-Workstation.md`
- `docs/V4.0-Architecture-Integrated-Mobile-Workstation.md`
- `docs/V4.0-Open-Source-Integration-Plan.md`
- `docs/V4.0-Development-Roadmap.md`
