# 让 AI 自动运营你的领英账号

This repository packages a practical LinkedIn operating workflow for AI agents:

- publish native LinkedIn video posts
- publish LinkedIn text posts
- leave targeted LinkedIn comments
- use OpenCLI and browser-harness against the user's logged-in browser

It is built around Codex skills and local browser tools. It does not store LinkedIn passwords, cookies, browser profiles, or private operating logs.

## What Is Included

```text
skills/
  linkedin-post-video/   Native LinkedIn video post workflow
  linkedin-post-text/    LinkedIn text post workflow
  linkedin-comment/      Targeted comment workflow

tools/
  wrappers/              PowerShell wrappers for OpenCLI and browser-harness
  opencli-overrides/     LinkedIn post-video adapter and manifest patch

scripts/
  install.ps1            Install skills and local tool dependencies
  patch-opencli-manifest.mjs
  verify.ps1             Basic local package verification
```

## Design

The workflow assumes an AI agent controls a real browser through local tools:

- OpenCLI: https://github.com/jackwener/OpenCLI
- browser-harness: https://github.com/browser-use/browser-harness

The account operator stays logged in through their own browser session. The repository does not include credentials.

## Install On Windows

Run PowerShell from the repository root:

```powershell
.\scripts\install.ps1
```

The installer will:

1. copy the three Codex skills into `%USERPROFILE%\.codex\skills`
2. clone OpenCLI into `.\tool\OpenCLI` if missing
3. clone browser-harness into `.\tool\browser-harness` if missing
4. copy the PowerShell wrappers into `.\tool`
5. apply the LinkedIn `post-video` adapter to OpenCLI
6. install/build OpenCLI and install browser-harness when possible

If Chrome remote debugging is not enabled, run:

```powershell
.\tool\browser-stack.ps1 setup-real
```

Then enable remote debugging in Chrome and run:

```powershell
.\tool\browser-stack.ps1 doctor
```

## Usage Examples

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

- Use only the local OpenCLI/browser-harness browser workflow for browser actions.
- Do not upload cookies, profile folders, messages, private logs, or memory files.
- For comments, identify a concrete resonance point first, then add a grounded production or sourcing viewpoint.
- For niche industry content, keep posts narrow and useful to the target buyer. Use no more than two relevant hashtags.

## Included OpenCLI Override

The repository includes a local LinkedIn `post-video` adapter under:

```text
tools/opencli-overrides/clis/linkedin/post-video.js
```

The adapter is applied by `scripts/install.ps1`. It is kept separate from the upstream OpenCLI repository so this package stays small and avoids committing `node_modules` or build artifacts.
