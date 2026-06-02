---
name: linkedin-post-text
description: Publish or prepare a LinkedIn text-only post through the user's OpenCLI/browser-harness workflow. Use when the user asks Codex to write, polish, schedule manually, publish, verify, or log a LinkedIn text post for niche manufacturing, product, sourcing, OEM/ODM, B2B, or buyer education content.
---

# LinkedIn Text Post

## Workflow

Use only the user's configured browser tools for browser actions:

- OpenCLI: `E:\machine text\tool\opencli.ps1`
- Browser harness wrapper: `E:\machine text\tool\browser-stack.ps1`

Do not use the Browser plugin, native browser shortcuts, or unrelated browser automation when the user requires the `tool` directory workflow.

## Draft

Write English LinkedIn copy by default. For niche B2B accounts, make the post narrow, practical, and buyer-facing:

- lead with a specific production risk or sourcing decision
- explain why it matters to the target buyer
- include a short checklist or grounded viewpoint
- avoid hard selling, generic factory claims, and AI-sounding structure
- use at most 2 precise hashtags from the target industry

Good topic patterns:

- sample approval checklist
- material and finish tradeoffs
- production tolerance and consistency risk
- packaging fit before bulk production
- sample-to-bulk consistency

Save the final text to `E:\machine text\linkedin_ops\YYYY-MM-DD_text_post.txt` or a more specific filename.

## Publish

1. Open the feed:
   `.\tool\opencli.ps1 browser li open https://www.linkedin.com/feed/`
2. Open the share box (`发动态` / start a post).
3. Fill the composer with the final text using OpenCLI `fill` or browser-harness keyboard/JS helpers.
4. Publish only if the user has approved publishing in this run or has an active standing instruction that publishing does not require confirmation.

If there is no active permission, leave the post prepared and show the exact text before publishing.

## Verify

After publishing, open the profile activity page:

```powershell
.\tool\opencli.ps1 browser li open "https://www.linkedin.com/in/<profile-slug>/recent-activity/all/"
.\tool\opencli.ps1 browser li state
```

Confirm the new text appears as the latest activity. Check for accidental duplicates before leaving the run. If a same-topic video post already exists today, avoid publishing a fallback text post unless the user explicitly wants both.

## Log

Write logs in Chinese under `E:\machine text\linkedin_ops\YYYY-MM-DD_运营记录.md`; keep LinkedIn-facing text in English.

Record:

- final post text
- whether it was published or only prepared
- verification result
- visible impressions/comments if available
- reason for not posting, if withheld
