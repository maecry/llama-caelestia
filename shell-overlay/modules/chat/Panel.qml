pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

// Chat panel body, shown as a bar popout.
Item {
    id: root

    required property var popouts

    readonly property bool active: root.popouts.hasCurrent && root.popouts.currentName === "chat"

    onActiveChanged: ChatState.visible = active

    function close(): void {
        root.popouts.hasCurrent = false;
    }

    implicitWidth: 400
    implicitHeight: 520

    Component.onCompleted: {
        ChatState.refreshServer();
        input.forceActiveFocus();
    }

    StyledRect {
        anchors.fill: parent
        radius: Tokens.rounding.extraLarge
        color: Colours.tPalette.m3surfaceContainerLow

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Tokens.padding.large
            spacing: Tokens.spacing.medium

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                MaterialIcon {
                    text: "smart_toy"
                    color: Colours.palette.m3primary
                    fontStyle: Tokens.font.icon.medium
                    fill: 1
                }

                ColumnLayout {
                    spacing: 0

                    StyledText {
                        text: "llama.cpp"
                        font: Tokens.font.title.small
                        color: Colours.palette.m3onSurface
                    }

                    StyledText {
                        text: ChatState.busy ? "working…" : ChatState.serverRunning ? "ready" : "server stopped"
                        font: Tokens.font.body.small
                        color: ChatState.busy ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                    }
                }

                Item {
                    Layout.fillWidth: true
                }

                IconButton {
                    type: IconButton.Text
                    isRound: true
                    icon: ChatState.serverRunning ? "stop" : "play_arrow"
                    activeColour: ChatState.serverRunning ? Colours.palette.m3error : Colours.palette.m3primary
                    inactiveColour: ChatState.serverRunning ? Colours.palette.m3error : Colours.palette.m3primary
                    onClicked: ChatState.toggleServer()
                }

                IconButton {
                    type: IconButton.Text
                    isRound: true
                    icon: "add"
                    onClicked: ChatState.newChat()
                }

                IconButton {
                    type: IconButton.Text
                    isRound: true
                    icon: "close"
                    onClicked: root.close()
                }
            }

            Flickable {
                id: flick

                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: width
                contentHeight: column.implicitHeight
                boundsBehavior: Flickable.StopAtBounds

                function scrollToEnd(): void {
                    Qt.callLater(() => {
                        scrollAnim.to = Math.max(0, flick.contentHeight - flick.height);
                        scrollAnim.start();
                    });
                }

                NumberAnimation {
                    id: scrollAnim

                    target: flick
                    property: "contentY"
                    duration: Tokens.anim.durations.normal
                    easing: Tokens.anim.emphasized
                }

                Connections {
                    target: ChatState.history

                    function onRowsInserted(): void {
                        flick.scrollToEnd();
                    }

                    function onDataChanged(): void {
                        flick.scrollToEnd();
                    }
                }

                Column {
                    id: column

                    width: flick.width
                    spacing: Tokens.spacing.small

                    Repeater {
                        model: ChatState.history

                        delegate: Item {
                            id: row

                            required property string kind
                            required property string text

                            width: column.width
                            height: kind === "user" ? bubble.height : kind === "tool" ? chip.implicitHeight : body.implicitHeight
                            opacity: 0

                            Component.onCompleted: appear.start()

                            Anim {
                                id: appear

                                target: row
                                property: "opacity"
                                to: 1
                                type: Anim.FastEffects
                            }

                            StyledRect {
                                id: bubble

                                visible: row.kind === "user"
                                anchors.right: parent.right
                                width: Math.min(parent.width * 0.85, userText.implicitWidth + Tokens.padding.large)
                                height: userText.implicitHeight + Tokens.padding.medium
                                radius: Tokens.rounding.large
                                bottomRightRadius: Tokens.rounding.extraSmall
                                color: Colours.tPalette.m3primaryContainer

                                StyledText {
                                    id: userText

                                    anchors.fill: parent
                                    anchors.margins: Tokens.padding.small
                                    text: row.text
                                    color: Colours.palette.m3onPrimaryContainer
                                    font: Tokens.font.body.medium
                                    wrapMode: Text.Wrap
                                }
                            }

                            StyledText {
                                id: body

                                visible: row.kind !== "user"
                                width: parent.width
                                text: row.text
                                color: row.kind === "error" ? Colours.palette.m3error : Colours.palette.m3onSurface
                                font: Tokens.font.body.medium
                                textFormat: row.kind === "assistant" ? Text.MarkdownText : Text.PlainText
                                wrapMode: Text.Wrap
                            }

                            StyledRect {
                                id: chip

                                visible: row.kind === "tool"
                                implicitWidth: Math.min(row.width, chipRow.implicitWidth + Tokens.padding.medium)
                                implicitHeight: chipRow.implicitHeight + Tokens.padding.extraSmall
                                radius: Tokens.rounding.small
                                color: Colours.tPalette.m3surfaceContainerHigh

                                RowLayout {
                                    id: chipRow

                                    anchors.centerIn: parent
                                    spacing: Tokens.spacing.extraSmall

                                    MaterialIcon {
                                        text: "build"
                                        color: Colours.palette.m3onSurfaceVariant
                                        fontStyle: Tokens.font.icon.extraSmall
                                    }

                                    StyledText {
                                        Layout.maximumWidth: row.width - Tokens.padding.large * 2
                                        text: row.text
                                        elide: Text.ElideRight
                                        color: Colours.palette.m3onSurfaceVariant
                                        font: Tokens.font.mono.small
                                    }
                                }
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 6
                spacing: Tokens.spacing.extraSmall
                visible: ChatState.busy

                Repeater {
                    model: 3

                    delegate: StyledRect {
                        required property int index

                        implicitWidth: 6
                        implicitHeight: 6
                        radius: Tokens.rounding.full
                        color: Colours.palette.m3primary
                        opacity: 0.3

                        SequentialAnimation on opacity {
                            running: ChatState.busy
                            loops: Animation.Infinite
                            PauseAnimation {
                                duration: index * 130
                            }
                            Anim {
                                to: 1
                                type: Anim.FastEffects
                            }
                            Anim {
                                to: 0.3
                                type: Anim.SlowEffects
                            }
                            PauseAnimation {
                                duration: (2 - index) * 130
                            }
                        }
                    }
                }
            }

            StyledRect {
                Layout.fillWidth: true
                implicitHeight: input.implicitHeight + Tokens.padding.medium * 2

                radius: Tokens.rounding.large
                color: Colours.tPalette.m3surfaceContainerHighest
                border.width: 1
                border.color: input.activeFocus ? Colours.palette.m3primary : "transparent"

                Behavior on border.color {
                    CAnim {}
                }

                TextInput {
                    id: input

                    anchors.fill: parent
                    anchors.leftMargin: Tokens.padding.medium
                    anchors.rightMargin: Tokens.padding.medium
                    verticalAlignment: TextInput.AlignVCenter
                    color: Colours.palette.m3onSurface
                    font: Tokens.font.body.medium
                    selectionColor: Colours.palette.m3primary
                    selectedTextColor: Colours.palette.m3onPrimary
                    clip: true

                    Keys.onReturnPressed: {
                        ChatState.send(input.text);
                        input.text = "";
                    }

                    Keys.onEscapePressed: root.close()
                }

                StyledText {
                    anchors.left: parent.left
                    anchors.leftMargin: Tokens.padding.medium
                    anchors.verticalCenter: parent.verticalCenter
                    text: "ask local model…"
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.body.medium
                    visible: input.text.length === 0
                }
            }
        }
    }
}
