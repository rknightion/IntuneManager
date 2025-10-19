# Utilities Guidance

## Scope
- Applies to helpers under `IntuneManager/Utilities/` (currently `Logger`).

## Practices
- Prefer enhancing `Logger` instead of scattering logging helpers. Use categories and levels (`info`, `warning`, `error`) consistently.
- Utility additions should be platform-agnostic and broadly reusable. If a helper is feature-specific, place it alongside that feature instead.
- Keep APIs stateless where possible; if shared state is required, document initialization order and thread-safety expectations.
