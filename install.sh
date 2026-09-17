#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLASMOID_ID="com.github.tesla.plasmacommandmenu"

if kpackagetool6 -t Plasma/Applet --list | grep -q "$PLASMOID_ID"; then
    echo "🔄 Upgrading Command Menu widget..."
    kpackagetool6 -t Plasma/Applet --upgrade "$DIR/package"
else
    echo "📥 Installing Command Menu widget..."
    kpackagetool6 -t Plasma/Applet --install "$DIR/package"
fi

if [ ! -e "$HOME/.commands.json" ]; then
    echo "📝 Creating example ~/.commands.json"
    cp "$DIR/examples/commands-full.json" "$HOME/.commands.json"
fi

echo
echo "✅ Done. Right click the panel → 'Add Widgets…' → search for 'Command Menu'."
echo "   If it does not show up yet: systemctl --user restart plasma-plasmashell.service"
