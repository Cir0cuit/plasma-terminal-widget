# Releasing

What a maintainer does so that existing users can update with `./update.sh`
(or by hand, as the README describes) without losing anything.

## Versions

There is one version number, `MAJOR.MINOR.PATCH`, kept in two places:

* `project(... VERSION x.y.z)` in `CMakeLists.txt` — compiled into the engine
  and reported to QML as `TerminalInfo.engineVersion`;
* `"Version"` in `package/metadata.json` — what Plasma shows for the widget
  package and what *Get New Widgets* compares against (`x.y`).

`package/contents/ui/version.js` holds a third, different number:
`requiredEngine`, the **oldest engine this widget package works with**. It
only moves when the QML starts to use something a newer engine provides. When
the installed engine is older, the *Appearance* settings page tells the user to
rebuild it, and the QML must keep working without the new engine API — check
`engineOutdated` before calling it.

## Settings

Users' settings live in Plasma's config, keyed by the entry names in
`package/contents/config/main.xml`. So:

* never rename or remove an entry, or change what its stored values mean —
  add a new entry instead and leave the old one readable;
* give every new entry a default that reproduces the previous behaviour, so an
  update changes nothing until the user changes a setting.

## Checklist

1. Bump the version in `CMakeLists.txt` and `package/metadata.json`.
2. If the QML now needs the new engine, raise `requiredEngine` in
   `package/contents/ui/version.js` to the same version, and make sure the
   affected QML degrades when `engineOutdated` is true.
3. Add a `CHANGELOG.md` entry: the date, which halves changed (engine, widget
   package or both), what changed for users, and anything an update needs
   beyond `./update.sh`.
4. Update an existing installation of the previous release with
   `./update.sh` and check that the widgets come back with their settings
   unchanged. If the engine changed, also try the new widget package against
   the old engine and check that it degrades and says so.
5. Merge to `main` (users' clones pull from it), then tag the merge commit
   `vX.Y.Z` and push the tag.
6. If the widget package changed, upload the new `package/` archive to the
   KDE Store so *Get New Widgets* offers it.
