---
name: linkedin-comment
description: Leave targeted LinkedIn comments through the user's OpenCLI and Browser Harness workflow. Use when Codex needs to comment on LinkedIn posts, reply to comments, engage target accounts, operate LinkedIn trust-building, or write natural comments for niche industry, product, sourcing, manufacturing, OEM/ODM, B2B, or overseas buyer conversations.
---

# LinkedIn Comment

## Workflow

Use only the packaged local browser stack for browser actions:

- OpenCLI: `.\tool\opencli.ps1`
- Browser stack wrapper: `.\tool\browser-stack.ps1`

Prefer the `linkedin-browser-stack` skill for browser readiness, login-state checks, OpenCLI-to-Harness handoff, and troubleshooting.

Do not use a generic browser plugin, native browser shortcuts, or unrelated browser automation when the local stack is available.

## Select Targets

Comment only where the post has a real overlap with the account's trust-building goals:

- target industry and buyer segment
- prototype, sample, launch, fulfillment, or sourcing discussions
- material choice, finish, packaging, quality, production risk, or buyer education
- founders, operators, sourcing managers, product managers, or manufacturers with visible relevance

Skip posts where the only possible comment would be generic encouragement, pure sales outreach, politics, unrelated news, or low-context emojis.

## Write The Comment

Every comment must follow this order:

1. Name the concrete resonance point from the target post.
2. Add one grounded viewpoint from production, sourcing, sample approval, or quality control.
3. Keep it short and human. Do not pitch services unless the user explicitly asks.

Use English for LinkedIn-facing comments unless the target post is clearly in another language and that language is more natural.

Avoid:

- "Great post"
- "Thanks for sharing"
- "As a manufacturer..."
- long consultant-style paragraphs
- obvious AI rhythm with three balanced clauses
- hashtags in comments unless there is a clear reason

Comment shape:

```text
The point about <specific detail> is the part I see most often in production too. For this kind of product, <one practical manufacturing insight>. It usually shows up in the sample long before bulk production.
```

## Publish

Use OpenCLI to open/read the post when available. Use Browser Harness coordinates only when LinkedIn comment boxes do not expose stable selectors.

Publish only if the user has approved commenting in this run or has an active standing instruction that publishing does not require confirmation. If there is no active permission, show the exact post target and comment text first.

After posting, re-read or screenshot the post to verify the comment appears. If the comment box does not open or the comment cannot be created, log the actual blocker instead of inventing a result.

## Log

Write logs under `.\linkedin_ops\YYYY-MM-DD_operations_log.md` or the user's preferred local operations folder; keep LinkedIn-facing comments in English.

For each comment record:

- target name and profile/company if visible
- post topic or URL
- resonance point used
- exact comment text
- result: sent, not sent, failed, or could not open comment box
- reason for skipping, if skipped
