# Releasing

What a maintainer does so that existing users can update with `./update.sh`,
or with `./install.sh` from a downloaded copy, without losing anything.

## Versions

There is one version number, `MAJOR.MINOR.PATCH`, kept in two places:

* `project(... VERSION x.y.z)` in `CMakeLists.txt` — compiled into the engine
  and reported to QML as `TerminalInfo.engineVersion`;
* `"Version"` in `package/metadata.json` — the same `x.y.z`, which Plasma
  shows as the widget's version. *Get New Widgets* does not read it; see
  step 6.

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
3. Add a `CHANGELOG.md` entry under a heading `## X.Y.Z — YYYY-MM-DD` (the
   day you tag): which halves changed (engine, widget package or both), what
   changed for users, and anything an update needs beyond `./update.sh`. Keep
   the bare version as the heading's second word and leave older headings as
   they are: `update.sh` looks for the user's old version there and prints
   only the entries above it.
4. Test the update the way users will run it. In a fresh clone of `main` (the
   previous release) run `./install.sh`, restart plasmashell, add a widget and
   change a few of its settings. Then point that clone at the release with
   `git branch -u origin/<release branch>`, so the previous release's own
   `update.sh` does the pull, as it will for users.
   * If the engine changed, first upgrade only the widget package from your
     checkout of the release with
     `kpackagetool6 --type Plasma/Applet --upgrade package`, restart
     plasmashell, and check that the widget keeps working on the old engine
     and that its *Appearance* page says the engine is outdated.
   * In the clone, run the command the previous release's users are told to
     run: `./update.sh`, or for 1.0, which has none, `git pull` and then
     `./update.sh`. Check that it prints the new CHANGELOG entry and that the
     widgets come back with their settings unchanged.
5. Merge to `main` (users' clones pull from it), then tag the release commit
   `vX.Y.Z` and push the tag.
6. If the widget package changed, build the archive with
   `(cd package && zip -r ../io.github.cir0cuit.plasmaterminal-X.Y.Z.plasmoid .)`, upload
   it to the KDE Store entry and set the entry's version to `X.Y.Z`. *Get New
   Widgets* compares that version with the one it recorded at install time.
