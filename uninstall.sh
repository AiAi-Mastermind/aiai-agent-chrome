#!/bin/bash
# Remove the Agent Chrome kit. Your Chrome Beta sign-ins are kept unless you add --purge.
#
#   ./uninstall.sh            stop Agent Chrome at login, remove the skill and its links
#   ./uninstall.sh --purge    also delete the Agent Chrome profile (all its sign-ins) and the kit's Keychain items
set -euo pipefail
PURGE=0
[ "${1:-}" = "--purge" ] && PURGE=1
DEST="$HOME/.local/share/agent-chrome"

if [ -x "$DEST/bin/agent-chrome" ]; then
  "$DEST/bin/agent-chrome" down >/dev/null 2>&1 || true
  "$DEST/bin/agent-chrome" uninstall-launchagent || true
fi
for d in "$HOME/.claude/skills" "$HOME/.codex/skills" "$HOME/.agents/skills"; do
  [ -L "$d/agent-chrome" ] && rm "$d/agent-chrome"
done
rm -rf "$DEST"
echo "Removed the skill and the login item. Chrome Beta itself is still installed (brew uninstall --cask google-chrome@beta)."

if [ "$PURGE" = 1 ]; then
  rm -rf "$HOME/Library/Application Support/AgentChrome" "$HOME/Library/Caches/agent-chrome" "$HOME/Library/Logs/agent-chrome"
  security delete-generic-password -s agent-chrome.typesafe -a "$USER" >/dev/null 2>&1 || true
  security delete-generic-password -s agent-chrome.openai -a "$USER" >/dev/null 2>&1 || true
  echo "Deleted the Agent Chrome profile (its sign-ins) and the kit's Keychain items."
fi
