# rnl-core-utilities-kit

Swift package: `CoreUtilitiesKit`

Shared non-UI infrastructure utilities extracted from the Record and Learn app for reuse across Apple-platform apps.

## Scope (Phase 1)

This extraction pass intentionally keeps only low-coupling, framework-reusable primitives:

- `CircuitBreaker`
- `DiagnosticsLogger`
- `FileIO`
- `JSONDiskStore`
- `NetworkMonitor`
- `PerformanceTrace`
- `TextSanitizer`

## What Stayed In The App

The following utility files were intentionally not moved because they are app-specific or tightly coupled:

- UI/design/localization utilities (`DesignTokens`, `Localization+Extensions`, `KeyboardDismiss`, `PlatformHaptics`, `WindowAccessor`, `QuizStyleHints`)
- App-domain coupled helpers (`DemoContentProvider`, `LessonRepository`, `DeckRefreshDiffer`, `NLPUtility`, `RAGChunker`)
- App-specific runtime config and events (`FeatureFlags`, `AppLinks`, `Notifications`, `PipelinePerformanceTargets`)

## Compatibility Notes

- `JSONDiskStore` uses a neutral default storage directory (`CoreUtilitiesKitData`) and allows overriding the directory name.
- `JSONDiskStore` supports immediate writes (`saveNow`), debounced writes (`save`), and deterministic flushing (`flushPendingSave`).
- `CircuitBreaker` supports configurable backoff policy (`Configuration`) and state introspection (`retryAfter`, `failureCount`, `reset`, `resetAll`).
- `DiagnosticsLogger` uses a framework-level toggle via environment variable `CORE_UTILS_DIAGNOSTICS` and exposes `redacted(_:)` for safe log preprocessing.
- `NetworkMonitor` exposes a reusable static classifier (`deriveQuality`) for deterministic quality decisions.

## Xcode Integration

Add package dependency in Xcode:

- File -> Add Package Dependencies...
- URL: `https://github.com/mosif16/rnl-core-utilities-kit`
