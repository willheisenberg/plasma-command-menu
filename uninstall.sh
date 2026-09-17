#!/usr/bin/env bash
set -e

PLASMOID_ID="com.github.tesla.plasmacommandmenu"

if kpackagetool6 -t Plasma/Applet --list 2>/dev/null | grep -q "$PLASMOID_ID"; then
    kpackagetool6 -t Plasma/Applet --remove "$PLASMOID_ID"
    echo "✅ Widget removed (~/.commands.json was left untouched)"
else
    echo "ℹ️  Widget was not installed"
fi
