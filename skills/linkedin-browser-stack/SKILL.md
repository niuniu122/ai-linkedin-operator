---
name: linkedin-browser-stack
description: Operate LinkedIn automation through the packaged OpenCLI and Browser Harness stack. Use when Codex needs to check browser readiness, preserve a logged-in LinkedIn browser session, choose between OpenCLI adapters, OpenCLI Browser Bridge, and Browser Harness, recover from UI limits such as hidden upload inputs, or avoid tab/profile drift while posting, commenting, reading inboxes, inspecting timelines, and verifying LinkedIn activity.
---

# LinkedIn Browser Stack

## Purpose

Use this skill as the browser automation base layer for LinkedIn operator skills. It tells Codex which browser tool to use first, how to keep login state, how to hand off from OpenCLI to Browser Harness, and how to avoid operating on the wrong tab.

## Current Packaged State

This repository installs a local Windows workflow under `.\tool`:

- OpenCLI wrapper: `.\tool\opencli.ps1`
- Browser stack wrapper: `.\tool\browser-stack.ps1`
- Browser Harness wrapper: `.\tool\browser-harness.ps1`
- Isolated Harness fallback: `.\tool\browser-harness-isolated.ps1`
- Last OpenCLI-opened tab marker: `.\tool\browser-stack-state.json`

Observed baseline when this skill was packaged:

- OpenCLI `1.8.1`, daemon `1.8.1`, extension `1.0.17`
- Browser Harness `0.1.0`
- OpenCLI profile alias/default: `daily-login`
- Browser Harness daily-login daemon: `harness-real`
- OpenCLI command surface: about 1,000 commands, including LinkedIn, Reddit, Instagram, YouTube, X/Twitter, TikTok, and other adapters
- LinkedIn surface: read adapters for inbox, timeline, profile, posts, analytics, search, and UI/write adapters for posting, messaging, invitations, and Sales Navigator flows

Treat these as expected install-time capabilities, not permanent upstream version guarantees. Always run the readiness check at the start of a live browser run.

## Tool Priority

Use this order:

1. OpenCLI site adapters for deterministic read/write commands:
   `.\tool\opencli.ps1 linkedin <command> ...`
2. OpenCLI Browser Bridge for DOM state, selectors, form filling, tabs, network, and structured browser actions:
   `.\tool\opencli.ps1 browser <session> ...`
3. Browser Harness only when OpenCLI reaches a boundary: screenshots, visual checks, coordinate clicks, raw CDP, hidden file inputs, cross-origin visual interaction, or custom helpers.

Do not switch to a generic browser plugin or native browser shortcut when this local stack is available.

## Readiness

Run:

```powershell
.\tool\browser-stack.ps1 doctor
.\tool\browser-stack.ps1 verify-login
```

Expected result:

- OpenCLI daemon and extension are connected.
- OpenCLI profile `daily-login` is connected and default.
- Browser Harness can attach to the same daily logged-in browser state.

Browser Harness doctor may report missing `profile-use` or `BROWSER_USE_API_KEY`. Those are optional cloud/profile-sync items and do not block local LinkedIn operation.

## Daily Login Mode

Use the user's daily logged-in browser state by default:

```powershell
.\tool\opencli.ps1 browser li open https://www.linkedin.com/feed/
```

Then inspect:

```powershell
.\tool\opencli.ps1 browser li state
```

When Harness is needed:

```powershell
@'
print(page_info())
'@ | .\tool\browser-stack.ps1 harness-login
```

Direct `browser-harness` is shimmed to the same daily-login fallback after installation.

## OpenCLI To Harness Handoff

The wrappers auto-sync the active Harness tab to the last OpenCLI-opened page:

- `.\tool\opencli.ps1 browser <session> open <url>` records the target in `.\tool\browser-stack-state.json`.
- `browser-harness` and `.\tool\browser-stack.ps1 harness-login` read that marker and silently switch to the matching tab before running piped code.

Use manual sync/check when needed:

```powershell
.\tool\browser-stack.ps1 sync-opencli-tab
```

Skip auto-sync only when you explicitly want Harness to stay on its current tab:

```powershell
browser-harness --no-sync
```

or:

```powershell
$env:BROWSER_STACK_SKIP_SYNC='1'
```

## LinkedIn Operating Pattern

For read work, prefer OpenCLI adapters first:

```powershell
.\tool\opencli.ps1 linkedin inbox --limit 5 -f json
.\tool\opencli.ps1 linkedin timeline --limit 10 -f json
.\tool\opencli.ps1 linkedin posts <profile-url> --limit 10 -f json
```

For post preparation or UI work:

```powershell
.\tool\opencli.ps1 browser li open https://www.linkedin.com/feed/
.\tool\opencli.ps1 browser li state
.\tool\opencli.ps1 browser li find --text "Start a post"
```

For hidden video/image upload inputs, use Browser Harness/CDP after opening the LinkedIn page with OpenCLI. This preserves login state and avoids creating an empty automation profile.

For write actions, fail closed:

- Confirm the exact target account/thread/post before writing.
- Publish, send, connect, comment, or delete only when the user has approved the action in the current run or has a standing instruction.
- After a write action, verify from LinkedIn activity, inbox, or the relevant target page.

## Isolated Mode

Use isolated mode only for clean-browser testing that must not inherit the user's login:

```powershell
@'
print(page_info())
'@ | .\tool\browser-stack.ps1 harness-isolated
```

Do not use isolated mode for LinkedIn posting, commenting, inbox reading, Sales Navigator work, or any flow that depends on account state.

## Troubleshooting

If OpenCLI cannot see the browser profile, run:

```powershell
.\tool\browser-stack.ps1 doctor
```

If Browser Harness is on the wrong tab, run:

```powershell
.\tool\browser-stack.ps1 sync-opencli-tab
```

If Chrome asks for remote debugging permission in real-browser mode, allow it for the session and re-run doctor.

If OpenCLI has no adapter for a LinkedIn action, use Browser Bridge before Browser Harness. Browser Harness is the visual/CDP fallback, not the default first step.
