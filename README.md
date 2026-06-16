# 📋 SmartClip

**Intelligent clipboard commands for [Claude Code](https://claude.com/claude-code).**

SmartClip adds two slash commands that understand *what you were just doing*:

- **`/clp`** — **smart copy.** Looks at your recent work — code you were
  writing, an email reply, docs, a shell command, JSON — and copies the clean,
  paste-ready version of it to your system clipboard. No more hand-selecting the
  right lines out of a wall of chat.
- **`/pst`** — **smart paste.** Reads your clipboard and does the *right thing
  with it* in context — diagnoses a pasted stack trace, integrates a snippet,
  drafts a reply to a pasted message, pretty-prints JSON, and so on.

Cross-platform: macOS, Linux (Wayland & X11), Windows/WSL, and Termux.

---

## Why

Claude Code generates something great, and then you... drag-select it out of the
terminal, fighting markdown fences and "Sure, here's the code!" preambles.
SmartClip closes that last mile. `/clp` knows the *deliverable* from the
*chatter* and copies only the part you actually want.

```text
You: write me a python function to slugify a string
Claude: Sure! Here's a clean implementation… ```python … ``` …explanation…
You: /clp
📋 Copied the slugify() function (9 lines, raw Python) to your clipboard.
```

```text
(you copy a failing test's stack trace from your terminal)
You: /pst
📋 Clipboard held a pytest AssertionError — traced it to auth.py:88 and
   patched the off-by-one. Details below.
```

---

## Install

### Option A — as a Claude Code plugin (recommended)

From inside Claude Code:

```text
/plugin marketplace add jhammant/SmartClip
/plugin install smartclip@smartclip
```

> Local checkout? Use the path instead:
> `/plugin marketplace add /path/to/SmartClip`

Then restart Claude Code. The bundled `smartclip` helper ships with the plugin —
nothing else to install.

### Option B — standalone install script

```bash
git clone https://github.com/jhammant/SmartClip.git
cd SmartClip
./install.sh
```

…or one-liner:

```bash
curl -fsSL https://raw.githubusercontent.com/jhammant/SmartClip/main/install.sh | sh
```

This installs the `smartclip` helper to `~/.local/bin` and the `/clp` + `/pst`
commands to `~/.claude/commands/`. Restart Claude Code and you're set.

---

## Usage

| Command | What it does |
|---|---|
| `/clp` | Auto-detect the best deliverable from recent work and copy it. |
| `/clp just the code` | Steer it — copy only the code block. |
| `/clp the email` | Copy the message/email body. |
| `/clp as plain text` | Strip formatting, copy plain text. |
| `/pst` | Read clipboard, infer the smart action, do it. |
| `/pst explain` | Explain whatever's on the clipboard. |
| `/pst add to utils.py` | Integrate the clipboard snippet into a file. |
| `/pst draft a reply` | Draft a reply to a pasted message. |

Both commands accept a free-text steer after the command name; if you give none,
SmartClip infers intent from the conversation.

---

## How it works

SmartClip is deliberately simple — no daemon, no API keys, no telemetry.

```text
SmartClip/
├── .claude-plugin/
│   ├── plugin.json          # plugin manifest
│   └── marketplace.json     # so others can `/plugin marketplace add`
├── commands/
│   ├── clp.md               # /clp prompt — picks & cleans the deliverable
│   └── pst.md               # /pst prompt — reads clipboard, acts in context
├── bin/
│   └── smartclip            # cross-platform copy/paste helper (POSIX sh)
├── install.sh               # standalone installer
├── LICENSE
└── README.md
```

- The **commands** are prompt templates. When you run `/clp`, Claude already has
  your conversation in context, so it classifies the most recent deliverable,
  strips the conversational scaffolding, and writes the clean payload to a temp
  file.
- The **`smartclip` helper** does the actual OS clipboard I/O, auto-selecting
  `pbcopy`/`pbpaste`, `wl-copy`/`wl-paste`, `xclip`, `xsel`, `clip.exe` /
  `powershell.exe`, or Termux's clipboard tools.

You can use the helper directly too:

```bash
echo "hello" | smartclip copy     # → clipboard
smartclip paste                   # clipboard → stdout
```

### Clipboard backends

| Platform | Copy | Paste | Install |
|---|---|---|---|
| macOS | `pbcopy` | `pbpaste` | built in |
| Linux (Wayland) | `wl-copy` | `wl-paste` | `wl-clipboard` |
| Linux (X11) | `xclip` / `xsel` | `xclip` / `xsel` | `xclip` or `xsel` |
| Windows / WSL | `clip.exe` | `powershell.exe Get-Clipboard` | built in |
| Termux (Android) | `termux-clipboard-set` | `termux-clipboard-get` | `termux-api` |

---

## Contributing

Issues and PRs welcome. Good first contributions: more clipboard backends,
smarter content classification, and demo GIFs.

1. Fork & branch (`feat/…`, `fix/…`).
2. Keep `bin/smartclip` POSIX-`sh` clean (test with `sh`, not just `bash`).
3. Open a PR with a clear description.

## License

[MIT](LICENSE) © 2026 Jonathan Hammant
