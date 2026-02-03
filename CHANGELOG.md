# Changelog
All notable changes to this project will be documented here.

## [v0.4.0] - 2026-02-03
- Weather + music widget alignment now centers on the arc apex (visual layout tightened).
- Removed dependency on `vline.png` (now drawn via Lua/Cairo).
- Added suite/theme/cache path overrides (`CONKY_SUITE_DIR`, `CONKY_THEME_PATH`, `CONKY_CACHE_DIR`) and updated docs.
- Fixed OpenWeather forecast refresh so forecast JSON and icons are always generated.
- Moved METAR/TAF caches and other temp data into the cache dir (RAM-friendly).

## [v0.3.0] - 2026-01-03
- Added lyrics module and lyrics window widget (with example vars file).
- Added pfSense widget SSH safety via shared circuit breaker to prevent sshguard lockouts.
- Added Zyxel WBE530 access point widget with SSH protection and optional IP-to-label mapping.
- Documented SSH mitigation behavior and optional single-widget launcher pattern.
- Normalized file permissions so only scripts are executable.

## [v0.1.0] - 2025-11-22
- Initial public release: modular widgets, centralized theme.lua, screenshots, MIT license.
