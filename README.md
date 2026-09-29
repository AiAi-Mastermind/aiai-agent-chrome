# Agent Chrome kit

Give your AI agents (Claude Code and Codex) one safe browser of their own. You sign in to your sites once, and your agents can then check orders, look things up and work in your web portals without touching your everyday Chrome.

## What you get

- **Agent Chrome**: a separate Chrome Beta browser that starts when you log in. Your agents work in their own tabs there. Your everyday Chrome, passwords and bookmarks stay untouched.
- **The agent-chrome skill**: instructions and guardrails for Claude Code and Codex. Agents open their own tabs, never close yours, stop at sign-in screens for you to handle, and never buy, delete or change account settings unless you ask.
- **The best model for each job**, chosen by testing (see `docs/BENCHMARKS.md`):
  - signed-in work → Codex with GPT-6 Sol
  - quick checks from Claude Code → Sonnet 5.5
  - fast lookups on public sites → jev-drive (optional)

## What you need

- A Mac on a current version of macOS, with one user account on it
- [Homebrew](https://brew.sh)
- Claude Code, Codex, or both, already signed in
- Optional, for jev-drive: a Jev (TypeSafe) API key. An OpenAI API key is optional too and only makes jev-drive faster.

## Install (about 10 minutes)

1. Open Terminal in this folder.
2. Run `./install.sh`, or `./install.sh --with-jev` to include jev-drive.
3. When Chrome Beta opens, sign in to the sites you want your agents to use.

## Use it

- **Claude Code:** type `/agent-chrome`, or just ask in plain words: "Use Agent Chrome to check my last three orders on Amazon."
- **Codex:** start it with `codex -p browser`, then type `$agent-chrome` or ask the same way.
- **When an agent hits a sign-in, code or captcha screen,** it stops and tells you which site needs you. Sign in inside the Chrome Beta window, then tell the agent to continue.

## Safety rules built in

- Agents only use tabs they opened themselves, and they close them when they're done.
- They don't make purchases, cart changes, subscription changes or account changes unless you ask in that request.
- They never type passwords and never read your saved passwords.
- jev-drive works only on the public sites in `~/.local/share/agent-chrome/config/jev-public-hosts.json` (Wikipedia and Amazon to start). It sends each page's visible text to Jev's maker, TypeSafe, and to OpenAI, so never add a site where you are signed in to private data (email, banking, insurance carriers, your CRM).
- Don't turn on Chrome sync or install a password manager in Chrome Beta.

## Check and update

- Health check: `~/.local/share/agent-chrome/bin/agent-chrome doctor`
- Update: run `./install.sh` again from a newer copy of this kit. Your sign-ins and your public-site list are kept.
- Remove: `./uninstall.sh` (keeps your sign-ins) or `./uninstall.sh --purge` (deletes them too).
