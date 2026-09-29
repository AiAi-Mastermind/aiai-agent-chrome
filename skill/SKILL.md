---
name: agent-chrome
description: The one browser AI agents use on this Mac for anything that needs a signed-in account or a real browser session - online stores, CRMs, carrier and admin portals, order history, or any "log in and check" task. Agent Chrome is a dedicated, persistent Chrome Beta profile that the owner signs in to once; Claude Code and Codex attach to it with playwright-cli. Also provides jev-drive, fast navigation on public sites (Jev with GPT-6 Sol taking over uncertain steps). Use it instead of launching Chrome, Chromium or Playwright browsers, and instead of the owner's everyday Chrome. Triggers on "log in", "signed in", "my account", "order history", "find on Amazon", "look up on Wikipedia", "in the browser", "use the browser", "browser automation".
---

# Agent Chrome

## 1. The rule

Route signed-in browser work through Agent Chrome. Never launch another Chrome, Chromium, or Playwright browser for it. Never drive the owner's personal Chrome profiles or Arc unless they name them in the request. For public, unauthenticated page checks, such as local dev-server screenshots or rendering, a throwaway headless browser is still allowed.

This wrapper is a guardrail against accidental misuse by cooperative agents (closing the shared browser, leaking cookies into transcripts, or driving tabs they did not open), not a sandbox against a malicious local process, which could bypass it with raw CDP; bypassing it is forbidden below.

## 1a. Which tool drives the browser (benchmarked 2026-09-27 and 2026-09-28)

Pick by the kind of page:

| Task | Use | Why |
|---|---|---|
| **Public site** on the Jev list (`config/jev-public-hosts.json`): search, find, open the right item | **`jev-drive`**: Jev + GPT-6 Sol taking over below 0.93 (section 1b) | 24/24 tasks, including the colour, brand and size traps; about 5–30 s and $0.03 per task |
| **Signed-in account pages** (orders, admin consoles, anything personal) and every site not on the Jev list | **Codex `gpt-6-sol`, medium effort**, driving `agent-chrome` itself | 7/7 both days, exact product 3/3; $1.21 for 7 tasks. Never send account pages to Jev |
| Quick attended check from Claude Code | **Sonnet 5.5** driving `agent-chrome` itself | 7/7, exact product 3/3, the fastest agent (224 s for 7 tasks) but about twice Sol's cost |

- Codex headless: `codex exec -m gpt-6-sol -c model_reasoning_effort=medium ...`; interactive: `codex -p browser`. Needs Codex CLI 0.156 or later.
- **Do not use** `gpt-6-luna` as a browser agent: it is 20× cheaper than Sol but took the wrong colour 2 of 3 times. **Do not use** `gpt-6-astra`: slowest and most expensive, no gain. **Do not use** Sonnet 5.5 as the jev-drive takeover model: 21/24, wrong colour 3 of 3, twice Sol's price.
- **Do not** let Jev run to the end and check afterwards: the checking agent accepted Jev's wrong pick 3 of 3 times. The step-by-step 0.93 gate in `jev-drive` is what works.
- The full benchmark is in this kit's `docs/BENCHMARKS.md`.

## 1b. jev-drive: fast navigation on public sites

```bash
JD="$(dirname "$AC")/jev-drive"      # AC from section 2
"$JD" "https://www.amazon.com/" "Search Amazon for teal acoustic panels and open the product page of a teal one. Stop when a product page is open."
```

It prints one JSON object: `status` (`done`, `blocked`, `signin_needed`, `left_public_sites`, `needs_approval`, `not_configured`, `error`), `final_url`, `final_title`, and the steps with who chose each (`jev` or `takeover`). Jev works in its own background tab and closes it. To read the result, open `final_url` in your own `agent-chrome` tab (section 2). Any status other than `done` means: finish the task yourself with Codex `gpt-6-sol` and `agent-chrome`, or stop and ask the owner for `signin_needed` and `needs_approval`.

How it works: Jev picks each step in about 0.1 s and reports a confidence for the kind of step. Below 0.93, GPT-6 Sol picks that step instead from the same choices. The 0.93 cutoff caught every one of Jev's mistakes in testing; Jev's per-click score is not a usable gate.

Guardrails it enforces, which you must not work around:
- **Public sites only.** The start page and every page Jev sees must be on `config/jev-public-hosts.json`. Jev (TypeSafe) and the takeover model both receive each page's visible text. Never add account sites (banking, email, insurance carriers, CRMs, schools, government). `JEV_DRIVE_EXTRA_HOSTS=host` adds a public host for one run.
- It stops before sending a sign-in page anywhere, and it stops before any buy, cart, checkout, subscribe, delete or payment action.
- Jev uses raw CDP to control its own tab. That is the one approved exception to the no-raw-CDP rule, because the code is reviewed and it touches only the tab it opens.
- Keys: the Jev key comes from `TYPESAFE_API_KEY` or the Keychain item `agent-chrome.typesafe` (the installer stores it). The takeover model uses an OpenAI key (`OPENAI_API_KEY` or Keychain `agent-chrome.openai`), else `codex exec` on the machine's ChatGPT sign-in, which is slower but needs no key. If the machine has no Jev key, it returns `not_configured`; use Codex `gpt-6-sol` instead.
- Needs `uv` on `PATH`. The first run downloads jev-ultrafast (pinned to commit 1231850).

## 2. Start and attach — both harnesses

```bash
AC="$(ls -d ~/.claude/skills/agent-chrome ~/.codex/skills/agent-chrome ~/.agents/skills/agent-chrome 2>/dev/null | head -1)/bin/agent-chrome"
"$AC" up --json                                  # starts or reuses your account's instance (see section 10)
"$AC" attach amazon-orders                       # one session name per task
"$AC" pw amazon-orders tab-new https://www.amazon.com/gp/css/order-history
"$AC" pw amazon-orders snapshot                  # read refs, then click/fill/type by ref
"$AC" pw amazon-orders tab-close                 # close the tab you opened
"$AC" pw amazon-orders detach                    # never close: the browser is shared
```

Use lowercase session names matching `^[a-z0-9][a-z0-9-]{0,40}$`. Keep all Playwright calls behind `"$AC" pw`; do not bypass its guards. Snapshots stay under `~/Library/Caches/agent-chrome/<profile>/<session>`, not in the repo. Treat snapshots as private account data; do not commit or copy them into shared artifacts. The wrapper always captures Playwright stdout and stderr and removes `### Open tabs` sections before printing; wrapper `--json` includes the filtered text in one JSON object. Put wrapper flags before `pw`, not among its passthrough arguments. An exclusive per-session `.lock` serializes attachment and every `pw` invocation.

`attach` prints nothing about existing tabs by design. It creates and activates a temporary blank helper tab before attaching, captures all CLI output, removes newly written attachment artifacts (including `.playwright-cli/` snapshots), then closes the helper tab. Artifact cleanup excludes `.lock` and `.own-tab`; attachment explicitly clears tab ownership. Success prints only `attached <session> to <endpoint>` (or the JSON confirmation); failure reports only `attach failed` and the exit code.

playwright-cli reads the first tab once while attaching; the wrapper discards that output and deletes its files; keep Agent Chrome's startup tab as its first tab.

## 3. Tab etiquette

Open your own tab with `tab-new <url>`, supplying exactly one `http://` or `https://` URL. The wrapper binds your session to the tab you opened by CDP target id, stored in the session's `.own-tab` JSON marker. It serializes `tab-new` across sessions with the profile lock and accepts ownership only when exactly one new page target appears. Before every other allowed command except `detach` and `list`, it verifies that your target still exists as a page. If the marker is missing or malformed, or that tab closes, run `tab-new` again.

Attachment clears ownership. `tab-close` (even on failure) and `detach` also clear it, so after closing your tab you must `tab-new` again before reading or acting. Only drive tabs you opened. Close your current tab with `tab-close` without an index, then detach. Never navigate, close, or read another agent's or the owner's tab. `tab-select` and `tab-list` are always refused. Several agents may be attached at once; the target-id check does not prevent an outside actor from changing the selected tab. If selection is uncertain, open a fresh task tab before reading or acting.

## 4. Sign-in walls

Stop at a sign-in form, 2FA, passkey prompt, or captcha. Tell the owner exactly which site needs them. Have them sign in inside Agent Chrome; `"$AC" open <url>` opens his sign-in tab. Never type credentials, read them from 1Password, retry in a loop, or switch browsers to get around sign-in. After they confirm completion, resume in your own task tab, not his sign-in tab.

## 5. Action boundaries

Stay read-only by default. Make no purchases, cart changes, subscription changes, address changes, payment changes, or account-setting changes unless the owner explicitly asks in the current request. Minimize addresses, order numbers, payment details, and other personal data in notes and outputs.

## 6. What the wrapper allows

Only these `pw` commands are allowed; every other command is refused:

- Tabs and sessions: `tab-new`, `tab-close`, `detach`, `list`.
- Reading and interaction: `snapshot`, `click`, `dblclick`, `fill`, `type`, `press`, `hover`, `select`, `check`, `uncheck`, `drag`.
- Navigation: `go-back`, `go-forward`, `reload`.
- Output: `screenshot`, `pdf`.
- Dialogs and locators: `dialog-accept`, `dialog-dismiss`, `find`, `generate-locator`.

Options are rejected: any argument after the command starting with `-` is refused, including `--filename` and all session, browser, config, and CDP overrides. Output files stay in the session folder. `tab-new` takes exactly one valid http(s) URL. `tab-close`, `detach`, `list`, `snapshot`, `go-back`, `go-forward`, `reload`, `screenshot`, `pdf`, and `dialog-dismiss` take no arguments; `tab-close` never accepts an index.

Named refusals explain why:

- `close`, `close-all`, `kill-all`, `delete-data`: shut down or wipe the shared signed-in browser; use `detach`.
- `open`: launches a separate unsigned browser; use `tab-new` (wrapper `open <url>` is for the owner's sign-in tabs).
- `install`, `install-browser`: install other browsers instead of using dedicated Chrome Beta.
- `goto`: use `tab-new <url>` instead of navigating a tab you did not open.
- `state-save`, `state-load`: export live cookies to plaintext or inject foreign cookies.
- `cookie-*`, `localstorage-*`, `sessionstorage-*`, `request*`, `response*`: expose or alter credential material; `requests` can expose tokens in URLs.
- `eval`, `run-code`: can read cookies and storage or run arbitrary code; use `snapshot` for page reading.
- `console`, `tracing-start`: can expose tokens, headers, or cookies.
- `tab-select`, `tab-list`: select or reveal other tabs.
- `route`, `unroute`, `network-state-set`: change network behaviour for everyone.
- `show`: launches a separate dashboard browser.
- `video-start`: records every tab in the shared browser.
- `upload`: sends local files to a website; ask the owner first.
- `resize`: resizes the shared window.

Do not reproduce refused operations through scripts, `eval`, `run-code`, raw CDP, or direct Playwright calls. Never export cookies, passwords, or tokens.

### Limits, by design

Every tab in Agent Chrome belongs to the owner or to their agents, so tab-to-tab isolation here is etiquette the wrapper helps with, not a security boundary:

- playwright-cli attaches to the whole shared browser. While attached it observes every tab: it snapshots the first tab once during `attach` (the wrapper discards that output and its files), and it can collect other tabs' console messages and downloads into the session folder.
- The own-tab check runs just before each command. If your tab closes in the moment between that check and the command, Playwright may act on the neighbouring tab. Keep one task per tab and do not close tabs you did not open.
- `tab-new`, `tab-close` and `detach` print only a one-line summary, because the CLI's own response lists every tab's title and URL.
- `detach` deletes the session folder's snapshots, screenshots, console logs and downloads, because they are private account data. Copy anything you need into your answer, minus personal details, before detaching.

## 7. Codex specifics

Use this skill through the shell in headless `codex exec`, exactly as above. The Codex `chrome` plugin reaches Agent Chrome only when the ChatGPT extension is installed in Agent Chrome and removed from every other profile; run `"$AC" doctor` to inspect both locations. When the owner explicitly names `@Chrome`, follow that plugin's own rules.

The `browser` profile (`~/.codex/browser.config.toml`, used by `codex -p browser`) sets `gpt-6-sol` at medium effort. Where Codex runs sandboxed (read-only or workspace-write), the profile also needs `sandbox_mode = "workspace-write"` with `[sandbox_workspace_write] network_access = true` and `writable_roots` for `~/Library/Application Support/AgentChrome`, `~/Library/Caches/agent-chrome`, `~/Library/Caches/ms-playwright` and `$TMPDIR`. Otherwise the launcher cannot reach its loopback port or write its lock and session folders, and Codex reports it cannot attach. The installer writes these lines for you.

## 8. Claude Code specifics

Use the commands above through Bash. Reserve Claude in Chrome (`/chrome`) for the owner's own attended use in their personal browser. Do not use it for agent work unless they ask.

## 9. Health and lifecycle

Run `"$AC" doctor` before promising browser work in a new session. Check `"$AC" status` for ownership, CDP health, page count, and LaunchAgent state. Use `"$AC" endpoint` to print the configured endpoint without contacting Chrome.

Use `"$AC" down` only for an intentional shared-browser shutdown, after coordinating with the owner and other agents; normal task cleanup is `detach`. Install the LaunchAgent with `"$AC" install-launchagent` to start at login after reboots and restart after crashes. A clean quit stays down. If Chrome is running unmanaged, run `down` before installing. Remove the LaunchAgent with `"$AC" uninstall-launchagent`; this preserves the profile but can stop the managed process.

Inspect logs at `~/Library/Logs/agent-chrome/personal.log` after a launch failure. Exit codes: `0` success, `1` doctor failure, `2` usage error, `3` status not running, `4` refusal/conflict, `5` launch/CDP failure. Playwright passthrough returns its own exit code.

## 10. Setup facts for maintainers

Keep the persistent profile at `~/Library/Application Support/AgentChrome/personal` on the FileVault disk. Cookies use the real macOS Keychain because Playwright never launches this browser. Use Google Chrome Beta's separate app bundle so macOS does not route the owner's clicked links into Agent Chrome. Install it with `brew install --cask google-chrome@beta`; install the attachment CLI with `npm install -g @playwright/cli@latest`.

Do not enable Chrome sync or install the 1Password extension in this profile. Install the ChatGPT extension inside Agent Chrome when using the Codex plugin. Native messaging host links come from personal Chrome's `NativeMessagingHosts` directory; they do not share its browser profile.

Read configuration from `config/profiles.json` beside the launcher directory, resolving launcher symlinks. Use `AGENT_CHROME_BINARY` to override the binary, `AGENT_CHROME_PROFILE` for the default profile, or `--profile NAME` for an explicit profile. Never add automation, mock-keychain, password-store, headless, remote-origin, or remote-debugging-address flags.

### One Mac account

This kit sets up one Agent Chrome for the macOS account that runs the installer, on port 9230. Chrome's debugging port has no password and loopback ports are shared by every account on a Mac, so do not sign in to anything in Agent Chrome on a Mac where other people have their own macOS accounts. Ask your provider for the multi-account setup instead.
