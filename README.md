# AI LinkedIn Operator

This repository packages a practical LinkedIn operating workflow for AI agents:

- publish native LinkedIn video posts
- publish LinkedIn text posts
- leave targeted LinkedIn comments
- use OpenCLI and Browser Harness against the user's logged-in browser
- keep OpenCLI and Browser Harness aligned on the same browser profile and tab

It is built around Codex skills and local browser tools. It does not store LinkedIn passwords, cookies, browser profiles, private messages, private logs, or account memory.

## What Is Included

```text
skills/
  linkedin-browser-stack/ Browser automation base layer for LinkedIn operations
  linkedin-post-video/    Native LinkedIn video post workflow
  linkedin-post-text/     LinkedIn text post workflow
  linkedin-comment/       Targeted comment workflow

tools/
  wrappers/               PowerShell wrappers for OpenCLI and Browser Harness
  opencli-overrides/      LinkedIn post-video adapter and manifest patch

scripts/
  install.ps1             Install skills and local tool dependencies
  patch-opencli-manifest.mjs
  verify.ps1              Basic local package verification
```

## Design

The workflow assumes an AI agent controls a real browser through local tools:

- OpenCLI: https://github.com/jackwener/OpenCLI
- Browser Harness: https://github.com/browser-use/browser-harness

The account operator stays logged in through their own browser session. OpenCLI is used first for deterministic adapters and Browser Bridge actions. Browser Harness is used only as the fallback for screenshots, raw CDP, hidden file inputs, visual interaction, and other UI edges.

The wrappers include OpenCLI-to-Harness tab sync: when OpenCLI opens a URL, the target is recorded in `tool/browser-stack-state.json`; Browser Harness switches to that tab before running piped scripts. The state file is local runtime data and is ignored by git.

## Install On Windows

Run PowerShell from the repository root:

```powershell
.\scripts\install.ps1
```

The installer will:

1. copy all Codex skills into `%USERPROFILE%\.codex\skills`
2. clone OpenCLI into `.\tool\OpenCLI` if missing
3. clone Browser Harness into `.\tool\browser-harness` if missing
4. copy the PowerShell wrappers into `.\tool`
5. apply the LinkedIn `post-video` adapter to OpenCLI
6. install/build OpenCLI and install Browser Harness when possible

Check readiness:

```powershell
.\tool\browser-stack.ps1 doctor
.\tool\browser-stack.ps1 verify-login
```

If Chrome remote debugging is not enabled, run:

```powershell
.\tool\browser-stack.ps1 setup-real
```

Then enable remote debugging in Chrome and re-run doctor.

## Usage Examples

Check the browser stack:

```text
Use linkedin-browser-stack. Check whether OpenCLI and Browser Harness share my logged-in LinkedIn browser state.
```

Publish a LinkedIn video post:

```text
Use linkedin-post-video. Upload this MP4 to LinkedIn with a vertical buyer-education caption and verify the post.
```

Publish a LinkedIn text post:

```text
Use linkedin-post-text. Publish a buyer-education post about sample approval and log the result.
```

Comment on target posts:

```text
Use linkedin-comment. Find relevant target-industry posts and leave three natural comments.
```

## Operating Rules

- Use the local OpenCLI/Browser Harness workflow for browser actions.
- Prefer OpenCLI adapters and Browser Bridge before Browser Harness.
- Do not upload cookies, profile folders, messages, private logs, memory files, or runtime state.
- Confirm exact targets before write actions such as publish, send, connect, comment, delete, or invite.
- For comments, identify a concrete resonance point first, then add a grounded production or sourcing viewpoint.
- For niche industry content, keep posts narrow and useful to the target buyer. Use no more than two relevant hashtags.

## Included OpenCLI Override

The repository includes a local LinkedIn `post-video` adapter under:

```text
tools/opencli-overrides/clis/linkedin/post-video.js
```

The adapter is applied by `scripts/install.ps1`. It is kept separate from the upstream OpenCLI repository so this package stays small and avoids committing `node_modules` or build artifacts.
