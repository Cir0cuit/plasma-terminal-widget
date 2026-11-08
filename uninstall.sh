#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Remove both halves. Widget instances have to be removed from the desktop
# first, or plasmashell will show an empty placeholder until it is restarted.
set -uo pipefail

cd "$(dirname "$0")" || exit 1
# shellcheck source=scripts/common.sh
. scripts/common.sh || exit 1

refuse_root

echo "Removing the applet..."
if ! command -v kpackagetool6 >/dev/null 2>&1; then
    echo "  kpackagetool6 not found - skipping (nothing to remove without it)."
elif package_listed; then
    kpackagetool6 --type Plasma/Applet --remove "$APPLET_ID" || true
else
    # kpackagetool6 --remove would report an error for this.
    echo "  not installed."
fi

echo "Removing the QML module..."
if [ -f build/install_manifest.txt ]; then
    as_root xargs -a build/install_manifest.txt rm -f
fi

# The manifest lists files, not directories, so core/ survives the step above -
# and on a machine that installed from the store there is no manifest at all.
# core/ has to be the first directory removed: rmdir leaves a non-empty
# directory alone, so a surviving core/ keeps every parent below non-empty too,
# and the whole chain silently does nothing.
seen=""
found=0
while read -r qmldir; do
    [ -n "$qmldir" ] || continue
    # Resolve first: on Arch /usr/lib64 is a symlink to /usr/lib, so two
    # candidates can name the same directory.
    qmldir=$(readlink -f "$qmldir" 2>/dev/null) || continue
    [ -d "$qmldir/$MODULE_PATH" ] || continue
    case ":$seen:" in *":$qmldir:"*) continue ;; esac
    seen="$seen:$qmldir"
    found=1
    echo "  $qmldir/$MODULE_PATH"
    as_root rm -rf "$qmldir/$MODULE_PATH"
    # No 2>/dev/null: su would ask for its password there, unseen. The
    # parents exist, since core/ did, and non-empty ones are left quietly.
    as_root rmdir --ignore-fail-on-non-empty \
        "$qmldir/io/github/cir0cuit/plasmaterminal" \
        "$qmldir/io/github/cir0cuit" \
        "$qmldir/io/github" \
        "$qmldir/io" || true
done < <(qml_dir_candidates)

if [ "$found" -eq 0 ]; then
    echo "  no installed module found - nothing to remove."
fi

echo "Done. Restart plasmashell: systemctl --user restart plasma-plasmashell.service"
