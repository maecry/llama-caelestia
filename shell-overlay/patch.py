#!/usr/bin/env python3
"""Apply the chat-panel patches to the symlinked caelestia shell mirror.

Reads the packaged shell (/etc/xdg/quickshell/caelestia), applies textual patches,
and writes the results into the user mirror. Every anchor must match exactly once,
so a shell update that breaks a patch fails loudly instead of silently misapplying.

Overlay files (our own QML) are copied over the mirror afterwards.
"""
import pathlib
import shutil
import sys

SRC = pathlib.Path("/etc/xdg/quickshell/caelestia")
DST = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else
                   pathlib.Path.home() / ".config/quickshell/caelestia")
OVL = pathlib.Path(__file__).resolve().parent


def patch(rel, subs):
    src = SRC / rel
    text = src.read_text()
    for old, new in subs:
        n = text.count(old)
        assert n == 1, f"{rel}: anchor found {n} times: {old!r}"
        text = text.replace(old, new)
    out = DST / rel
    out.parent.mkdir(parents=True, exist_ok=True)
    if out.is_symlink() or out.exists():
        out.unlink()
    out.write_text(text)
    print(f"patched {rel}")


# 1. chat popout registration
patch("modules/bar/popouts/Content.qml", [
    ("import qs.services\n", "import qs.services\nimport qs.modules.chat as Chat\n"),
    ("""        Popout {
            name: "lockstatus\"""",
     """        Popout {
            name: "chat"
            sourceComponent: Chat.Panel {
                popouts: root.popouts
            }
        }

        Popout {
            name: "lockstatus\""""),
])

# 2. robot above the power button opens the chat
patch("modules/bar/Bar.qml", [
    ("""                    Power {
                        objectName: "taskbarPowerButton"
                        screenState: root.screenState
                    }""",
     """                    Power {
                        objectName: "taskbarPowerButton"
                        screenState: root.screenState
                        popouts: root.popouts
                    }"""),
    ("""        const id = ch.entryId;
        const top = ch.y;
""",
     """        const id = ch.entryId;
        const top = ch.y;

        if (id === "power") {
            const power = ch.item as Power;
            const robotCenter = power.robot.mapToItem(root, 0, power.robot.implicitHeight / 2).y;
            if (Math.abs(y - robotCenter) <= power.robot.implicitHeight / 2 + Tokens.padding.small / 2) {
                popouts.currentName = "chat";
                popouts.currentCenter = robotCenter;
                popouts.hasCurrent = true;
                return;
            }
        }
"""),
])

# 3. keyboard focus so the composer can be typed into
patch("modules/drawers/ContentWindow.qml", [
    ("WlrLayershell.keyboardFocus: screenState.launcher || screenState.session ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None",
     "WlrLayershell.keyboardFocus: screenState.launcher || screenState.session || (panels.popouts.hasCurrent && panels.popouts.currentName === \"chat\") ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None"),
])

# 4. our own QML files
for f in sorted(pathlib.Path(OVL / "modules").rglob("*.qml")):
    rel = f.relative_to(OVL)
    out = DST / rel
    out.parent.mkdir(parents=True, exist_ok=True)
    if out.is_symlink() or out.exists():
        out.unlink()
    shutil.copy2(f, out)
    print(f"copied {rel}")
