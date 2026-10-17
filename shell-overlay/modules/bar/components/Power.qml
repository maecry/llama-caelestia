import QtQuick
import Caelestia.Config
import qs.components
import qs.services
import qs.modules.chat as Chat

// Power button, with the llama chat robot stacked on top of it.
Item {
    id: root

    required property ScreenState screenState
    required property var popouts

    readonly property alias robot: robotBtn

    readonly property bool chatOpen: root.popouts.hasCurrent && root.popouts.currentName === "chat"

    implicitWidth: Math.max(robotBtn.implicitWidth, powerBtn.implicitWidth)
    implicitHeight: robotBtn.implicitHeight + Tokens.spacing.small + powerBtn.implicitHeight

    // Start the chat backend with the bar so the first hover is instant.
    Component.onCompleted: Chat.ChatState.refreshServer()

    // Click pins the panel (it survives the pointer leaving); hover only opens it.
    function toggleChat(): void {
        if (chatOpen) {
            Chat.ChatState.pinned = !Chat.ChatState.pinned;
        } else {
            Chat.ChatState.pinned = true;
            root.popouts.currentName = "chat";
            root.popouts.currentCenter = robotBtn.mapToItem(null, 0, robotBtn.implicitHeight / 2).y;
            root.popouts.hasCurrent = true;
        }
    }

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Tokens.spacing.small

        Item {
            id: robotBtn

            implicitWidth: robotIcon.implicitHeight + Tokens.padding.small
            implicitHeight: robotIcon.implicitHeight

            StateLayer {
                anchors.fill: undefined
                anchors.centerIn: parent
                implicitWidth: implicitHeight
                implicitHeight: robotIcon.implicitHeight + Tokens.padding.small
                radius: Tokens.rounding.full
                onClicked: root.toggleChat()
            }

            MaterialIcon {
                id: robotIcon

                anchors.centerIn: parent
                text: "smart_toy"
                color: root.chatOpen ? Colours.palette.m3primary : Colours.palette.m3secondary
                fontStyle: Tokens.font.icon.builders.small.weight(Font.Bold).build()
                fill: root.chatOpen && Chat.ChatState.pinned ? 1 : 0
            }
        }

        Item {
            id: powerBtn

            implicitWidth: powerIcon.implicitHeight + Tokens.padding.small
            implicitHeight: powerIcon.implicitHeight

            StateLayer {
                // Cursed workaround to make the height larger than the parent
                anchors.fill: undefined
                anchors.centerIn: parent
                implicitWidth: implicitHeight
                implicitHeight: powerIcon.implicitHeight + Tokens.padding.small
                radius: Tokens.rounding.full
                onClicked: root.screenState.session = !root.screenState.session
            }

            MaterialIcon {
                id: powerIcon

                anchors.centerIn: parent
                text: "power_settings_new"
                color: Colours.palette.m3error
                fontStyle: Tokens.font.icon.builders.small.weight(Font.Bold).build()
            }
        }
    }
}
