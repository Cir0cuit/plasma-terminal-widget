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

- **Font style.** *Appearance → Style* picks any weight or italic the font
  family is installed in — Thin, Light, Regular, Medium, SemiBold, Italic and
  so on — not only the family itself. On any style lighter than Bold, bold
  text uses the family's real Bold face.
  ([#7](https://github.com/Cir0cuit/plasma-terminal-widget/issues/7))
- `update.sh`, which updates an installation made from a git checkout in one
  step.
- The engine reports its version, so a widget package newer than the
  installed engine says so in its settings instead of failing quietly.

### Changed

- If your Konsole profile uses a style other than Regular and the widget
  follows that profile, the widget now draws text in that style too.

### Fixed

- `install.sh` builds again after a first attempt that failed, for example on
  a missing dependency. Before, `build/` had to be deleted by hand.
- `install.sh` no longer fails where `$USER` is not set.
- *Appearance → Family* and *Size* show the font the widget actually uses.
  Before, with *Match my Konsole profile* on, they showed the first family in
  the list and 10 pt, and a monospace family that the list left out showed as
  the first family instead.
- *Behavior → Terminal bell* works in every mode: system beep, notification
  and flash. Before, the setting had no effect.
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

### Updating from 1.0

Your widgets keep all their settings. A 1.0 clone does not have `update.sh`
yet, so pull once by hand. In the `plasma-terminal-widget` folder that
`git clone` created, run:

```bash
git pull
./update.sh
```

If *Get New Widgets* has already updated the widget to 1.1, run the same
commands in the folder you built the engine from. Until you do, the widget
keeps working on the 1.0 engine, but without the font style setting and the
fixes made in the engine, and its *Appearance* settings page says the engine
needs rebuilding.

## 1.0.0

First release.
