# Changelog

Every release lists what changed and whether updating needs anything beyond
the usual `./update.sh` — see [Updating](README.md#updating).

The widget comes in two halves that are installed separately: the **engine**
(the compiled QML module, installed system-wide) and the **widget package**
(the QML plasmoid, installed per user or from *Get New Widgets*). Each entry
says which halves changed. When the engine changed, updating only the widget
package is not enough; the widget's settings page says so if it happens.

## 1.1.0 — 2026-11-04

Halves changed: **engine and widget package** — rebuild the engine.

### Added

- **Font style.** *Appearance → Style* picks any style the font family is
  installed in — Thin, Light, Regular, Medium, SemiBold, Italic and so on —
  not only the family itself. Bold text still uses the family's real Bold
  face, whatever style the rest of the text is in.
  ([#7](https://github.com/Cir0cuit/plasma-terminal-widget/issues/7))
- *Match my Konsole profile* now follows the profile's font style as well as
  its family and size.
- `update.sh`, which updates an installation made from a git checkout in one
  step.
- The engine reports its version, so a widget package newer than the
  installed engine says so in its settings instead of failing quietly.

### Changed

- If your Konsole profile uses a style other than Regular and the widget
  follows that profile, the widget now draws text in that style too.

### Updating from 1.0

Run `./update.sh` in your clone; existing widgets keep all their settings.
A 1.0 engine keeps working with the 1.1 widget package, minus the font style
setting, until it is rebuilt.

## 1.0.0

First release.
