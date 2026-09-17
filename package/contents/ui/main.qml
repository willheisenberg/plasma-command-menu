import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasma5support as Plasma5Support

PlasmoidItem {
    id: root

    // Parsed ~/.commands.json (array of entries) and optional top-level settings
    property var menuData: []
    property string menuTitle: ""
    property string menuIcon: ""
    property bool showIcon: true
    property string loadError: ""

    // Incremented whenever the popup opens, collapses all submenus
    property int resetToken: 0
    property string lastFileText: ""

    readonly property string filePathExpr: {
        var p = (Plasmoid.configuration.commandsFile || "").trim() || "~/.commands.json";
        if (p === "~") {
            return '"$HOME"';
        }
        if (p.indexOf("~/") === 0) {
            return '"$HOME"' + shellQuote(p.substring(1));
        }
        return shellQuote(p);
    }
    readonly property string readCmd: "cat -- " + filePathExpr

    // Top-level entries for the popup, including error and edit/reload entries
    readonly property var entries: {
        var out = [];
        if (loadError !== "") {
            out.push({ kind: "error", title: loadError });
        }
        out = out.concat(normalize(menuData));
        var extra = [];
        if (Plasmoid.configuration.showEditButton) {
            extra.push({ kind: "edit", title: i18n("Edit Commands"), icon: "document-edit" });
        }
        if (Plasmoid.configuration.showReloadButton) {
            extra.push({ kind: "reload", title: i18n("Reload"), icon: "view-refresh" });
        }
        if (extra.length > 0 && out.length > 0) {
            out.push({ kind: "separator" });
        }
        return out.concat(extra);
    }

    function shellQuote(s) {
        return "'" + String(s).replace(/'/g, "'\\''") + "'";
    }

    // Turn .commands.json entries into { kind, title, icon, command, children }, dropping invalid ones
    function normalize(items) {
        var out = [];
        if (!Array.isArray(items)) {
            return out;
        }
        for (var i = 0; i < items.length; i++) {
            var cmd = items[i];
            if (!cmd || typeof cmd !== "object") {
                continue;
            }
            if (cmd.type === "separator") {
                out.push({ kind: "separator" });
            } else if (!cmd.title) {
                continue;
            } else if (cmd.type === "submenu") {
                if (Array.isArray(cmd.submenu)) {
                    out.push({ kind: "submenu", title: cmd.title, icon: cmd.icon || "", children: normalize(cmd.submenu) });
                }
            } else if (cmd.command) {
                out.push({ kind: "command", title: cmd.title, icon: cmd.icon || "", command: cmd.command });
            }
        }
        return out;
    }

    function reload() {
        executable.connectSource(readCmd);
    }

    function applyFile(text) {
        // Keep the existing delegates (and open submenus) if nothing changed
        if (text === lastFileText && loadError === "") {
            return;
        }
        lastFileText = text;
        var parsed;
        try {
            parsed = JSON.parse(text);
        } catch (e) {
            menuData = [];
            loadError = i18n("Invalid JSON: %1", e.message);
            return;
        }
        var cfg = {};
        if (Array.isArray(parsed)) {
            cfg.menu = parsed;
        } else if (parsed && typeof parsed === "object" && Array.isArray(parsed.menu)) {
            cfg = parsed;
        } else {
            menuData = [];
            loadError = i18n("Expected an array or an object with a \"menu\" array");
            return;
        }
        menuTitle = typeof cfg.title === "string" ? cfg.title : "";
        menuIcon = typeof cfg.icon === "string" ? cfg.icon : "";
        showIcon = cfg.showIcon !== false;
        loadError = "";
        menuData = cfg.menu;
    }

    function runDetached(shellCmd) {
        executable.connectSource("setsid -f sh -c " + shellQuote(shellCmd) + " >/dev/null 2>&1");
    }

    function editCommandsFile() {
        var example = JSON.stringify([
            { title: "Terminal", command: "konsole", icon: "utilities-terminal" },
            { title: "File Manager", command: "dolphin", icon: "system-file-manager" },
            { type: "separator" },
            { title: "SSH Connections", type: "submenu", submenu: [
                { title: "Connect to Server (SSH)", command: "konsole -e ssh user@example.com", icon: "utilities-terminal" }
            ] }
        ], null, 2);
        runDetached("f=" + filePathExpr + "; [ -e \"$f\" ] || printf '%s\\n' " + shellQuote(example) + " > \"$f\"; xdg-open \"$f\"");
    }

    function activate(entry) {
        switch (entry.kind) {
        case "command":
            runDetached(entry.command);
            break;
        case "edit":
            editCommandsFile();
            break;
        case "reload":
            lastFileText = "";
            reload();
            return;
        default:
            return;
        }
        root.expanded = false;
    }

    onExpandedChanged: function() {
        if (root.expanded) {
            resetToken++;
            reload();
        }
    }
    onReadCmdChanged: reload()
    Component.onCompleted: reload()

    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: i18n("Edit Commands")
            icon.name: "document-edit"
            onTriggered: root.editCommandsFile()
        },
        PlasmaCore.Action {
            text: i18n("Reload")
            icon.name: "view-refresh"
            onTriggered: root.reload()
        }
    ]

    toolTipMainText: menuTitle || i18n("Command Menu")
    toolTipSubText: loadError || Plasmoid.configuration.commandsFile

    Plasma5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []

        onNewData: function(sourceName, data) {
            if (sourceName === root.readCmd) {
                if (data["exit code"] === 0) {
                    root.applyFile(data["stdout"] || "");
                } else {
                    root.lastFileText = "";
                    root.menuData = [];
                    root.loadError = i18n("Cannot read %1", Plasmoid.configuration.commandsFile);
                }
            }
            disconnectSource(sourceName);
        }
    }

    compactRepresentation: MouseArea {
        id: compactRoot

        readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
        readonly property bool iconVisible: root.showIcon || root.menuTitle === "" || vertical
        property bool wasExpanded: false

        Layout.minimumWidth: vertical ? Kirigami.Units.iconSizes.small : row.implicitWidth
        Layout.preferredWidth: Layout.minimumWidth
        Layout.fillHeight: !vertical
        Layout.minimumHeight: vertical ? Kirigami.Units.iconSizes.smallMedium : 0

        acceptedButtons: Qt.LeftButton
        hoverEnabled: true
        onPressed: wasExpanded = root.expanded
        onClicked: root.expanded = !wasExpanded

        RowLayout {
            id: row
            anchors.centerIn: parent
            height: parent.height
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Icon {
                visible: compactRoot.iconVisible
                Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                Layout.alignment: Qt.AlignVCenter
                source: root.menuIcon !== "" ? root.menuIcon : "bash"
                fallback: "utilities-terminal"
                active: compactRoot.containsMouse
            }

            PlasmaComponents.Label {
                visible: !compactRoot.vertical && root.menuTitle !== ""
                text: root.menuTitle
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }

    fullRepresentation: Item {
        id: popup

        // Grow with the content; only scroll if the menu would not fit on screen
        readonly property real maxHeight: Screen.desktopAvailableHeight * 0.8
        readonly property real wantedHeight: Math.max(Kirigami.Units.gridUnit * 2, Math.min(menu.implicitHeight, maxHeight))

        Layout.preferredWidth: Kirigami.Units.gridUnit * 20
        Layout.minimumWidth: Kirigami.Units.gridUnit * 14
        Layout.minimumHeight: wantedHeight
        Layout.preferredHeight: wantedHeight
        Layout.maximumHeight: wantedHeight

        focus: true
        Keys.onDownPressed: {
            var first = menu.nextItemInFocusChain(true);
            if (first) {
                first.forceActiveFocus(Qt.TabFocusReason);
            }
        }

        PlasmaComponents.ScrollView {
            id: scrollView
            anchors.fill: parent

            MenuLevel {
                id: menu
                width: scrollView.availableWidth
                entries: root.entries
                resetToken: root.resetToken
                onTriggered: function(entry) {
                    root.activate(entry);
                }
            }
        }
    }
}
