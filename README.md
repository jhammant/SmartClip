# 📋 SmartClip

**Intelligent clipboard commands for [Claude Code](https://claude.com/claude-code).**

SmartClip adds slash commands that understand *what you were just doing*:

- **`/clp`** — **smart copy.** Looks at your recent work — code you were
  writing, an email reply, docs, a shell command, JSON — and copies the clean,
  paste-ready version of it to your system clipboard. No more hand-selecting the
  right lines out of a wall of chat.
- **`/pst`** — **smart paste.** Reads your clipboard and does the *right thing
  with it* in context — diagnoses a pasted stack trace, integrates a snippet,
  drafts a reply to a pasted message, pretty-prints JSON, and so on.
- **`/clh`** — **clip history** *(opt-in)*. A typed, searchable history of
  everything you've copied. List it, recall item #3, or ask in plain English —
  "the last url", "that python function". See [Clipboard history](#clipboard-history).

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

Run a command bare to let SmartClip infer what you mean — or add a **smart
argument** to tell it exactly.

### `/clp` — smart copy

> Also available as **`/cpy`** — an identical alias, if that's easier to reach for.

| Command | What lands on your clipboard |
|---|---|
| `/clp` | the best-guess deliverable from recent work |
| `/clp just the code` · `/clp the function` | only the code, raw, no fences |
| `/clp the command` | just the shell command(s), runnable |
| `/clp the email` · `/clp the reply` | the last email / message body you drafted |
| `/clp the diff` | the most recent diff / patch |
| `/clp as plain text` · `/clp as markdown` | the last answer, in that format |
| `/clp usernames` · `/clp the emails` · `/clp the urls` | **extraction** — every match, one per line |

### `/pst` — smart paste

| Command | What SmartClip does |
|---|---|
| `/pst` | read clipboard, infer the smart action, do it |
| `/pst explain this` | explain whatever's on the clipboard |
| `/pst run this` | run the clipboard contents as a command¹ |
| `/pst fix this` | treat the clipboard as an error/snippet and fix the cause |
| `/pst add to utils.py` | integrate the clipboard snippet into a file |
| `/pst draft a reply` | draft a reply to a pasted message |
| `/pst convert to <X>` | convert it (JSON→YAML, JS→TS, `curl`→`fetch`, …) |

¹ `run this` echoes the command first and lets Claude Code's normal permission
prompt gate anything destructive — it never auto-approves dangerous commands.

Both commands accept any free-text instruction; if you give none, SmartClip
infers intent from the conversation.

### `/clh` — clip history *(opt-in)*

| Command | What SmartClip does |
|---|---|
| `/clh` | list recent clips (numbered, newest first, with type + preview) |
| `/clh 3` | re-copy item #3 back to the clipboard |
| `/clh the last url` · `/clh that python function` | natural-language recall — find the match and re-copy it |
| `/clh clear` | purge all history |

History is **off by default**. Turn it on with `export SMARTCLIP_HISTORY=1`.

---

## Clipboard history

`/clh` is backed by a small, **opt-in** typed history. It's built to be safe by
default:

- **Off unless you opt in.** Nothing is recorded until you set
  `SMARTCLIP_HISTORY=1`. A single copy can opt out with `smartclip copy --no-history`.
- **Owner-only on disk.** Stored under `${XDG_DATA_HOME:-~/.local/share}/smartclip`
  with `umask 077` — directory `700`, files `600`. No other user can read it.
- **Secrets are skipped, not stored.** Anything that looks like a credential —
  GitHub/GitLab/Slack/Stripe/AWS/Google tokens, JWTs, PEM private keys, or
  `password = …` / `api_key: …` lines — is detected and **never written to
  disk**; the history just notes that a clip was skipped, with a redacted preview.
- **Add your own rules.** `SMARTCLIP_HISTORY_EXCLUDE='<regex>'` marks any matching
  clip as never-store (e.g. an internal project codename).
- **Bounded.** Clips larger than `SMARTCLIP_HISTORY_MAXSIZE` (default 1 MiB) aren't
  stored; the log is capped at `SMARTCLIP_HISTORY_MAX` entries (default 200), oldest pruned.
- **Easy to wipe.** `smartclip history clear` (or `/clh clear`) deletes everything.

> ⚠️ Detection is best-effort and history is **plaintext on disk**. Don't enable
> it on shared or untrusted machines. If you copy a secret SmartClip didn't
> recognise, run `smartclip history clear`.

| Variable | Default | Effect |
|---|---|---|
| `SMARTCLIP_HISTORY` | *(unset)* | set to `1` to enable recording |
| `SMARTCLIP_HISTORY_MAX` | `200` | max entries kept |
| `SMARTCLIP_HISTORY_MAXSIZE` | `1048576` | max bytes stored per clip |
| `SMARTCLIP_HISTORY_EXCLUDE` | *(none)* | regex of content to never store |
| `SMARTCLIP_DATA_DIR` | `~/.local/share/smartclip` | where history lives |

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
│   ├── cpy.md               # /cpy prompt — identical alias of /clp
│   ├── pst.md               # /pst prompt — reads clipboard, acts in context
│   └── clh.md               # /clh prompt — list / recall clip history
├── bin/
│   └── smartclip            # cross-platform copy/paste/history helper (POSIX sh)
├── install.sh               # standalone installer
├── video/                   # Remotion source for the launch video
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
