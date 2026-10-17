pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia

// Chat state lives outside the popout so closing the panel keeps the pi session alive.
Singleton {
    id: root

    // edit for your setup
    readonly property string ctl: Quickshell.env("HOME") + "/.local/bin/llama-ctl" // install.sh symlinks it there
    readonly property string piBin: Quickshell.env("HOME") + "/.pi/agent/bin/pi"
    readonly property string model: "local/Ornith-1.5-9B"

    property bool busy: false
    property bool visible: false
    readonly property alias history: logModel
    property bool serverRunning: false
    property int lastStreamRow: -1
    property int lastToolRow: -1

    function addRow(kind, text): int {
        logModel.append({
            kind: kind,
            text: text
        });
        return logModel.count - 1;
    }

    function stream(delta): void {
        if (lastStreamRow < 0)
            return;
        logModel.setProperty(lastStreamRow, "text", logModel.get(lastStreamRow).text + delta);
    }

    function send(text): void {
        text = (text ?? "").trim();
        if (!text)
            return;
        addRow("user", text);
        const cmd = {
            type: "prompt",
            message: text
        };
        if (busy)
            cmd.streamingBehavior = "steer";
        agent.write(JSON.stringify(cmd) + "\n");
        lastStreamRow = addRow("assistant", "");
        lastToolRow = -1;
        busy = true;
    }

    function newChat(): void {
        if (busy)
            return;
        agent.write('{"type":"new_session"}\n');
        logModel.clear();
        lastStreamRow = -1;
    }

    function onLine(line): void {
        if (!line)
            return;
        let ev;
        try {
            ev = JSON.parse(line);
        } catch (e) {
            return;
        }

        const inner = ev.assistantMessageEvent;
        if (ev.type === "message_update" && inner) {
            if (inner.type === "text_delta")
                stream(inner.delta);
        } else if (ev.type === "tool_execution_start") {
            const a = ev.args || {};
            lastToolRow = addRow("tool", ev.toolName + "  " + String(a.command ?? a.path ?? a.pattern ?? JSON.stringify(a)).slice(0, 80));
        } else if (ev.type === "tool_execution_end") {
            if (lastToolRow >= 0)
                logModel.setProperty(lastToolRow, "text", logModel.get(lastToolRow).text + (ev.isError ? "   ✗" : "   ✓"));
        } else if (ev.type === "agent_settled") {
            busy = false;
            const reply = lastStreamRow >= 0 ? logModel.get(lastStreamRow).text.trim() : "";
            // Panel closed: let the user know the answer is ready.
            if (!visible && reply)
                Toaster.toast("llama.cpp", reply.slice(-200), "smart_toy", Toast.Info);
        } else if (ev.type === "response" && ev.success === false) {
            addRow("error", ev.error || "command failed");
            busy = false;
        }
    }

    function refreshServer(): void {
        if (!serverCheck.running)
            serverCheck.running = true;
    }

    function toggleServer(): void {
        if (serverToggle.running)
            return;
        serverRunning = !serverRunning;
        serverToggle.running = true;
    }

    ListModel {
        id: logModel
    }

    Process {
        id: agent

        command: [root.piBin, "--mode", "rpc", "--model", root.model]
        workingDirectory: "/home/maecry"
        stdinEnabled: true
        running: true

        stdout: SplitParser {
            onRead: line => root.onLine(line)
        }
    }

    Process {
        id: serverCheck

        command: [root.ctl, "status"]
        onExited: code => root.serverRunning = code === 0
    }

    Process {
        id: serverToggle

        command: [root.ctl, "toggle"]
        onExited: root.refreshServer()
    }
}
