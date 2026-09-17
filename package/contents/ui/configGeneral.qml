import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.FormLayout {
    id: page

    property alias cfg_commandsFile: commandsFileField.text
    property alias cfg_showEditButton: showEditButtonField.checked
    property alias cfg_showReloadButton: showReloadButtonField.checked

    TextField {
        id: commandsFileField
        Kirigami.FormData.label: i18n("Commands file:")
        placeholderText: "~/.commands.json"
        Layout.fillWidth: true
    }

    Label {
        text: i18n("Same format as the GNOME 'Command Menu' extension.\nThe file is re-read every time the menu is opened.")
        font.italic: true
        font.pointSize: 9
        color: Kirigami.Theme.disabledTextColor
        Layout.fillWidth: true
    }

    CheckBox {
        id: showEditButtonField
        Kirigami.FormData.label: i18n("Menu buttons:")
        text: i18n("Show 'Edit Commands'")
    }

    CheckBox {
        id: showReloadButtonField
        text: i18n("Show 'Reload'")
    }
}
