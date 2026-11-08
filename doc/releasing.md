# Releasing

What a maintainer does so that existing users can update without losing
anything, whether they run `git pull` and `./update.sh` or update the widget
from *Get New Widgets* first.

## Versions

There is one version number, `MAJOR.MINOR.PATCH`, kept in two places:

* `project(... VERSION x.y.z)` in `CMakeLists.txt` — compiled into the engine
  and reported to QML as `TerminalInfo.engineVersion`. The build also writes
  it to a file named `version` in the engine's QML module directory, which is
  installed next to the plugin; `install.sh` and `update.sh` read the
  installed engine's version from there. An engine without that file is
  1.0.0.
* `"Version"` in `package/metadata.json` — the same `x.y.z`, which Plasma
  shows as the widget's version. The KDE Store entry's version and date decide
  whether *Get New Widgets* offers an update; KPackage then replaces the
  installed files only if this `Version` is strictly higher than the installed
  one. If it is not, the update still reports success and the old files stay.

`install.sh` and `update.sh` compare both installed halves with the copy they
run from, and stop if either is newer.

`package/contents/ui/version.js` holds a third, different number:
`requiredEngine`, the **oldest engine this widget package works fully with**.
It moves whenever the engine changes in a way users notice, through new API
or a fix. When the engine Plasma has loaded is older, each settings page
shows a notice
(`EngineStatus.qml`) with both versions, what waits for each engine version
newer than the loaded one (the page's `outdatedNotes`, then the
`commonNotes` of `EngineStatus.qml` for what lies outside the settings
pages) and how to update.

## Files the running widget loads

*Get New Widgets* replaces the widget package while Plasma runs. Plasma keeps
what it has already loaded, but a `main.qml` or `TerminalPane.qml` it has not
loaded yet in that session, for a new widget or a panel popup opened for the
first time, is read from the new package. Plasma's QML engine still has the
package folder's old listing cached and cannot find files that are new, so an
import of one fails and the widget shows an error instead of a terminal until
Plasma restarts. Users can skip releases, so "new" means missing from any
earlier release. Hence:

* `main.qml` and `TerminalPane.qml` must not import or load a file of the
  package that an earlier release did not have.
* The same two files must work on an engine older than the package, both
  before that restart and after it, until the user runs `update.sh`. They
  cannot use `version.js` for that, since 1.0 did not have it, so they test
  for new engine API with `typeof`, the way `TerminalPane.qml` tests for
  `fontStyleInfo`.
* The settings pages, `EngineStatus.qml`, `EngineInfo.qml` and `version.js`
  are free of this rule: Plasma builds a new QML engine for every settings
  dialog it opens, and that engine sees the new files. The pages reach the
  engine only through `EngineStatus.qml`, whose `info` is null without an
  engine, so that they still open and say what is missing.

## Settings

Users' settings live in Plasma's config, keyed by the entry names in
`package/contents/config/main.xml`. So:

* never rename or remove an entry, or change what its stored values mean —
  add a new entry instead and leave the old one readable;
* give every new entry a default that reproduces the previous behaviour, so an
  update changes nothing until the user changes a setting;
* in `main.qml` and `TerminalPane.qml`, read a new entry as possibly
  undefined (as `cfg.fontStyle || ""` does): a widget that existed before an
  update from *Get New Widgets* keeps the old list of entries until Plasma
  restarts.

## Checklist

1. Bump the version in `CMakeLists.txt` and `package/metadata.json`.
2. If the engine changed in a way users notice (new API or a fix), raise
   `requiredEngine` in `package/contents/ui/version.js` to the same version.
   Add an entry `{ version: "X.Y.Z", text: … }` saying what waits for it to
   the `outdatedNotes` of each settings page it affects, and to the
   `commonNotes` of `EngineStatus.qml` for what lies outside the settings
   pages. Keep the older entries, since an engine that old can still be
   installed, and write each entry so that it reads correctly on its own: an
   engine between two releases sees only the later entries. If the QML also
   starts to use new engine API, make `main.qml` and `TerminalPane.qml` test
   for it with `typeof` (see above).
3. Add a `CHANGELOG.md` entry under a heading `## X.Y.Z — YYYY-MM-DD`, with a
   provisional date that step 5 sets: which halves changed (engine, widget
   package or both), what changed for users, and anything an update needs
   beyond `git pull` and `./update.sh`. Keep the bare version as the
   heading's second word and leave older headings as they are: `update.sh`
   looks for the older installed half's version there. After it has
   installed the update, it prints the entries above that heading, next to
   its restart prompt. So an entry must not tell the reader to run
   `update.sh`, or to restart Plasma before running it; advice for users who
   update from the store first belongs in the store's changelog (step 6).
4. Test every way of updating, against the working tree:

   ```bash
   test/update-routes.sh --from main
   ```

   `--from` names the previous release; until step 5, `main` still holds it.
   The script first checks the versions from step 1, and that
   `requiredEngine` is the new version if `src/` or `lib/` changed since
   `--from`; a change there that users cannot notice, such as a build fix,
   fails this check and has to be judged by hand.
   It then runs these routes on Fedora, Debian, Ubuntu and Arch, each in a
   fresh rootless podman container, and checks what the scripts print and
   which versions end up installed:
   * the previous release installed with its own `install.sh`, then
     `git pull` and `./update.sh`;
   * the same with a store update of the widget package before `git pull`;
   * the store package without an engine, then `./update.sh`, or
     `./install.sh`;
   * a newer widget package or engine installed already, which both scripts
     must refuse;
   * `./update.sh` twice;
   * `./install.sh` from a copy without `.git`, then `./uninstall.sh`.

   In a hidden nested Plasma session it then updates the widget package while
   Plasma runs and adds a widget, and runs the new package on the old engine,
   the new engine and none, reading the widget and its three settings pages.
   It exits non-zero if any check fails; its header lists the tools it needs.

   The store update is simulated: the archive from step 6 is installed only
   if its `Version` is higher, the way KPackage applies it. The script cannot
   test the real *Get New Widgets* dialog or the live store; step 6 ends with
   a check of the live entry.
5. Set the date in the new `CHANGELOG.md` heading to today and commit it.
   Then merge to `main`, tag the release commit `vX.Y.Z` and push the tag.
   This has to happen before step 6. Users' clones pull from `main`, and a
   user who updates from the store first is told to run `git pull` and
   `./update.sh`, which needs the release on `main`: a 1.0 clone has no
   `update.sh`, and newer scripts refuse to run from a copy older than the
   installed widget. The settings pages' *How to update* link opens the
   README's Updating section on GitHub, which shows `main`.
6. If the widget package changed, publish it on the KDE Store entry
   (https://store.kde.org/p/2371024):
   * Build the archive with
     `(cd package && zip -r ../io.github.cir0cuit.plasmaterminal-X.Y.Z.plasmoid .)`.
   * Replace the entry's file with it; never add a second file. With two
     files, *Update* installs the one with the highest file version and skips
     files without one, so it can install the old file again while recording
     the new version.
   * Set the version `X.Y.Z` on the entry and on the file. *Get New Widgets*
     offers *Update* when the entry's version or the date it last changed
     differs from what it recorded at install time.
   * Fill in the entry's changelog for `X.Y.Z`: a few lines for users, taken
     from `CHANGELOG.md`. *Discover* shows it with the update, and until
     `update.sh` runs it is the only list of changes a user who updates from
     the store can see.
   * If `doc/store-description.md` changed, paste it, without its opening
     comment, into the entry's description.
   * After saving, read the entry from the store's API,
     https://api.kde-look.org/ocs/v1/content/data/2371024, and check that
     `<version>` is `X.Y.Z`, `<changed>` has today's date, `<changelog>`
     holds the new text, and there is one file (`downloadname1`, with
     `download_version1` `X.Y.Z`).
