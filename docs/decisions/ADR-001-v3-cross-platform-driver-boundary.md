# ADR-001: Adopt Cross-Platform Mobile Driver Boundary For V3.0

## Status

Accepted

## Date

2026-06-30

## Context

V2.0 established iOS Assist Studio as a local iPhone automation workstation:

- Flutter Desktop Mac App is the product entry.
- Dart Runtime owns connection, workflow execution, evidence and monitor data.
- Appium / WDA / XCUITest is the iOS main driver chain.
- Project DSL is the workflow source of truth.
- The product is local, single-user, single-device and serial.

The V3.0 product direction expands the workstation to solve pain points already demonstrated by competitive mobile automation products, especially TestHub's APP automation module:

- device as a resource, not a passive config
- remote control and automation sharing the same device system
- target / element management
- visual, OCR and coordinate strategies for non-standard apps
- execution status separated from test result
- local evidence, logs, performance and report diagnosis

Keeping the current iOS-specific Runtime as the top-level architecture would make Android support and Target Library support feel like add-ons. It would also spread platform conditionals across Flutter pages, Runtime commands, Workflow nodes and evidence models.

We need a reversible but explicit boundary that lets the product embrace cross-platform mobile automation without losing V2.0 safety constraints.

## Decision

Adopt a cross-platform mobile driver boundary for V3.0.

The Runtime will depend on a platform-neutral mobile driver abstraction instead of directly depending on iOS-specific concepts in higher-level workflow, device, recorder, execute and monitor flows.

Conceptual boundary:

```text
Flutter Desktop Mac App
  -> Dart Runtime
  -> MobileDeviceDriver abstraction
      -> iOS adapter
          -> Appium / WDA / XCUITest
      -> Android adapter
          -> Appium UiAutomator2 / ADB
```

The driver boundary must expose:

- platform
- masked current device
- capability report
- connect / disconnect / heartbeat
- screenshot
- page source when available
- tap / swipe / input
- app launch / stop
- logs and performance where supported
- action cleanup / release behavior

V3.0 will also introduce Target Library and Target Resolver as Runtime-owned concepts. OCR, CV, Airtest or scrcpy may support target resolution or remote control, but they must not bypass the Runtime state machine or become hidden second execution paths.

## Alternatives Considered

### Keep V2.0 iOS Runtime and add Android branches inline

Pros:

- Fastest short-term implementation.
- Minimal package reshaping.
- Existing iOS code remains familiar.

Cons:

- Platform conditionals would spread across UI, Runtime, DSL and tests.
- Android would feel like a sidecar rather than a first-class path.
- Target Library would need to know too much about iOS and Android execution details.
- Long-term maintenance cost would rise quickly.

Rejected because V3.0 is a product direction change, not a small platform flag.

### Build a separate Android product path

Pros:

- Keeps iOS code untouched.
- Allows Android-specific technology choices like ADB, scrcpy and Airtest without waiting for abstraction.

Cons:

- Duplicates Device, Recorder, Workflow, Execute and Monitor concepts.
- Breaks the single workstation mental model.
- Creates two evidence models and two state machines.
- Makes cross-platform workflow reuse difficult.

Rejected because V3.0 must feel like one mobile workstation.

### Use Airtest as the universal automation engine

Pros:

- Strong visual automation story.
- Proven for Android image-based workflows.
- Aligns with some competitive product choices.

Cons:

- Does not preserve iOS Appium / WDA as the main driver boundary.
- Would make visual automation the core path instead of an auxiliary capability.
- Increases risk of low-confidence blind actions.
- Would disrupt existing Project DSL and Runtime safety model.

Rejected for core execution. Airtest may be considered as an Android auxiliary adapter or target resolution helper later.

### Use Appium only and ignore ADB / scrcpy / OCR / CV

Pros:

- Cleaner abstraction.
- Works across iOS and Android at protocol level.
- Reduces dependency surface.

Cons:

- Does not fully address non-standard APP target pain.
- Does not cover strong Android remote control needs.
- Leaves performance/log collection weaker than competitive products.

Rejected as the full V3.0 strategy. Appium remains important, but adapter capabilities may use platform-native helpers.

## Consequences

Positive:

- iOS and Android can share Device, Recorder, Workflow, Execute and Monitor surfaces.
- Platform differences are localized in adapters and capability reports.
- Target Library can become platform-aware without becoming UI-specific.
- Existing iOS Appium / WDA chain can be preserved as the iOS adapter.
- Tests can use fake drivers to validate Runtime without real devices.

Trade-offs:

- Runtime models need migration from iOS-specific names to platform-neutral names.
- Some V2.0 UI copy and readiness helpers must learn platform-aware labels.
- Adapter abstraction adds design overhead before Android features ship.
- Capability reports must be maintained carefully to avoid hidden platform behavior.

Non-negotiable constraints:

- Single current device only.
- Serial execution only.
- Safe stop remains required.
- Runtime owns all device actions.
- Target Resolver cannot directly click.
- Visual / OCR low confidence must pause or fail safely.
- No cloud upload by default.
- No Node middleware in the V3.0 main path.
- No multi-device farm or team platform behavior.

## Follow-Up Work

- Define `MobilePlatform`, `MobileDevice`, `DeviceResourceState` and capability report models.
- Wrap current iOS Appium / WDA session manager behind the iOS adapter.
- Add fake driver tests before introducing real Android support.
- Design Target Library models and validation.
- Update Workflow DSL with `targetRef` while keeping existing coordinate nodes compatible.
- Add Android adapter only after the iOS adapter boundary is stable.

## References

- `docs/V3.0-Competitive-Strategy-TestHub.md`
- `docs/V3.0-PRD-Cross-Platform-Mobile-Workstation.md`
- `docs/V3.0-Architecture-Cross-Platform-Runtime.md`
- `docs/V3.0-Development-Plan.md`
