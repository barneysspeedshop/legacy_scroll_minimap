## 2.0.0

- Migrate library, tests, and example to standalone Material UI without changing widget behavior. Requires Dart 3.13 and Flutter 3.47 or newer; consumers must also use `material_ui` for Material types.

## 1.0.1

* Added optional `scrollController` so wheel and trackpad input over the minimap uses the same `ScrollPosition.pointerScroll` path as the main content.
* Fixed minimap scroll direction to match Flutter `Scrollable` semantics (including reversed axes).
* Treat desktop/Linux trackpad two-finger pans as scroll instead of seek/scrub.
* Updated the package homepage.

## 1.0.0

* Initial release extracted from `legacy_timeline_scrubber`.
* Added `ScrollMinimap`, `MinimapMarker`, `MinimapTheme`, and `MinimapHandle`.
