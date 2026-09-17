# Command Menu for KDE Plasma 6

Panel widget to manage command shortcuts – a port of the GNOME extension
[gnome-command-menu](https://github.com/arunk140/gnome-command-menu).
It reads the **same `~/.commands.json`**, so an existing GNOME config works unchanged.

## Install

```bash
./install.sh
```

Then right click the panel → *Add Widgets…* → **Command Menu**.

## ~/.commands.json

Either a plain array of entries, or an object with top-level settings:

```json
{
    "title": "Commands",
    "showIcon": true,
    "icon": "utilities-terminal",
    "menu": [
        { "title": "Terminal", "command": "konsole", "icon": "utilities-terminal" },
        { "type": "separator" },
        {
            "title": "SSH Connections",
            "type": "submenu",
            "submenu": [
                { "title": "Connect to Server", "command": "konsole -e ssh root@10.144.1.2 -p 8022" }
            ]
        }
    ]
}
```

| Field      | Meaning                                                              |
|------------|----------------------------------------------------------------------|
| `title`    | Text in the menu (top level: text next to the panel icon)            |
| `command`  | Shell command, started detached via `sh -c`                          |
| `icon`     | Freedesktop / Breeze icon name                                       |
| `type`     | `"separator"` or `"submenu"` (submenus may be nested)                |
| `showIcon` | Top level only: `false` hides the panel icon when a title is set     |

The file is re-read every time the menu opens, so no reload is needed after editing.
Submenus slide open inside the menu and the popup grows to fit, so it only scrolls when it would exceed the screen.
Keyboard: ↑/↓ to select, Enter to run, →/← to open/close submenus.

## Settings

- Path of the commands file (default `~/.commands.json`)
- Show *Edit Commands* / *Reload* entries in the menu (both are also in the right-click menu)

## Uninstall

```bash
./uninstall.sh
```
