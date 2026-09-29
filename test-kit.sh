#!/bin/bash
# Agent Chrome kit acceptance test. Read-only: it changes no settings and prints no secrets.
#   ./test-kit.sh              run every check
#   ./test-kit.sh --skip-links skip the symlink check (use when testing a skill folder that is not installed)
#   ./test-kit.sh --full       also run the longer Amazon "teal acoustic panels" jev-drive test
# KIT_SKILL_DIR overrides the skill folder (default ~/.local/share/agent-chrome).
# Exit 0 if nothing failed, 1 if anything failed.

SKILL="${KIT_SKILL_DIR:-$HOME/.local/share/agent-chrome}"
SKIP_LINKS=0
FULL=0
for arg in "$@"; do
  case "$arg" in
    --skip-links) SKIP_LINKS=1 ;;
    --full) FULL=1 ;;
    -h|--help) sed -n '2,7p' "$0"; exit 0 ;;
    *) echo "Unknown option: $arg" >&2; exit 2 ;;
  esac
done

AC="$SKILL/bin/agent-chrome"
JD="$SKILL/bin/jev-drive"
SESSION="kit-test"
PASS=0; FAIL=0; SKIP=0
TMP="$(mktemp -d "${TMPDIR:-/tmp}/kit-test.XXXXXX")"
ATTACHED=0

pass() { PASS=$((PASS+1)); printf 'PASS  %s\n' "$*"; }
fail() { FAIL=$((FAIL+1)); printf 'FAIL  %s\n' "$*"; }
skip() { SKIP=$((SKIP+1)); printf 'SKIP  %s\n' "$*"; }

cleanup() {
  if [ "$ATTACHED" = 1 ] && [ -x "$AC" ]; then
    "$AC" pw "$SESSION" tab-close >/dev/null 2>&1 || true
    "$AC" pw "$SESSION" detach >/dev/null 2>&1 || true
  fi
  rm -rf "$TMP"
}
trap cleanup EXIT
trap 'exit 130' INT TERM

# Run a command with a time limit (bash 3.2, no coreutils timeout). Output goes to $1, exit code is returned.
run_limited() {  # $1 out file, $2 seconds, rest command
  local out="$1" secs="$2"; shift 2
  "$@" >"$out" 2>"$out.err" </dev/null &
  local pid=$! n=0
  while kill -0 "$pid" 2>/dev/null; do
    if [ "$n" -ge "$secs" ]; then kill "$pid" 2>/dev/null; sleep 1; kill -9 "$pid" 2>/dev/null; wait "$pid" 2>/dev/null; return 124; fi
    sleep 1; n=$((n+1))
  done
  wait "$pid"
}

json_get() {  # $1 file, $2 key ; prints the value or nothing
  python3 - "$1" "$2" <<'PY' 2>/dev/null
import json, sys
try:
    text = open(sys.argv[1]).read()
    start = text.find("{")
    data = json.loads(text[start:]) if start >= 0 else {}
    v = data.get(sys.argv[2], "")
    print("" if v is None else v)
except Exception:
    pass
PY
}

keychain_has() { security find-generic-password -s "$1" -a "$USER" >/dev/null 2>&1; }

echo "Agent Chrome kit test. Skill folder: $SKILL"

# 1. Files
missing=""
for f in SKILL.md bin/agent-chrome bin/jev-drive config/models.json config/jev-public-hosts.json config/profiles.json; do
  [ -f "$SKILL/$f" ] || missing="$missing $f"
done
for f in bin/agent-chrome bin/jev-drive; do
  [ -f "$SKILL/$f" ] && [ ! -x "$SKILL/$f" ] && missing="$missing $f(not-executable)"
done
if [ -z "$missing" ]; then pass "files: all present, launchers executable"; else fail "files: problem with$missing"; fi

# 2. Symlinks
if [ "$SKIP_LINKS" = 1 ]; then
  skip "symlinks: skipped by --skip-links"
else
  want="$(cd "$SKILL" 2>/dev/null && pwd -P)"; bad=""
  for d in "$HOME/.claude/skills" "$HOME/.codex/skills" "$HOME/.agents/skills"; do
    l="$d/agent-chrome"
    if [ ! -L "$l" ]; then bad="$bad $l(not-a-link)"; continue; fi
    got="$(cd "$l" 2>/dev/null && pwd -P)"
    [ "$got" = "$want" ] || bad="$bad $l(points-elsewhere)"
  done
  if [ -z "$bad" ]; then pass "symlinks: Claude, Codex and .agents links point to the skill"; else fail "symlinks:$bad"; fi
fi

# 3. models.json
BROWSER=""; TAKEOVER=""
if [ -f "$SKILL/config/models.json" ]; then
  mres="$(python3 - "$SKILL/config/models.json" <<'PY' 2>&1
import json, sys
try:
    d = json.load(open(sys.argv[1]))
except Exception as e:
    print("INVALID invalid JSON"); sys.exit()
b, t = d.get("browser_agent", ""), d.get("jev_takeover_model", "")
if b not in ("codex-gpt-6-sol", "claude-sonnet-5-5"):
    print("INVALID browser_agent is %r" % b); sys.exit()
if t not in ("gpt-6-sol", "claude-sonnet-5-5"):
    print("INVALID jev_takeover_model is %r" % t); sys.exit()
print("OK %s %s" % (b, t))
PY
)"
  case "$mres" in
    OK\ *) set -- $mres; BROWSER="$2"; TAKEOVER="$3"; pass "models.json: valid (browser_agent=$BROWSER, jev_takeover_model=$TAKEOVER)" ;;
    *) fail "models.json: ${mres#INVALID }" ;;
  esac
else
  fail "models.json: file missing"
fi

# 4. Model CLIs
need_codex=0; need_claude=0
case "$BROWSER" in codex-*) need_codex=1 ;; claude-*) need_claude=1 ;; esac
if [ "$TAKEOVER" = "gpt-6-sol" ] && ! keychain_has agent-chrome.openai; then need_codex=1; fi
case "$TAKEOVER" in claude-*) need_claude=1 ;; esac
if [ -z "$BROWSER" ]; then
  skip "model CLIs: models.json unusable"
else
  if [ "$need_codex" = 1 ]; then
    if command -v codex >/dev/null 2>&1; then
      cv="$(codex --version 2>/dev/null | grep -Eo '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1)"
      ok="$(python3 -c 'import sys; v=[int(x) for x in sys.argv[1].split(".")]+[0,0]; print("yes" if v[:2]>=[0,156] else "no")' "${cv:-0}" 2>/dev/null)"
      if [ "$ok" = "yes" ]; then pass "codex: version $cv (needs 0.156 or later)"; else fail "codex: version ${cv:-unknown} is too old; run: npm install -g @openai/codex@latest"; fi
    else
      fail "codex: not installed; run: npm install -g @openai/codex@latest"
    fi
  else
    skip "codex: the chosen models do not need it"
  fi
  if [ "$need_claude" = 1 ]; then
    if command -v claude >/dev/null 2>&1; then pass "claude: Claude Code is installed"; else fail "claude: Claude Code is not installed"; fi
  else
    skip "claude: the chosen models do not need it"
  fi
fi

# 5-6. doctor, status
if [ -x "$AC" ]; then
  run_limited "$TMP/doctor" 90 "$AC" doctor; rc=$?
  if [ "$rc" = 0 ]; then pass "doctor: exit 0"; else fail "doctor: exit $rc (run: $AC doctor)"; fi
  run_limited "$TMP/status" 30 "$AC" status; rc=$?
  if [ "$rc" = 0 ]; then pass "status: exit 0, Agent Chrome is running"; else fail "status: exit $rc (3 means not running; run: $AC up)"; fi
  # 7. endpoint
  ep="$("$AC" endpoint 2>/dev/null </dev/null)"
  case "$ep" in
    http://127.0.0.1:[0-9]*) pass "endpoint: $ep" ;;
    *) fail "endpoint: expected http://127.0.0.1:<port>, got '$ep'" ;;
  esac
else
  fail "doctor: launcher missing"; fail "status: launcher missing"; fail "endpoint: launcher missing"
fi

# 8. Browser cycle
if [ -x "$AC" ]; then
  cyc=""
  run_limited "$TMP/attach" 60 "$AC" attach "$SESSION"; rc=$?
  if [ "$rc" = 0 ]; then ATTACHED=1; else ATTACHED=1; cyc="attach exit $rc"; fi
  if [ -z "$cyc" ]; then
    run_limited "$TMP/tabnew" 60 "$AC" pw "$SESSION" tab-new https://example.com/; rc=$?
    [ "$rc" = 0 ] || cyc="tab-new exit $rc"
  fi
  if [ -z "$cyc" ]; then
    run_limited "$TMP/snap" 60 "$AC" pw "$SESSION" snapshot; rc=$?
    if [ "$rc" != 0 ]; then cyc="snapshot exit $rc"
    elif ! grep -q "Example Domain" "$TMP/snap"; then cyc="snapshot did not contain 'Example Domain'"; fi
  fi
  if [ -z "$cyc" ]; then
    run_limited "$TMP/tabclose" 60 "$AC" pw "$SESSION" tab-close; rc=$?
    [ "$rc" = 0 ] || cyc="tab-close exit $rc"
  fi
  run_limited "$TMP/detach" 60 "$AC" pw "$SESSION" detach; drc=$?
  [ "$drc" = 0 ] && ATTACHED=0
  [ -z "$cyc" ] && [ "$drc" != 0 ] && cyc="detach exit $drc"
  if [ -z "$cyc" ]; then pass "browser cycle: attach, tab-new, snapshot (Example Domain), tab-close, detach"; else fail "browser cycle: $cyc"; fi

  # 9. eval refusal
  run_limited "$TMP/eval" 30 "$AC" pw "$SESSION" eval "1"; rc=$?
  if [ "$rc" = 4 ]; then pass "guard: eval refused with exit 4"; else fail "guard: eval should exit 4, got $rc"; fi
else
  fail "browser cycle: launcher missing"; fail "guard: launcher missing"
fi

# 10. jev-drive refusal of a non-public page
if [ -x "$JD" ]; then
  run_limited "$TMP/jd1" 60 "$JD" https://www.amazon.com/gp/css/order-history "open the page"; rc=$?
  st="$(json_get "$TMP/jd1" status)"
  if [ "$rc" = 4 ] && [ "$st" = "not_configured" ]; then pass "jev-drive refusal: order-history URL refused (exit 4, not_configured)"
  else fail "jev-drive refusal: expected exit 4 and not_configured, got exit $rc and status '${st:-none}'"; fi
else
  fail "jev-drive refusal: jev-drive missing"
fi

# 11. Wikipedia Mercury task
JEV_KEY=0
keychain_has agent-chrome.typesafe && JEV_KEY=1
keychain_has jevfabsol.typesafe-api-key && JEV_KEY=1
[ -n "${TYPESAFE_API_KEY:-}" ] && JEV_KEY=1
if [ "$JEV_KEY" = 1 ] && [ -x "$JD" ]; then
  run_limited "$TMP/jd2" 240 "$JD" https://en.wikipedia.org/wiki/Main_Page "Find and open the Wikipedia article about the planet Mercury (not the chemical element or the Roman god). Stop when that article is open."; rc=$?
  st="$(json_get "$TMP/jd2" status)"; ft="$(json_get "$TMP/jd2" final_title)"
  case "$ft" in
    "Mercury (planet)"*) if [ "$rc" = 0 ] && [ "$st" = "done" ]; then pass "jev-drive Wikipedia: opened '$ft'"; else fail "jev-drive Wikipedia: status '$st', exit $rc"; fi ;;
    *) fail "jev-drive Wikipedia: status '${st:-none}', exit $rc, title '${ft:-none}' (rerun with JEV_DRIVE_DEBUG=1)" ;;
  esac
else
  skip "jev-drive Wikipedia: no Jev key in Keychain (run ./install.sh --with-jev to add one)"
fi

# 12. Amazon teal task (only with --full)
if [ "$FULL" = 1 ]; then
  if [ "$JEV_KEY" = 1 ] && [ -x "$JD" ]; then
    run_limited "$TMP/jd3" 240 "$JD" https://www.amazon.com/ "Search Amazon for teal acoustic panels and open the product page of one acoustic panel result. Stop when a product page is open."; rc=$?
    st="$(json_get "$TMP/jd3" status)"; ft="$(json_get "$TMP/jd3" final_title)"
    lower="$(printf '%s' "$ft" | tr '[:upper:]' '[:lower:]')"
    if [ "$rc" = 0 ] && [ "$st" = "done" ] && printf '%s' "$lower" | grep -Eq 'teal|turquoise|aqua'; then
      pass "jev-drive Amazon teal: product title names the colour"
    else
      fail "jev-drive Amazon teal: status '${st:-none}', exit $rc, title lacks teal/turquoise/aqua or run stopped short"
    fi
  else
    skip "jev-drive Amazon teal: no Jev key in Keychain"
  fi
else
  skip "jev-drive Amazon teal: run with --full to include it"
fi

echo
echo "$PASS passed, $FAIL failed, $SKIP skipped"
[ "$FAIL" = 0 ] || exit 1
exit 0
