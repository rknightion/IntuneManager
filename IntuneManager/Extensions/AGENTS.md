# Extensions Guidance

## Scope
- Applies to files under `IntuneManager/Extensions/`.

## Practices
- Keep extensions narrowly scoped and additive; avoid overriding system behavior unless absolutely necessary.
- Group related extensions into single files (e.g., all color helpers in `Color+*.swift`) and document usage with brief comments when behavior is non-obvious.
- Before adding a new extension, check for existing helpers in `Core/CrossPlatform` or `Utilities` to prevent duplication.
