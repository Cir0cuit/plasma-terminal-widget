#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Test helper: drive the pointer to a logical screen position under KWin.
#
# ydotool only emits relative motion. libinput accelerates big jumps wildly,
# but small steps land at a steady 2 logical pixels per unit on this 2x scaled
# screen, so the move is chopped into small steps and verified against
# workspace.cursorPos.

set -u

SCRATCH="${SCRATCH:-$(mktemp -d -t plasma-terminal-XXXXXX)}"
export YDOTOOL_SOCKET="${YDOTOOL_SOCKET:-/tmp/.ydotool_socket}"
STEP_UNITS=${STEP_UNITS:-20}      # units per step; small enough to stay linear
UNITS_PER_LOGICAL=${UNITS_PER_LOGICAL:-2}
PROBE_SEQ=0

kwin_eval() {
    local name="$1" js="$2" id
    printf '%s\n' "$js" > "$SCRATCH/$name.js"
    id=$(qdbus-qt6 org.kde.KWin /Scripting org.kde.kwin.Scripting.loadScript "$SCRATCH/$name.js" "$name" 2>/dev/null)
    qdbus-qt6 "org.kde.KWin" "/Scripting/Script$id" org.kde.kwin.Script.run >/dev/null 2>&1
}

cursor_pos() {
    # KWin refuses to re-run a script that was already loaded under the same
    # name, so every probe needs a fresh name and a fresh marker.
    local uniq="$(date +%s%N)"
    local tag="PTPOS$uniq" line
    kwin_eval "ptpos$uniq" "console.info('$tag ' + workspace.cursorPos.x + ' ' + workspace.cursorPos.y);"
    line=$(journalctl --user -u plasma-kwin_wayland.service --since "-20s" --no-pager 2>/dev/null | grep -F "$tag " | tail -1)
    if [ -n "$line" ]; then
        echo "$line" | sed -E "s/.*$tag ([0-9-]+) ([0-9-]+).*/\1 \2/"
    else
        echo "-1 -1"
    fi
}

# Emit a whole movement as one privileged batch of small steps.
ymove_steps() { # <units-x> <units-y>
    sudo -n bash -c '
        export YDOTOOL_SOCKET=$4
        ux=$1; uy=$2; step=$3
        n=1
        ax=${ux#-}; ay=${uy#-}
        big=$ax; [ "$ay" -gt "$big" ] && big=$ay
        [ "$big" -gt 0 ] && n=$(( (big + step - 1) / step ))
        for i in $(seq "$n"); do
            ydotool mousemove -x $(( ux / n )) -y $(( uy / n )) >/dev/null 2>&1
        done
        ydotool mousemove -x $(( ux - (ux / n) * n )) -y $(( uy - (uy / n) * n )) >/dev/null 2>&1
    ' _ "$1" "$2" "$STEP_UNITS" "$YDOTOOL_SOCKET"
}

pointer_to() { # <logical-x> <logical-y>
    local tx="$1" ty="$2" i pos cx cy dx dy
    sudo -n YDOTOOL_SOCKET="$YDOTOOL_SOCKET" ydotool mousemove -x -9000 -y -9000 >/dev/null 2>&1
    for i in 1 2 3 4 5; do
        pos=$(cursor_pos); cx=${pos% *}; cy=${pos#* }
        dx=$((tx - cx)); dy=$((ty - cy))
        if [ "${dx#-}" -le 3 ] && [ "${dy#-}" -le 3 ]; then
            echo "pointer at $cx,$cy (target $tx,$ty)"
            return 0
        fi
        ymove_steps $((dx / UNITS_PER_LOGICAL)) $((dy / UNITS_PER_LOGICAL))
    done
    pos=$(cursor_pos)
    echo "pointer at ${pos// /,} (target $tx,$ty) - not converged"
    return 1
}

yclick() { sudo -n YDOTOOL_SOCKET="$YDOTOOL_SOCKET" ydotool click "$1" >/dev/null 2>&1; }
ytype()  { sudo -n YDOTOOL_SOCKET="$YDOTOOL_SOCKET" ydotool type "$1" >/dev/null 2>&1; }
ykey()   { sudo -n YDOTOOL_SOCKET="$YDOTOOL_SOCKET" ydotool key "$@" >/dev/null 2>&1; }

case "${1:-}" in
    goto)  pointer_to "$2" "$3" ;;
    where) cursor_pos ;;
esac
