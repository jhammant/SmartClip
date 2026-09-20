# SmartClip — state as of 2026-09-20

## What this is
`/cpy`, `/pst`, `/clh` for Claude Code, plus (new) **SmartClip.app**: a menu-bar
Mac app in `mac/` that records everything you copy into the same store the
commands read, and pastes it back with ⌥⌘V.

## Where it stands
Done and verified end-to-end on this Mac:
- Capture of text, **images** (stored as PNG, OCR'd with Vision) and Finder file
  copies (paths only). Password-manager clips skipped via `org.nspasteboard.*`
  markers; credential-shaped text — and screenshots whose text looks like a
  credential — dropped entirely.
- Retention: history lines kept **for ever** (the index is the archive); only
  clip *contents* are budgeted at 20 GB, oldest evicted first; single items over
  16 MB never stored. Verified live with a 10 KB budget.
- ⌥⌘V picker (search incl. OCR text, ↑↓, ⏎ paste, ⌘1–9, thumbnails).
  `smartclip history search TEXT` searches the whole index; `/clh` uses it.
- Installed at `/Applications/SmartClip.app`, signed with the Apple Development
  cert (so the Accessibility grant survives rebuilds), running now. 22 tests green.

Not done: **Accessibility grant** and **Open at login** — both need Jon to click
them in the menu bar. Until the grant, ⏎ in the picker only copies, no ⌘V.

## Next steps
1. Menu bar icon → *Enable paste-back…*, then *Open at login*. Test ⌥⌘V.
2. Paste-as transforms: plain/trimmed/extract URLs locally; "tidy this" /
   "reply in my voice" via LM Studio (free, local).
3. `/pst 3` and `/pst the link I copied from Slack` — resolve by history index /
   source app, which the `app` and `ts` fields already support.
4. Consider a launch write-up — this is a shippable OSS release (stars goal).

## Open questions
- Ship the Mac app as a signed/notarised download, or build-from-source only?
- Is 20 GB right once screenshots accumulate? Nothing has stressed it yet.
- Whether image OCR text (up to 8 KB/line) should stay in `history.jsonl` for
  ever, or move to sidecar files if the index gets slow to load.

## Ideas worth keeping
- **The index is the archive, the bytes are the cache.** Keep a permanent,
  cheap text index of every event; budget only the heavy payloads and evict
  oldest-first. Gives "keep everything for ever" honestly within a disk cap.
- **Two writers, one log.** A CLI and a GUI appending to one JSONL: the GUI
  waits a beat and defers to the CLI's richer labelled entry instead of both
  logging. Same trick fits any agent+daemon pair sharing a store.
- **Normalise last, not first.** The secret-detector stripped whitespace before
  testing "is this one opaque token", so ordinary sentences were redacted.
  Normalising before a shape test destroys the evidence the test needs.
- **OCR turns an unscannable blob into policy-checkable text** — reading a
  screenshot let the same credential rules apply to images.

---
_Updated by `forkcode close` on 2026-09-20T21:47+01:00_
