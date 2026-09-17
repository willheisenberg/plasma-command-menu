import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

// One level of the menu. Submenus load another MenuLevel lazily and slide open.
ColumnLayout {
    id: level

    // Normalized entries: { kind: command|submenu|separator|edit|reload|error, title, icon, command, children }
    property var entries: []
    property int depth: 0
    // Incremented by the parent to collapse all submenus
    property int resetToken: 0

    signal triggered(var entry)
    signal collapseRequested()

    spacing: 0

    Repeater {
        model: level.entries

        delegate: ColumnLayout {
            id: entryItem

            required property var modelData
            readonly property string kind: modelData.kind
            readonly property int indent: level.depth * Kirigami.Units.gridUnit
            property bool open: false

            Layout.fillWidth: true
            spacing: 0

            Connections {
                target: level
                function onResetTokenChanged() {
                    entryItem.open = false;
                }
            }

            Kirigami.Separator {
                visible: entryItem.kind === "separator"
                Layout.fillWidth: true
                Layout.leftMargin: Kirigami.Units.largeSpacing + entryItem.indent
                Layout.rightMargin: Kirigami.Units.largeSpacing
                Layout.topMargin: Kirigami.Units.smallSpacing
                Layout.bottomMargin: Kirigami.Units.smallSpacing
            }

            PlasmaComponents.ItemDelegate {
                id: button

                visible: entryItem.kind !== "separator"
                enabled: entryItem.kind !== "error"
                Layout.fillWidth: true
                hoverEnabled: true
                highlighted: activeFocus
                leftPadding: Kirigami.Units.largeSpacing + entryItem.indent

                function activate() {
                    if (entryItem.kind === "submenu") {
                        entryItem.open = !entryItem.open;
                    } else {
                        level.triggered(entryItem.modelData);
                    }
                }

                function focusNeighbour(forward) {
                    var next = nextItemInFocusChain(forward);
                    if (next) {
                        next.forceActiveFocus(forward ? Qt.TabFocusReason : Qt.BacktabFocusReason);
                    }
                }

                onHoveredChanged: {
                    if (hovered) {
                        forceActiveFocus(Qt.MouseFocusReason);
                    }
                }
                onClicked: activate()

                Keys.onReturnPressed: activate()
                Keys.onEnterPressed: activate()
                Keys.onDownPressed: focusNeighbour(true)
                Keys.onUpPressed: focusNeighbour(false)
                Keys.onRightPressed: {
                    if (entryItem.kind === "submenu") {
                        entryItem.open = true;
                    }
                }
                Keys.onLeftPressed: {
                    if (entryItem.kind === "submenu" && entryItem.open) {
                        entryItem.open = false;
                    } else {
                        level.collapseRequested();
                    }
                }

                contentItem: RowLayout {
                    spacing: Kirigami.Units.smallSpacing * 2

                    Kirigami.Icon {
                        Layout.preferredWidth: Kirigami.Units.iconSizes.small
                        Layout.preferredHeight: Kirigami.Units.iconSizes.small
                        source: entryItem.kind === "error" ? "dialog-error" : (entryItem.modelData.icon || "")
                        visible: source !== ""
                    }

                    PlasmaComponents.Label {
                        Layout.fillWidth: true
                        text: entryItem.modelData.title || ""
                        elide: entryItem.kind === "error" ? Text.ElideNone : Text.ElideRight
                        wrapMode: entryItem.kind === "error" ? Text.Wrap : Text.NoWrap
                    }

                    Kirigami.Icon {
                        visible: entryItem.kind === "submenu"
                        Layout.preferredWidth: Kirigami.Units.iconSizes.small
                        Layout.preferredHeight: Kirigami.Units.iconSizes.small
                        source: "go-next-symbolic"
                        rotation: entryItem.open ? 90 : 0

                        Behavior on rotation {
                            NumberAnimation {
                                duration: Kirigami.Units.longDuration
                                easing.type: Easing.InOutQuad
                            }
                        }
                    }
                }
            }

            Item {
                id: childContainer

                visible: entryItem.kind === "submenu" && Layout.preferredHeight > 0
                clip: true
                Layout.fillWidth: true
                Layout.preferredHeight: entryItem.open && childLoader.item ? childLoader.item.implicitHeight : 0

                Behavior on Layout.preferredHeight {
                    NumberAnimation {
                        duration: Kirigami.Units.longDuration
                        easing.type: Easing.InOutQuad
                    }
                }

                Loader {
                    id: childLoader
                    width: parent.width
                    active: entryItem.kind === "submenu" && (entryItem.open || childContainer.visible)
                    source: "MenuLevel.qml"

                    onLoaded: {
                        item.depth = level.depth + 1;
                        item.entries = Qt.binding(function() { return entryItem.modelData.children; });
                        item.resetToken = Qt.binding(function() { return level.resetToken; });
                        item.triggered.connect(level.triggered);
                        item.collapseRequested.connect(function() {
                            entryItem.open = false;
                            button.forceActiveFocus();
                        });
                    }
                }
            }
        }
    }
}
