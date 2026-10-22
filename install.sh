#!/usr/bin/env bash
# Installer for Tapo Power: the tapo-power helper in ~/bin, its icon, and the
# Plasma 6 applet. Everything is per-user; nothing needs sudo.
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APPLET_ID="io.github.jboero.tapopower"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}"

say() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }

say "Installing helper to ~/bin/tapo-power"
install -Dm755 "$SRC/tapo-power" "$HOME/bin/tapo-power"

# Removed: the custom tapo-power icon, superseded by Breeze's utilities-energy-monitor.
rm -f "$DATA/icons/hicolor/scalable/apps/tapo-power.svg"

say "Installing the Plasma applet"
DEST="$DATA/plasma/plasmoids/$APPLET_ID"
if [[ -d "$DEST" ]]; then
    # kpackagetool6 --upgrade can hang on DBus; a file sync is equivalent.
    rm -rf "$DEST" && cp -r "$SRC/plasmoid/$APPLET_ID" "$DEST"
else
    kpackagetool6 --type Plasma/Applet --install "$SRC/plasmoid/$APPLET_ID"
fi

if [[ ! -r "$HOME/.config/tapo-power/credentials" ]]; then
    say "No credentials yet. Run:  tapo-power --setup"
fi
say "Done. Add 'Tapo Power' to a panel, or enable it under System Tray Settings > Entries."
