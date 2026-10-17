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
    readonly property string sessionList: Quickshell.env("HOME") + "/.local/bin/pi-sessions"
    readonly property string serverUrl: "http://127.0.0.1:8000"

    property bool busy: false
    property bool visible: false
    property bool pinned: false // opened by click: survives the pointer leaving
    property var resumePaths: []
    readonly property alias history: logModel
    property bool serverRunning: false
    property real tokensPerSecond: 0
    property int lastDecoded: 0
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

    // Slash commands typed in the composer. Returns true when handled locally.
    function command(text): bool {
        const [cmd, arg] = text.trim().split(/\s+/);
        if (cmd === "/new") {
            newChat();
        } else if (cmd === "/resume") {
            if (arg)
                resume(arg);
            else
                listSessions();
        } else if (cmd === "/help") {
            addRow("info", "/new — start a new session   /resume — list recent sessions   /resume <n> — switch");
        } else {
            return false;
        }
        return true;
    }

    function listSessions(): void {
        if (sessions.running)
            return;
        resumePaths = [];
        sessions.running = true;
    }

    function resume(arg): void {
        const i = parseInt(arg, 10) - 1;
        const path = resumePaths[i];
        if (!path) {
            addRow("error", "no session " + arg + " — run /resume first");
            return;
        }
        agent.write(JSON.stringify({
            type: "switch_session",
            sessionPath: path
        }) + "\n");
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
            tokensPerSecond = 0;
            const reply = lastStreamRow >= 0 ? logModel.get(lastStreamRow).text.trim() : "";
            // Panel closed: let the user know the answer is ready.
            if (!visible && reply)
                Toaster.toast("oshelper", reply.slice(-200), "smart_toy", Toast.Info);
        } else if (ev.type === "response" && ev.command === "switch_session" && ev.success) {
            logModel.clear();
            lastStreamRow = -1;
            agent.write('{"type":"get_messages"}\n');
        } else if (ev.type === "response" && ev.command === "get_messages" && ev.success) {
            const rows = (ev.data?.messages || []).filter(m => m.role === "user" || m.role === "assistant");
            for (const m of rows) {
                const parts = Array.isArray(m.content) ? m.content : [];
                const body = parts.filter(p => p.type === "text").map(p => p.text).join("\n").trim();
                if (body)
                    addRow(m.role, body);
            }
            lastStreamRow = -1;
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

    // Generation speed straight from llama-server, sampled once a second while busy.
    function sampleSpeed(): void {
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            let decoded = 0;
            try {
                const nt = JSON.parse(xhr.responseText)[0].next_token;
                decoded = (Array.isArray(nt) ? nt[0] : nt).n_decoded;
            } catch (e) {
                return;
            }
            const delta = decoded - lastDecoded;
            lastDecoded = decoded;
            tokensPerSecond = delta > 0 ? delta : tokensPerSecond;
        };
        xhr.open("GET", serverUrl + "/slots");
        xhr.send();
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.busy

        onRunningChanged: {
            if (running) {
                root.lastDecoded = 0;
                root.tokensPerSecond = 0;
            }
        }

        onTriggered: root.sampleSpeed()
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
        id: sessions

        command: [root.sessionList, "8"]
        stdout: SplitParser {
            onRead: line => {
                const [path, date, ...rest] = line.split("\t");
                root.resumePaths.push(path);
                root.addRow("info", root.resumePaths.length + ". " + date + "  " + rest.join(" "));
            }
        }
        onExited: {
            if (root.resumePaths.length === 0)
                root.addRow("info", "no sessions yet");
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
