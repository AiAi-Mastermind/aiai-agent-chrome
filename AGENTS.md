# Agent Chrome kit: instructions for AI agents

## What this is

- This kit gives Claude Code and Codex one shared, separate browser (Chrome Beta) that the owner signs in to once.
- It installs the `agent-chrome` skill, a launcher, a Codex `browser` profile, and an optional add-on called `jev-drive` for fast lookups on public sites.
- The person you are helping is a business owner, not an engineer. Use plain words. Do the technical work yourself. Stop only for the OWNER steps below.
- macOS only. Windows is not supported yet (a Windows edition is planned).
- Do not run `build-kit.sh`. It is a maintainer script that needs a private source repo.

## Rules (read first, follow always)

1. Never ask the owner to paste a key or password into chat. Keys go only into the installer's Keychain prompt.
2. Never read Keychain values. Checking that an item exists is fine (`security find-generic-password -s NAME -a "$USER"` without `-w`).
3. Never add account sites (email, banking, insurance carriers, CRMs, schools, government) to `jev-public-hosts.json`.
4. If the Mac has other user accounts, do not sign in to anything in Agent Chrome. Chrome's debugging port has no password.
5. Stop at sign-in, 2FA and captcha screens. Tell the owner which site needs them.
6. No purchases, cart changes, subscription changes or account changes unless the owner asks in that request.
7. Never close the shared browser. Use `detach`, never `agent-chrome down`, unless the owner asks you to stop it.
8. Only use tabs you opened yourself.

## Before you start

Run these. Fix anything that fails before continuing.

```bash
uname -s                                   # must print Darwin
id -un; id -u                              # uid must not be 0 (do not use sudo)
command -v brew || ls /opt/homebrew/bin/brew /usr/local/bin/brew
command -v python3 node npm
command -v codex && codex --version        # optional; GPT-6 Sol needs 0.156 or later
command -v claude                          # optional; Claude Code
ls "/Applications/Google Chrome Beta.app" 2>/dev/null
lsof -nP -iTCP:9230 -sTCP:LISTEN           # empty is fine; something else on 9230 needs a look
ls ~/.local/share/agent-chrome 2>/dev/null # exists means this is an update, not a first install
```

The owner needs at least one of Codex (signed in with ChatGPT) or Claude Code (signed in).

## Setup, step by step

1. Ask the owner two things, in plain words: which browser agent they want and, if they want jev-drive, which takeover model. Use "Choosing models" below. If they have no preference, choose GPT-6 Sol for both.
2. If Homebrew is missing, tell the owner. **OWNER step:** they install it from https://brew.sh (it asks for their password). Then continue.
3. If Codex is missing or older than 0.156 and the owner chose Sol: `npm install -g @openai/codex@latest`. **OWNER step:** if `codex` asks to sign in, the owner signs in with ChatGPT.
4. If the owner chose Sonnet 5.5, confirm Claude Code is installed (`claude --version`). **OWNER step:** if it is not signed in, the owner runs `claude` and signs in.
5. From this folder, run the installer with the models the owner chose:
   ```bash
   ./install.sh --agent sol6 --takeover sol6             # or sonnet55 for either
   ```
   For jev-drive, the keys must be typed by the owner in their own Terminal, because your shell has no keyboard. **OWNER step:** ask the owner to open Terminal in this folder and run `./install.sh --with-jev`. It keeps your model choice and only adds the keys.
   Add `--no-start` only if the owner does not want Agent Chrome to start now or at login.
6. **OWNER steps during install:** a Homebrew or macOS password prompt, Touch ID, permission dialogs, and (with `--with-jev`) the Keychain prompts for the keys. The owner types these themselves. You never see them.
7. When Chrome Beta opens, **OWNER step:** the owner signs in to the sites they want agents to use. Do not turn on Chrome sync. Do not install a password manager extension.
8. Run `./test-kit.sh` (see "Verify"). Do not tell the owner it works until it prints no FAIL.
9. Tell the owner, in three lines: how to use it ("ask me to use Agent Chrome to check ..."), that you will stop at sign-in screens, and that `./install.sh` can be re-run any time to repair it.

## Choosing models

Two separate choices. Numbers come from `docs/BENCHMARKS.md` (tests on 27-28 Sep 2026).

| Choice | GPT-6 Sol (Codex) | Sonnet 5.5 (Claude Code) |
|---|---|---|
| Browser agent (signed-in work) | Exact product 3/3, about half the cost | Exact product 3/3, about twice as fast |
| jev-drive takeover | 24/24 tasks, about $0.03 per task | 21/24 (missed the colour test 3 of 3), about $0.06 per task |

- Recommend GPT-6 Sol for the jev-drive takeover.
- Either model is fine as browser agent. Pick the one whose app the owner already uses.
- GPT-6 Sol needs Codex CLI 0.156 or later, signed in with ChatGPT.
- Sonnet 5.5 needs Claude Code signed in. The model id is `claude-sonnet-5-5`.
- The choice is stored in `~/.local/share/agent-chrome/config/models.json`: `browser_agent` is `codex-gpt-6-sol` or `claude-sonnet-5-5`; `jev_takeover_model` is `gpt-6-sol` or `claude-sonnet-5-5`.
- To change it later, re-run `./install.sh --agent sol6|sonnet55 --takeover sol6|sonnet55`. An update with no model flags keeps the current choice.

## Optional: Jev (jev-drive)

jev-drive is fast navigation on public sites (Wikipedia and Amazon product pages to start). Skip it if the owner does not have a Jev (TypeSafe) key.

1. **OWNER step:** the owner opens Terminal in this folder and runs `./install.sh --with-jev`. It installs `uv` if needed.
2. **OWNER step:** the owner pastes the Jev key into the Keychain prompt, and optionally an OpenAI key at the second prompt. Never ask for either in chat. If you run `--with-jev` from your own shell, the installer only prints these instructions.
3. Without an OpenAI key, a Sol takeover uses `codex exec` on the ChatGPT sign-in: slower (about 45-70 seconds on the Amazon test), no key needed. With a Claude takeover it uses `claude -p` on the Claude sign-in.
   - **Codex users:** inside Codex's own sandbox (`codex -p browser`), a second `codex exec` cannot start. jev-drive then fails with "codex backend gave no answer". Fix: the owner adds an OpenAI key (step 2), or run jev-drive from Claude Code or a normal Terminal. Claude Code users are not affected.
4. Check the key exists without reading it: `security find-generic-password -s agent-chrome.typesafe -a "$USER" >/dev/null && echo present`.
5. `./test-kit.sh` runs a Wikipedia task when the key exists.
6. jev-drive prints one JSON object. `status` is one of done, blocked, signin_needed, left_public_sites, needs_approval, not_configured, error. Exit codes: 0 done, 3 stopped short, 4 refused or not configured, 5 error. `JEV_DRIVE_DEBUG=1` prints one line per step on stderr.
7. jev-drive sends each page's visible text to TypeSafe and the takeover model. Only public sites go in `~/.local/share/agent-chrome/config/jev-public-hosts.json`. Refuse any request to add an account site.

## Verify

```bash
./test-kit.sh            # normal check, about 1-3 minutes
./test-kit.sh --full     # also runs the Amazon "teal acoustic panels" test; run it once
```

`--skip-links` skips the symlink check. `KIT_SKILL_DIR=<folder>` tests a different skill folder.

PASS looks like this: every line starts with PASS or SKIP, and the last line reads `N passed, 0 failed, N skipped`. SKIP for the Jev tests is normal when Jev is not installed. The script changes nothing and never prints secrets.

| FAIL line starts with | What to do |
|---|---|
| files | Re-run `./install.sh`. |
| symlinks | Re-run `./install.sh`. It relinks `~/.claude/skills`, `~/.codex/skills`, `~/.agents/skills`. |
| models.json | Re-run `./install.sh --agent ... --takeover ...` to rewrite it. |
| codex | `npm install -g @openai/codex@latest`; owner signs in with ChatGPT if asked. |
| claude | Owner installs Claude Code and signs in, or switch to Sol with the installer flags. |
| doctor | Run `~/.local/share/agent-chrome/bin/agent-chrome doctor`. Fix the lines that start with FAIL. WARN lines are advice only. |
| status | Run `agent-chrome up`, then re-test. |
| endpoint | Run `agent-chrome endpoint`. Expect `http://127.0.0.1:<port>`. Anything else: re-run `./install.sh`. |
| browser cycle | Run `doctor`. Check Chrome Beta is open. The test always detaches at the end. |
| guard | Re-run `./install.sh` (the launcher may be modified or out of date). |
| jev-drive refusal | Re-run `./install.sh --with-jev`. |
| jev-drive Wikipedia or Amazon | See the troubleshooting table. |

## Troubleshooting

`AC=~/.local/share/agent-chrome/bin/agent-chrome`

| Problem | What to do |
|---|---|
| Homebrew missing | Owner installs from https://brew.sh (password needed). Open a new Terminal, then re-run `./install.sh`. |
| Chrome Beta signature check fails | Stop. Run `brew reinstall --cask google-chrome@beta`, then `./install.sh`. If it fails again, tell the owner and stop. Never bypass the check. |
| Port 9230 busy or another Chrome is on it | Run `lsof -nP -iTCP:9230 -sTCP:LISTEN` and `$AC status`. If it is Agent Chrome, nothing to fix. If another program owns it, tell the owner; do not kill it. Launcher exit 4 means conflict, 5 means launch or CDP failure. |
| Codex too old or not signed in | `npm install -g @openai/codex@latest`. Owner runs `codex` and signs in with ChatGPT. Check `codex --version` is 0.156 or later. |
| Claude Code not signed in | Owner runs `claude` and signs in. Model id is `claude-sonnet-5-5`. |
| Agent Chrome not running (exit 3) | `$AC up`, then `$AC doctor`. |
| jev-drive `not_configured` | Either the start page is not on the public-site list (expected for account pages), or no Jev key exists. Check with `security find-generic-password -s agent-chrome.typesafe -a "$USER" >/dev/null && echo present`. If missing, run `./install.sh --with-jev`. |
| jev-drive `signin_needed` | Owner signs in inside Chrome Beta, or use a page that needs no sign-in. |
| jev-drive `blocked` at the 180 s limit | Rerun with `JEV_DRIVE_DEBUG=1 ~/.local/share/agent-chrome/bin/jev-drive <url> "<goal>"`. Copy the stderr lines and report them to the person who supplied the kit. Do not change limits yourself. |
| `uv` missing | `brew install uv`, or re-run `./install.sh --with-jev`. |
| jev-drive "codex backend gave no answer" inside `codex -p browser` | Expected: Codex can't nest its sandbox. Owner adds an OpenAI key with `./install.sh --with-jev`, or run jev-drive from Claude Code or a normal Terminal. |
| "Failed to initialize cache at ~/.cache/uv" inside Codex | Re-run `./install.sh` to rewrite the Codex browser profile with the jev-drive folders. |
| `playwright-cli` not found | Open a new Terminal and re-run `./install.sh`. |
| `eval` refused (exit 4) | The guard is working. Do not try to bypass it. |

## Repair, reinstall, uninstall

- **Repair or update:** re-run `./install.sh` (add model flags only if the owner wants to change them). It updates in place and keeps sign-ins, the public-site list and the model choice. Then run `./test-kit.sh`.
- **Reinstall from scratch, keeping sign-ins:** `./uninstall.sh`, then `./install.sh`.
- **Uninstall:** `./uninstall.sh` removes the skill, its links and the login item. It keeps the owner's sign-ins and Chrome Beta.
- **Uninstall and delete sign-ins and kit Keychain items:** `./uninstall.sh --purge`. Ask the owner first. This cannot be undone.
- To remove Chrome Beta as well: `brew uninstall --cask google-chrome@beta`.
- Health check any time: `~/.local/share/agent-chrome/bin/agent-chrome doctor`.

## Where things are

- Skill: `~/.local/share/agent-chrome`, linked from `~/.claude/skills/agent-chrome`, `~/.codex/skills/agent-chrome`, `~/.agents/skills/agent-chrome`.
- Launcher: `~/.local/share/agent-chrome/bin/agent-chrome`. jev-drive is next to it.
- Agent Chrome listens on `http://127.0.0.1:9230` (`agent-chrome endpoint`).
- Keychain items: `agent-chrome.typesafe` (Jev key), `agent-chrome.openai` (optional). Account is the login name.
- Launcher exit codes: 0 ok, 1 doctor failure, 2 usage, 3 not running, 4 refusal or conflict, 5 launch or CDP failure.
- Browser use, once installed: read `~/.local/share/agent-chrome/SKILL.md`. Session names are lowercase, `^[a-z0-9][a-z0-9-]{0,40}$`. Cycle: `attach <session>`, `pw <session> tab-new <url>`, `pw <session> snapshot`, `pw <session> tab-close`, `pw <session> detach`.
