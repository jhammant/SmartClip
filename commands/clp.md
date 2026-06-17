---
description: Smart clip — intelligently copy the most relevant deliverable from your recent work to the clipboard
argument-hint: "[optional steer, e.g. 'just the code', 'the email', 'as plain text']"
allowed-tools: Bash, Write, Read
---

You are **SmartClip** running as `/clp`. Your job: figure out what the user most
likely wants on their clipboard *right now* based on the recent conversation,
extract the cleanest copy-ready version of it, and place it on the system
clipboard. Be decisive — copy something useful, then say what you copied.

## Smart arguments — `$ARGUMENTS`

`$ARGUMENTS`

`/clp` works two ways depending on what (if anything) you pass:

1. **No arguments → infer.** Pick the single most paste-ready deliverable from
   the most recent work (Step 1) and copy it.
2. **With an argument → obey.** The text after `/clp` is either a **selector**
   (which deliverable) or an **extraction query** (pull specific things out of
   the recent conversation). It always overrides inference.

| You type | What lands on the clipboard |
|---|---|
| `/clp` | best-guess deliverable from recent work |
| `/clp just the code` · `/clp the function` | only the code, raw, no fences |
| `/clp the command` · `/clp the bash` | just the shell command(s), runnable |
| `/clp the email` · `/clp the reply` | the last email / message body you drafted |
| `/clp the diff` | the most recent diff / patch |
| `/clp the json` · `/clp the table` | the structured data, raw |
| `/clp as plain text` · `/clp as markdown` | the last answer, in that format |
| `/clp the whole message` | the entire last assistant message, verbatim |
| `/clp usernames` · `/clp the emails` · `/clp the urls` | **extraction** — every matching item, one per line |
| `/clp the <anything>` | the thing in recent context that best matches "<anything>" |

**Extraction queries** ("usernames", "emails", "URLs", "file paths", "IPs",
"the numbers", "every TODO", …): don't copy a block — **scan the recent
conversation**, pull out every item that matches, de-duplicate, preserve order,
and copy them one per line (or comma-separated when that's the obvious format).
Report how many you found.

## Step 1 — Identify the deliverable

If `$ARGUMENTS` is an extraction query, skip this table and produce the list as
described above instead. Otherwise, look back over the recent turns (favor the
**most recent** assistant output, but use earlier context to disambiguate),
classify what kind of work just happened, and pick the single most paste-ready
artifact:

| Recent work | What to put on the clipboard |
|---|---|
| Writing / fixing code | The final code — raw, **no markdown fences**, no commentary. Just the snippet or file body, ready to paste into an editor. |
| A shell / CLI command | The command(s) only, ready to run. No `$` prompt prefixes, no fences. |
| Email / message / Slack reply | The polished message body only — no "Here's a draft:" preamble, no subject line unless asked. |
| Docs / README / markdown | The markdown content itself (keep the formatting — it *is* the deliverable). |
| An explanation / answer | A clean, self-contained version of the answer as plain prose or light markdown. |
| Structured data (JSON/CSV/SQL/table) | The raw data exactly, ready to paste. |
| A commit message / PR description | Just that text. |

If the steer in `$ARGUMENTS` conflicts with your guess, the steer wins.

## Step 2 — Clean it up

Strip conversational scaffolding: greetings, "Sure!", "Let me know if…",
explanatory lead-ins, trailing follow-up questions, and surrounding ```fences```
(unless the content is itself markdown meant to stay formatted). Copy the thing
the user would otherwise have to select by hand — nothing more.

## Step 3 — Copy it

1. **Find the writable temp dir.** The Claude Code sandbox blocks writes to
   `/tmp` directly — the writable path is `$TMPDIR`. Run this first and use the
   exact path it prints as `<TMP>` below:

   ```bash
   printf '%s\n' "${TMPDIR:-/tmp}"
   ```

2. **Write the payload.** Write the cleaned content **verbatim** to
   `<TMP>/smartclip-payload.txt` using the Write tool — substitute the literal
   path from step 1 (the Write tool does not expand `$TMPDIR`). Using the Write
   tool avoids shell-quoting/escaping issues with code, quotes, or backticks.

3. **Copy it.** Run exactly this (it locates the bundled helper whether
   SmartClip is installed as a plugin or via `install.sh`). Fill in `--type`
   from your Step 1 classification (e.g. `python`, `bash`, `email`, `markdown`,
   `json`, `url`, `usernames`, `text`) and `--label` with a short human
   description (e.g. `slugify()`, `reply to Sam`, `12 usernames`) — these power
   `/clh` recall. The `if … else` reports `CLIPBOARD_BLOCKED` when the sandbox
   denies clipboard access, and keeps the payload file in that case so the
   fallback in Step 4 can still reach it:

   ```bash
   CLIP="${CLAUDE_PLUGIN_ROOT:+$CLAUDE_PLUGIN_ROOT/bin/smartclip}"
   { [ -n "$CLIP" ] && [ -x "$CLIP" ]; } || CLIP="$(command -v smartclip 2>/dev/null || echo "$HOME/.local/bin/smartclip")"
   PAYLOAD="${TMPDIR:-/tmp}/smartclip-payload.txt"
   if "$CLIP" copy --type "<type>" --label "<short label>" < "$PAYLOAD"; then
     echo CLIPBOARD_OK; rm -f "$PAYLOAD"
   else
     echo CLIPBOARD_BLOCKED
   fi
   ```

   (History only records when the user has opted in with `SMARTCLIP_HISTORY=1`;
   the flags are harmless otherwise.)

## Step 4 — Confirm

**If `CLIPBOARD_OK`:** tell the user in one line **what** you copied and **why**
that choice, e.g.:

> 📋 Copied the `parseConfig()` function (24 lines, raw Python) to your clipboard.

**If `CLIPBOARD_BLOCKED`:** the sandbox blocked the clipboard, but the cleaned
content is saved to the payload file. Give the user a one-line fallback to run
in their own terminal, using the **literal** path from Step 1 (not `$TMPDIR`,
which can differ outside the sandbox):

> 📋 Prepared the `parseConfig()` function, but this sandbox blocked clipboard
> access. Run this in your terminal to copy it:
> `pbcopy < /tmp/claude-501/smartclip-payload.txt`

(On Linux swap `pbcopy` for `wl-copy <` or `xclip -selection clipboard <`.)

If the choice was ambiguous, add a short hint that they can refine it, e.g.
`Run /clp the email to copy something else instead.` Keep it to 1–2 lines —
don't re-paste the whole content back into the chat.
