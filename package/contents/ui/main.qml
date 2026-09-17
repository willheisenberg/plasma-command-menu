import QtQuick
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

    // Keys of currently opened submenus ({ key: true })
    property var openSubmenus: ({})

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

    // Flattened, visible rows for the popup list
    readonly property var rows: {
        var out = [];
        if (loadError !== "") {
            out.push({ kind: "error", title: loadError, depth: 0 });
        }
        buildRows(menuData, 0, "", out);
        var extra = [];
        if (Plasmoid.configuration.showEditButton) {
            extra.push({ kind: "edit", title: i18n("Edit Commands"), icon: "document-edit", depth: 0 });
        }
        if (Plasmoid.configuration.showReloadButton) {
            extra.push({ kind: "reload", title: i18n("Reload"), icon: "view-refresh", depth: 0 });
        }
        if (extra.length > 0 && out.length > 0) {
            out.push({ kind: "separator", depth: 0 });
        }
        return out.concat(extra);
    }

    function shellQuote(s) {
        return "'" + String(s).replace(/'/g, "'\\''") + "'";
    }

    function buildRows(items, depth, prefix, out) {
        if (!Array.isArray(items)) {
            return;
        }
        for (var i = 0; i < items.length; i++) {
            var cmd = items[i];
            if (!cmd || typeof cmd !== "object") {
                continue;
            }
            if (cmd.type === "separator") {
                out.push({ kind: "separator", depth: depth });
                continue;
            }
            if (!cmd.title) {
                continue;
            }
            var key = prefix + "/" + i + ":" + cmd.title;
            if (cmd.type === "submenu") {
                if (!Array.isArray(cmd.submenu)) {
                    continue;
                }
                var isOpen = openSubmenus[key] === true;
                out.push({ kind: "submenu", title: cmd.title, icon: cmd.icon || "", depth: depth, key: key, open: isOpen });
                if (isOpen) {
                    buildRows(cmd.submenu, depth + 1, key, out);
                }
                continue;
            }
            if (!cmd.command) {
                continue;
            }
            out.push({ kind: "command", title: cmd.title, icon: cmd.icon || "", depth: depth, command: cmd.command });
        }
    }

    function reload() {
        executable.connectSource(readCmd);
    }

    function applyFile(text) {
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

    function toggleSubmenu(key) {
        var copy = Object.assign({}, openSubmenus);
        if (copy[key]) {
            // Close this submenu and everything nested below it
            for (var k in copy) {
                if (k === key || k.indexOf(key + "/") === 0) {
                    delete copy[k];
                }
            }
        } else {
            copy[key] = true;
        }
        openSubmenus = copy;
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

    function activate(row) {
        if (!row) {
            return;
        }
        switch (row.kind) {
        case "submenu":
            toggleSubmenu(row.key);
            return;
        case "command":
            runDetached(row.command);
            break;
        case "edit":
            editCommandsFile();
            break;
        case "reload":
            reload();
            return;
        default:
            return;
        }
        root.expanded = false;
    }

    onExpandedChanged: function() {
        if (root.expanded) {
            openSubmenus = {};
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
        Layout.preferredWidth: Kirigami.Units.gridUnit * 20
        Layout.minimumWidth: Kirigami.Units.gridUnit * 14
        Layout.preferredHeight: Math.min(listView.contentHeight, Kirigami.Units.gridUnit * 32)
        Layout.minimumHeight: Kirigami.Units.gridUnit * 2
        Layout.maximumHeight: Kirigami.Units.gridUnit * 32

        PlasmaComponents.ScrollView {
            anchors.fill: parent

            ListView {
                id: listView
                model: root.rows
                clip: true
                focus: true
                currentIndex: -1
                keyNavigationEnabled: true
                highlightMoveDuration: 0

                Connections {
                    target: root
                    function onExpandedChanged() {
                        if (root.expanded) {
                            listView.currentIndex = -1;
                            listView.forceActiveFocus();
                        }
                    }
                }

                // Rebuilding the rows resets the model, so restore the selection afterwards
                function activateAt(idx) {
                    root.activate(root.rows[idx]);
                    Qt.callLater(function() { listView.currentIndex = idx; });
                }

                Keys.onPressed: function(event) {
                    var row = root.rows[currentIndex];
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                        activateAt(currentIndex);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Right && row && row.kind === "submenu" && !row.open) {
                        activateAt(currentIndex);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Left && row && row.kind === "submenu" && row.open) {
                        activateAt(currentIndex);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Down && currentIndex === -1) {
                        currentIndex = 0;
                        event.accepted = true;
                    }
                }

                delegate: Item {
                    id: rowItem
                    required property var modelData
                    required property int index

                    readonly property bool isSeparator: modelData.kind === "separator"
                    readonly property int indent: modelData.depth * Kirigami.Units.gridUnit

                    width: ListView.view.width
                    height: isSeparator ? Kirigami.Units.smallSpacing * 3 : rowDelegate.implicitHeight

                    Kirigami.Separator {
                        visible: rowItem.isSeparator
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: Kirigami.Units.largeSpacing + rowItem.indent
                        anchors.rightMargin: Kirigami.Units.largeSpacing
                    }

                    PlasmaComponents.ItemDelegate {
                        id: rowDelegate
                        visible: !rowItem.isSeparator
                        width: parent.width
                        enabled: rowItem.modelData.kind !== "error"
                        hoverEnabled: true
                        highlighted: rowItem.ListView.isCurrentItem
                        leftPadding: Kirigami.Units.largeSpacing + rowItem.indent

                        onHoveredChanged: {
                            if (hovered) {
                                listView.currentIndex = rowItem.index;
                            }
                        }
                        onClicked: listView.activateAt(rowItem.index)

                        contentItem: RowLayout {
                            spacing: Kirigami.Units.smallSpacing * 2

                            Kirigami.Icon {
                                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                                Layout.preferredHeight: Kirigami.Units.iconSizes.small
                                source: rowItem.modelData.kind === "error" ? "dialog-error" : (rowItem.modelData.icon || "")
                                visible: source !== ""
                            }

                            PlasmaComponents.Label {
                                Layout.fillWidth: true
                                text: rowItem.modelData.title || ""
                                elide: rowItem.modelData.kind === "error" ? Text.ElideNone : Text.ElideRight
                                wrapMode: rowItem.modelData.kind === "error" ? Text.Wrap : Text.NoWrap
                                font.bold: rowItem.modelData.kind === "submenu" && rowItem.modelData.open
                            }

                            Kirigami.Icon {
                                visible: rowItem.modelData.kind === "submenu"
                                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                                Layout.preferredHeight: Kirigami.Units.iconSizes.small
                                source: rowItem.modelData.open ? "go-down-symbolic" : "go-next-symbolic"
                            }
                        }
                    }
                }
            }
        }
    }
}
