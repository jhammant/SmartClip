#!/usr/bin/env sh
# SmartClip installer (standalone / non-plugin path).
#
# Installs the `smartclip` helper onto your PATH and copies the /clp and /pst
# slash commands into ~/.claude/commands/ so they work in any Claude Code
# session. Re-running is safe (idempotent).
#
# Usage:
#   ./install.sh
#   curl -fsSL https://raw.githubusercontent.com/jhammant/SmartClip/main/install.sh | sh
#
# Prefer the plugin install instead? See the README for `/plugin marketplace add`.

set -eu

# --- Resolve where this script lives (so curl-piped installs still work) ------
SRC_DIR=""
if [ -n "${BASH_SOURCE:-}" ]; then
  SRC_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE}")" && pwd)
elif [ -f "${0:-}" ] && [ "$(basename -- "${0:-}")" = "install.sh" ]; then
  SRC_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
fi

BIN_DIR="${SMARTCLIP_BIN_DIR:-$HOME/.local/bin}"
CMD_DIR="${SMARTCLIP_CMD_DIR:-$HOME/.claude/commands}"
RAW_BASE="https://raw.githubusercontent.com/jhammant/SmartClip/main"

say()  { printf '  %s\n' "$1"; }
ok()   { printf '  \033[32m✓\033[0m %s\n' "$1"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$1"; }

fetch() { # fetch <url> <dest>
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$1" -o "$2"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$2" "$1"
  else
    printf 'SmartClip: need curl or wget to download %s\n' "$1" >&2
    return 1
  fi
}

install_file() { # install_file <relative-path> <dest>
  rel="$1"; dest="$2"
  if [ -n "$SRC_DIR" ] && [ -f "$SRC_DIR/$rel" ]; then
    cp "$SRC_DIR/$rel" "$dest"
  else
    fetch "$RAW_BASE/$rel" "$dest"
  fi
}

printf '\n📋  Installing SmartClip…\n\n'

mkdir -p "$BIN_DIR" "$CMD_DIR"

install_file "bin/smartclip" "$BIN_DIR/smartclip"
chmod +x "$BIN_DIR/smartclip"
ok "helper installed → $BIN_DIR/smartclip"

install_file "commands/clp.md" "$CMD_DIR/clp.md"
install_file "commands/pst.md" "$CMD_DIR/pst.md"
ok "commands installed → $CMD_DIR/{clp,pst}.md"

# --- PATH check ---------------------------------------------------------------
case ":${PATH}:" in
  *":$BIN_DIR:"*) ok "$BIN_DIR is already on your PATH" ;;
  *)
    warn "$BIN_DIR is not on your PATH yet. Add this to your shell rc:"
    printf '\n      export PATH="%s:$PATH"\n\n' "$BIN_DIR"
    ;;
esac

# --- Clipboard backend check --------------------------------------------------
if command -v pbcopy >/dev/null 2>&1 || command -v wl-copy >/dev/null 2>&1 \
   || command -v xclip >/dev/null 2>&1 || command -v xsel >/dev/null 2>&1 \
   || command -v clip.exe >/dev/null 2>&1 || command -v clip >/dev/null 2>&1 \
   || command -v termux-clipboard-set >/dev/null 2>&1; then
  ok "a clipboard backend is available"
else
  warn "no clipboard tool found — install wl-clipboard, xclip, or xsel (Linux)."
fi

printf '\n✅  Done. Restart Claude Code, then try:\n'
printf '      \033[1m/clp\033[0m   after generating something  (smart copy)\n'
printf '      \033[1m/pst\033[0m   with something on your clipboard  (smart paste)\n\n'
