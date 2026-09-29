#!/bin/bash
# Agent Chrome kit installer (macOS). Safe to run again: it updates in place.
#
#   ./install.sh               Agent Chrome + the agent-chrome skill for Claude Code and Codex
#   ./install.sh --with-jev    also set up jev-drive (asks for your Jev key and, optionally, an OpenAI key)
#   ./install.sh --no-start    install everything but do not start Agent Chrome or add it to login items
#   --agent sol6|sonnet55      which model drives the browser for signed-in work (default: sol6 = Codex GPT-6 Sol)
#   --takeover sol6|sonnet55   which model takes Jev's uncertain steps in jev-drive (default: sol6)
#   Without these flags a first install asks; an update keeps the current choice.
#
# What it does, in order:
#   1. checks macOS, Homebrew, Node/npm and python3
#   2. installs Google Chrome Beta (its own app, separate from your everyday Chrome) and checks Google's signature
#   3. installs playwright-cli, which agents use to attach to Chrome Beta
#   4. installs the skill into ~/.local/share/agent-chrome and links it for Claude Code, Codex and other agents
#   5. adds a Codex "browser" profile (gpt-6-sol, medium effort)
#   6. starts Agent Chrome at login (LaunchAgent) and runs the health check
# Keys you type are stored only in your macOS Keychain. Nothing is sent anywhere by this script.
set -euo pipefail

KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="$HOME/.local/share/agent-chrome"
PLAYWRIGHT_CLI_VERSION="0.1.18"
WITH_JEV=0
START=1
AGENT=""
TAKEOVER=""
while [ $# -gt 0 ]; do
  arg="$1"; shift
  case "$arg" in
    --with-jev) WITH_JEV=1 ;;
    --no-start) START=0 ;;
    --agent) AGENT="${1:-}"; shift ;;
    --takeover) TAKEOVER="${1:-}"; shift ;;
    -h|--help) sed -n '2,19p' "$0"; exit 0 ;;
    *) echo "Unknown option: $arg" >&2; exit 2 ;;
  esac
done
for v in "$AGENT" "$TAKEOVER"; do
  case "$v" in ""|sol6|sonnet55) ;; *) echo "Model must be sol6 or sonnet55, not: $v" >&2; exit 2 ;; esac
done

say() { printf '\n==> %s\n' "$*"; }
fail() { printf '\nSTOPPED: %s\n' "$*" >&2; exit 1; }

say "1/6 Checking this Mac"
[ "$(uname -s)" = "Darwin" ] || fail "This kit is for macOS."
[ "$(id -u)" -ne 0 ] || fail "Run it as yourself, not with sudo."
if ! command -v brew >/dev/null 2>&1; then
  for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do [ -x "$b" ] && eval "$("$b" shellenv)"; done
fi
command -v brew >/dev/null 2>&1 || fail "Homebrew is required. Install it from https://brew.sh, then run this again."
command -v npm >/dev/null 2>&1 || { echo "Installing Node.js (for playwright-cli)"; brew install node; }
command -v python3 >/dev/null 2>&1 || fail "python3 is missing. Run: xcode-select --install"
others=$(dscl . -list /Users UniqueID | awk '$2 >= 501 {print $1}' | grep -v -x "$(id -un)" || true)
if [ -n "$others" ]; then
  echo "WARNING: this Mac has other user accounts ($(echo $others | tr '\n' ' ')). Chrome's debugging port has no password,"
  echo "so do not sign in to anything in Agent Chrome until your provider sets up port isolation for this Mac."
fi

say "2/6 Google Chrome Beta"
APP=""
for a in "/Applications/Google Chrome Beta.app" "$HOME/Applications/Google Chrome Beta.app"; do [ -d "$a" ] && APP="$a" && break; done
if [ -z "$APP" ]; then
  brew install --cask google-chrome@beta
  APP="/Applications/Google Chrome Beta.app"
fi
# Not --strict: Chrome's own updater leaves extended attributes that --strict rejects. Check Google's team ID instead.
codesign --verify --deep "$APP" || fail "Chrome Beta's signature did not verify; not continuing."
[ "$(codesign -dv "$APP" 2>&1 | sed -n 's/^TeamIdentifier=//p')" = "EQHXZ8M8AV" ] || fail "Chrome Beta is not signed by Google; not continuing."
spctl --assess --type execute "$APP" 2>/dev/null || fail "Chrome Beta is not notarized by Apple; not continuing."
echo "Chrome Beta $(defaults read "$APP/Contents/Info" CFBundleShortVersionString) verified"

say "3/6 playwright-cli"
if ! npm ls -g "@playwright/cli@$PLAYWRIGHT_CLI_VERSION" >/dev/null 2>&1; then
  npm install -g "@playwright/cli@$PLAYWRIGHT_CLI_VERSION"
fi
command -v playwright-cli >/dev/null 2>&1 || fail "playwright-cli is not on PATH after install; open a new Terminal and run this again."

say "4/6 The agent-chrome skill"
mkdir -p "$HOME/.local/share"
rm -rf "$DEST.new"
cp -R "$KIT/skill" "$DEST.new"
chmod 0755 "$DEST.new/bin/agent-chrome" "$DEST.new/bin/jev-drive"
if [ -f "$DEST/config/jev-public-hosts.json" ]; then  # keep the owner's own public-site list on updates
  cp "$DEST/config/jev-public-hosts.json" "$DEST.new/config/jev-public-hosts.json"
fi
# Model choice (config/models.json): flags win, then the current install's choice, then ask, then GPT-6 Sol.
current_agent=""; current_takeover=""
if [ -f "$DEST/config/models.json" ]; then
  current_agent=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("browser_agent",""))' "$DEST/config/models.json" 2>/dev/null || true)
  current_takeover=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("jev_takeover_model",""))' "$DEST/config/models.json" 2>/dev/null || true)
fi
pick() {  # $1 flag value, $2 current value in models.json form, $3 question
  if [ -n "$1" ]; then echo "$1"; return; fi
  case "$2" in *sonnet*) echo sonnet55; return ;; *sol*) echo sol6; return ;; esac
  if [ -t 0 ]; then
    read -r -p "$3 [1] GPT-6 Sol (recommended: exact every time, about half the cost)  [2] Claude Sonnet 5.5 (exact, about twice as fast): " n </dev/tty
    [ "$n" = "2" ] && echo sonnet55 || echo sol6
  else
    echo sol6
  fi
}
AGENT=$(pick "$AGENT" "$current_agent" "Browser agent for signed-in work?")
TAKEOVER=$(pick "$TAKEOVER" "$current_takeover" "jev-drive takeover model?")
python3 - "$DEST.new/config/models.json" "$AGENT" "$TAKEOVER" <<'PY'
import json, sys
path, agent, takeover = sys.argv[1:]
data = json.load(open(path))
data["browser_agent"] = {"sol6": "codex-gpt-6-sol", "sonnet55": "claude-sonnet-5-5"}[agent]
data["jev_takeover_model"] = {"sol6": "gpt-6-sol", "sonnet55": "claude-sonnet-5-5"}[takeover]
json.dump(data, open(path, "w"), indent=2)
open(path, "a").write("\n")
PY
echo "browser agent: $AGENT, jev-drive takeover: $TAKEOVER (change with ./install.sh --agent ... --takeover ...)"
rm -rf "$DEST.old"; [ -e "$DEST" ] && mv "$DEST" "$DEST.old"
mv "$DEST.new" "$DEST"; rm -rf "$DEST.old"
for d in "$HOME/.claude/skills" "$HOME/.codex/skills" "$HOME/.agents/skills"; do
  mkdir -p "$d"
  if [ -e "$d/agent-chrome" ] && [ ! -L "$d/agent-chrome" ]; then
    mv "$d/agent-chrome" "$d/agent-chrome.backup-$(date +%Y%m%d%H%M%S)"
  fi
  ln -sfn "$DEST" "$d/agent-chrome"
done
echo "skill linked into ~/.claude/skills, ~/.codex/skills and ~/.agents/skills"

say "5/6 Codex browser profile"
mkdir -p "$HOME/.codex"
TD=$(getconf DARWIN_USER_TEMP_DIR 2>/dev/null || echo "${TMPDIR:-/tmp}"); TD=${TD%/}
mkdir -p "$HOME/.cache/uv" "$HOME/.local/share/uv" "$HOME/.config/browser-harness"
cat > "$HOME/.codex/browser.config.toml" <<TOML
# Agent Chrome kit: Codex profile for browser work (codex -p browser). Benchmarked 2026-09-27/28: gpt-6-sol was the
# cheapest model that picked the exact product every time. See the agent-chrome skill, section 1a.
model = "gpt-6-sol"
model_reasoning_effort = "medium"
# Agent Chrome needs loopback access to Chrome (network on) and writes its lock, session and helper folders.
# Scoped to this opt-in profile only; your normal Codex settings are unchanged.
sandbox_mode = "workspace-write"

[sandbox_workspace_write]
network_access = true
writable_roots = [
  "$HOME/Library/Application Support/AgentChrome",
  "$HOME/Library/Caches/agent-chrome",
  "$HOME/Library/Caches/ms-playwright",
  "$TD",
  "$HOME/.cache/uv",
  "$HOME/.local/share/uv",
  "$HOME/.config/browser-harness",
]
TOML
if command -v codex >/dev/null 2>&1; then
  echo "Codex $(codex --version 2>/dev/null | awk '{print $NF}') found; gpt-6-sol needs Codex 0.156 or later (npm install -g @openai/codex@latest)."
else
  echo "Codex is not installed. Claude Code works without it; for Codex run: npm install -g @openai/codex@latest"
fi

if [ "$WITH_JEV" = 1 ] && [ ! -t 0 ]; then
  say "Optional: jev-drive"
  command -v uv >/dev/null 2>&1 || brew install uv
  echo "Keys can only be typed in your own Terminal window. Open Terminal in this folder and run:"
  echo "    ./install.sh --with-jev"
  echo "It keeps everything else as it is and only asks for the keys."
elif [ "$WITH_JEV" = 1 ]; then
  say "Optional: jev-drive"
  command -v uv >/dev/null 2>&1 || brew install uv
  echo "Paste your Jev (TypeSafe) API key when asked. It goes straight into your Keychain and is not shown."
  security add-generic-password -U -s agent-chrome.typesafe -a "$USER" -w
  read -r -p "Store an OpenAI API key for faster takeovers? Without one, jev-drive uses Codex on your ChatGPT sign-in. [y/N] " yn
  if [ "${yn:-n}" = "y" ] || [ "${yn:-n}" = "Y" ]; then
    echo "Paste your OpenAI API key when asked. It is not shown."
    security add-generic-password -U -s agent-chrome.openai -a "$USER" -w
  fi
fi

AC="$DEST/bin/agent-chrome"
if [ "$START" = 0 ]; then
  echo "Installed without starting (--no-start). Start later with: $AC install-launchagent && $AC up"
  exit 0
fi
say "6/6 Start at login and health check"
"$AC" install-launchagent
"$AC" up --json >/dev/null
"$AC" doctor || true

cat <<EOF

Done. Next:
  1. In the Chrome Beta window that opened, sign in to the sites you want your agents to use.
     This is a separate browser from your everyday Chrome. Do not turn on Chrome sync in it.
  2. In Claude Code, type /agent-chrome, or just ask: "use Agent Chrome to check my orders on <site>".
     In Codex, run: codex -p browser, then ask the same way.
  3. Health check any time: $AC doctor
EOF
