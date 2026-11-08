# Changelog

Every release lists what changed and whether updating needs anything beyond
`git pull` and `./update.sh` — see [Updating](README.md#updating).

The widget comes in two halves that are installed separately: the **engine**
(the compiled QML module, installed system-wide) and the **widget package**
(the QML plasmoid, installed per user or from *Get New Widgets*). Each entry
says which halves changed. When the engine changed, updating only the widget
package is not enough; the widget's settings pages say so if it happens.

## 1.1.0 — 2026-11-08

Halves changed: **engine and widget package** — rebuild the engine.

Updating: *Get New Widgets* and *Discover* update only the widget package.
`git pull` and `./update.sh` in your copy of the project rebuild the engine
as well; restart Plasma afterwards.

### Added

- **Font style.** *Appearance → Style* picks any weight or italic the font
  family is installed in — Thin, Light, Regular, Medium, SemiBold, Italic and
  so on — not only the family itself. On any style lighter than Bold, bold
  text uses the family's real Bold face.
  ([#7](https://github.com/Cir0cuit/plasma-terminal-widget/issues/7))
- `update.sh`, to run after `git pull` has downloaded a new version: it
  builds and installs that version over the old one, shows what changed and
  offers to restart plasmashell. It checks both halves, so after *Get New
  Widgets* has updated only the widget package, it says so, updates the
  engine and still lists the changes.
- The settings pages say when the engine is older than the widget package,
  naming the settings on each page that wait for it to be rebuilt, or that it
  is not installed. Before, *Appearance* and *Shell* stayed empty without an
  engine.

### Changed

- If your Konsole profile uses a style other than Regular and the widget
  follows that profile, the widget now draws text in that style too.
- `install.sh` and `update.sh` stop without changing anything when the
  installed widget package or engine is newer than the copy they run from.
  Before, `install.sh` put the older widget package back over one from
  *Get New Widgets*.
- `install.sh`, `update.sh` and `uninstall.sh` stop at once when run as
  root, for example with `sudo`, and ask for a password themselves for the
  steps that need root. Run as root, `install.sh` installed the widget
  package in root's home folder instead of yours, and left files in `build/`
  that the next run could not overwrite.
- The widget says "Terminal engine not installed" only when the engine is
  missing, and a terminal opened after *Get New Widgets* has updated the
  widget, before Plasma restarts, starts normally. Any other error that stops
  the terminal from loading is shown as it is, with the advice to restart
  Plasma if the widget was just updated.

### Fixed

- `install.sh` builds again after a first attempt that failed, for example on
  a missing dependency. Before, `build/` had to be deleted by hand.
- `install.sh` no longer fails where `$USER` is not set.
- Where sudo is not installed, `install.sh` and `uninstall.sh` use `su`,
  which asks for root's password. Before, they stopped with advice that did
  not work.
- An engine installed under a umask stricter than 022 can be read by Plasma,
  which before said the engine was not installed. Updating also repairs an
  engine installed that way.
- *Appearance → Family* and *Size* show the font the widget actually uses.
  Before, with *Match my Konsole profile* on, they showed the first family in
  the list and 10 pt, and a monospace family that the list left out showed as
  the first family instead.
- *Behavior → Terminal bell* works in every mode: system beep, notification
  and flash. Before, the setting had no effect. *Notification* uses KDE's
  notifications QML module, which a minimal Debian or Ubuntu install may lack
  (`qml6-module-org-kde-notifications`); without it, that mode sends nothing
  and the rest of the widget works as usual.
- *Antialias glyphs* takes effect at once, can be switched back on, and
  applies only to the widget it was set for.
- *Padding* takes effect at once instead of after the next resize.
- With *Start on load* off, *Start* now runs the startup command, and
  *Restart* and *Start a new session* start the shell.
- A shell that cannot start, because the program or the working directory
  does not exist, shows "Could not start …" instead of a blank terminal.
- A shell killed by a signal, or a program run as the shell and stopped with
  Ctrl+C, now triggers *When the shell exits* instead of leaving a terminal
  that ignores input.
- *Start a new session* offers the restart button for a program that exits
  at once, instead of restarting it over and over.
- *Read-only* also blocks text typed through an input method.
- Ctrl+wheel zooms one step per wheel notch on high-resolution wheels and
  touchpads, not several.
- *Shell → Arguments* accepts quotes inside a word, as in
  `--rcfile="/home/me/my rc"`, and escaped quotes.
- Programs that read `COLORFGBG`, such as vim and mc, are told the background
  is light when the colour scheme is light.
- The bold option is labelled for what it does: *Draw bold text in a bold
  font*.
- The blinking cursor blinks wherever it is on the line, and only in the
  widget that has focus. It used to stop blinking from about the 40th column
  and leave a thin bar behind.
- *Draw bold text in a bold font* and *Cursor covers the full line height*
  change what is already on screen as soon as they are applied, and the
  normal cursor no longer reaches into the line below.
- With little or no padding, the rightmost column is no longer cut off.
- *Clear Scrollback and Reset* empties the scrollback and resets the
  terminal, and a bash, zsh or fish prompt waiting for input is redrawn at the
  top.
- With some fonts, such as Noto Sans Mono and DejaVu Sans Mono at 10 pt, typing
  on the lower rows of a tall terminal no longer blanks the line.
- *Shell → Program* set to a path that does not exist shows "Could not
  start", naming the program and folder that failed, instead of quietly
  starting another shell.
- Turning on *Start on load* while "Terminal is not running" is shown no
  longer leaves a terminal with no shell behind it.
- The "Terminal is not running", "The shell exited" and "Could not start"
  messages are readable on every colour scheme.
- On the desktop, the widget's global shortcut focuses the terminal on every
  press, not every second one, and typing reaches the terminal again after
  Plasma's menu for the widget closes.
- A font family that is no longer installed falls back to a monospace font
  instead of a proportional one, and the settings show the font and colour
  scheme actually in use.
- *Appearance → Family* lists Noto Sans Mono and other monospace fonts that
  fontconfig does not mark as monospace, and no longer lists symbol fonts or
  duplicate per-weight names such as "JetBrains Mono Light".
- When the Konsole profile's font is not installed, *Match my Konsole
  profile* says so.
- The keyboard option names the zoom keys it also controls, the Environment
  box shows several lines, and the Shell page says which changes take effect
  after *Restart Session*.

## 1.0.0

First release.
