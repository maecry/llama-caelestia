# llama-caelestia

Local LLM chat inside the [caelestia](https://github.com/caelestia-dots/shell) bar: a robot icon
above the power button, a chat popout on hover, and one play/stop button for the llama.cpp server.

The model answers in **caveman** style with lazy-senior-dev rules, and that style is baked into the
*server* (chat template), so every client — this panel, `pi`, `curl`, anything — gets it without
per-client configuration.

```
bar (bottom left)         popout
┌──────────┐              ┌──────────────────────────────┐
│  robot   │  hover  ──▶  │ llama.cpp  ready   ■  +  ×  │
├──────────┤              │  you: how do I …             │
│  power   │              │  llama: do X. only if Y.     │
└──────────┘              │  …                           │
                          │ [ ask local model…         ] │
                          └──────────────────────────────┘
```

## What it does

- **Robot button** stacked above the power button in the bar. Hover it → chat popout opens.
- **Play / stop** in the popout header starts and stops `llama-server` (`llama-ctl toggle`).
- **Chat** runs `pi --mode rpc` inside the shell, so it has pi's tools, sessions and file access —
  an OS helper, not just a prompt box. The process lives in the shell singleton, so closing the
  panel keeps the session running in the background.
- **Toast when an answer lands** while the panel is closed.
- **Popout closes** when the pointer leaves it; the chat keeps going.
- Styling uses real caelestia Material 3 tokens (`Colours`, `Tokens`, `Anim`, `MaterialIcon`).

## How it hooks into the shell

caelestia's QML lives in a root-owned package directory, so nothing is edited in place.
`sync.sh` mirrors `/etc/xdg/quickshell/caelestia` into `~/.config/quickshell/caelestia` as per-file
symlinks, then `shell-overlay/patch.py` applies four small textual patches to the *copies*:

| patch | file | what |
|---|---|---|
| 1 | `modules/bar/popouts/Content.qml` | register the `chat` popout |
| 2 | `modules/bar/Bar.qml` | pass popout state to the power entry, route robot hover to `chat` |
| 3 | `modules/drawers/ContentWindow.qml` | keyboard focus while the chat popout is open |
| 4 | — | copy `shell-overlay/modules/{chat,bar}` into the mirror |

Every anchor must match exactly once, so a caelestia update that breaks a patch fails loudly
instead of silently misapplying. `./sync.sh --clean` drops the mirror and returns you to the
packaged shell.

## Requirements

- caelestia shell (any recent version that has bar popouts), Quickshell
- llama.cpp with a server-capable build (`llama-server`)
- [pi](https://github.com/badlogic/pi-mono) at `~/.pi/agent/bin/pi` with a `local` provider entry
  pointing at `http://127.0.0.1:8000/v1` (see below)
- The model of your choice; defaults target `Ornith-1.5-9B` Q8_0 + vision mmproj

## Install

```bash
git clone https://github.com/maecry/llama-caelestia
cd llama-caelestia

cp config.env.example config.env   # edit: llama.cpp build path + model paths
./install.sh                       # ~/.local/bin/llama-ctl + shell mirror + patches
qs -c caelestia kill; sleep .1; caelestia shell -d
```

`~/.pi/agent/models.json` needs the provider the panel talks to:

```json
{
  "providers": {
    "local": {
      "baseUrl": "http://127.0.0.1:8000/v1",
      "models": [{ "id": "Ornith-1.5-9B", "contextWindow": 196608, "vision": true }]
    }
  }
}
```

If your model id differs, change `model` in `shell-overlay/modules/chat/ChatState.qml` (the panel
passes it straight to `pi --model`).

## Server control

```bash
llama-ctl start | stop | toggle | status   # status exits 0 when running
scripts/run-server.sh                      # foreground, same thing the panel spawns
```

`run-server.sh` reads `config.env` from the repo root and then environment overrides
(`CTX`, `NGL`, `PORT`, `TEMP`, `UBATCH`, `LOAD_MODE`, …). If the build directory is not on the
loader path, it exports `LD_LIBRARY_PATH` to the directory holding `llama-server` — without that,
`llama-server` starts and immediately dies when launched from anywhere else.

## The caveman + ponytail style block

`style/caveman-ponytail.jinja` is a chat template: the model's own template with an extra system
block injected before the tools section. `run-server.sh` passes it with `--chat-template-file`, so
the style applies at the server, for every client, and cannot be overridden by a client's system
prompt (it is part of the template-rendered system message).

`style/gguf-template.py` dumps the template of a GGUF so you can rebase the block onto another
model:

```bash
python3 style/gguf-template.py model.gguf > style/mine.jinja   # then paste the style block in
```

Two rules to keep when editing it:

- Jinja comments must end with `-#}`, not `-*-}`; the latter leaves `render_content` undefined and
  every request 500s.
- Keep the style block above the tools section, otherwise tool calls get the chatty style too.

## Layout

```
install.sh                 one-shot install
sync.sh                    mirror + patch the shell (--clean to revert)
shell-overlay/patch.py     the textual patches
shell-overlay/modules/chat/ChatState.qml   pi RPC process, log, server state, completion toast
shell-overlay/modules/chat/Panel.qml       popout body
shell-overlay/modules/bar/components/Power.qml  robot above the power button
scripts/llama-ctl.sh       start/stop/toggle/status
scripts/run-server.sh      llama-server launch (template + tuning)
style/                     chat template + tooling
legacy-tray/               earlier SNI tray (Rust, ksni); unused, kept for reference
```

## Troubleshooting

- **Panel opens but nothing is clickable** — the mirror is stale; rerun `./sync.sh` and restart.
- **`patch.py` assertion error** — caelestia changed the file the patch anchors to. Compare the
  anchor with the new packaged file and update `patch.py`.
- **Play does nothing** — check `llama-server.log` in the repo root; usually a missing model path in
  `config.env` or a missing shared library (`LD_LIBRARY_PATH`, see above).
- **`noctalia-qs was built against Qt 6.11.2 but the system has 6.12.0`** — rebuild the quickshell
  package; the mismatch makes panels behave oddly on some setups.

## License

MIT
