---
name: linkedin-low-risk-connect
description: Build low-risk LinkedIn connection requests from a vetted prospect spreadsheet or candidate list through the user's OpenCLI and Browser Harness workflow. Use when Codex needs to review prospects, verify LinkedIn profiles, avoid bulk connection requests, write target-specific invitation notes, send one personalized invite at a time, or log connection-request outcomes for B2B sourcing, manufacturing, sales, founder, product, or overseas-buyer relationship workflows.
---

# LinkedIn Low-Risk Connect

## Workflow

Use only the packaged local browser stack for browser actions:

- OpenCLI: `.\tool\opencli.ps1`
- Browser stack wrapper: `.\tool\browser-stack.ps1`

Prefer the `linkedin-browser-stack` skill for browser readiness, login-state checks, OpenCLI-to-Harness handoff, and troubleshooting.

Do not use a generic browser plugin, native browser shortcuts, or unrelated browser automation when the local stack is available.

## Input

Accept a vetted spreadsheet or candidate list with fields such as:

- candidate name
- company, project, or organization
- LinkedIn URL or search clue
- due-diligence summary
- business fit
- concrete connection angle
- confidence or risk notes
- suggested next step

Parse structured spreadsheets with a real spreadsheet parser. Do not rely on screenshots when the file itself is available.

Never commit prospect spreadsheets, target lists, private notes, browser state, or operating logs.

## Low-Risk Gate

Do not bulk add. Process exactly one candidate at a time.

Target confidence does not make the action low risk. Before judging any candidate, judge whether the account is ready to send another connection request.

Use this decision order:

```text
account stability -> recent invite history -> relationship warmth -> target confidence -> invite necessity
```

Skip all connection requests for the session when any condition is true:

- recent `AUTH_REQUIRED`, public-login fallback, checkpoint, CAPTCHA, or identity-verification signal
- recent outbound invite burst or unknown pending-invitation state
- low remaining personalized invitation allowance
- the workflow starts from a cold lead list and needs multiple people searches
- the target has no warm interaction and no exact profile URL
- the account has just posted, commented, messaged, searched, or connected multiple times in the same operating window

When the account-readiness gate fails, prepare a shortlist, comment plan, or human-review note instead of sending invites.

Send a connection request only when all conditions are true:

- The LinkedIn profile is tied to the candidate name from the input.
- The visible headline, company, about section, experience, posts, or project context matches the due-diligence notes.
- The page is a real person profile, not a company page, search result ambiguity, duplicate, or uncertain match.
- A usable `Connect` action is visible or an OpenCLI connect command can target the exact profile URL.
- The invite note is target-specific, short, and non-salesy.
- The account state is normal: no public login fallback, checkpoint, CAPTCHA, permission prompt, or unstable page state.

Skip instead of sending when any signal is weak:

- multiple possible profiles
- only `Follow`, `Message`, or no visible connection action
- company/project mismatch
- profile not accessible
- auth required, checkpoint, CAPTCHA, or public-login page
- invite note limit cannot be confirmed
- the page shifts or the clicked target is uncertain

## Verify Candidates

Start with sent-invitation and account-state checks when available:

```powershell
.\tool\opencli.ps1 linkedin sent-invitations -f json
.\tool\browser-stack.ps1 verify-login
```

For each candidate:

1. Search with exact name plus company, project, or role clues.
2. Open the best candidate profile and read visible identity signals.
3. Compare the profile against the due-diligence notes.
4. Record the evidence used for the match.
5. Decide `send`, `skip`, or `needs human review`.

Avoid a direct spreadsheet-to-search-to-connect flow in one session. If the input only contains search clues, create a reviewed shortlist first and connect later only when the account state is clean and the exact profile URL is known.

Use OpenCLI adapters and Browser Bridge first. Use Browser Harness only when the page is already open and a visual fallback is necessary.

Never continue if the browser falls back to a public login page or asks for a security checkpoint.

## Invitation Notes

Write LinkedIn-facing notes in English unless the target profile is clearly better served in another language.

Keep the note under the visible LinkedIn note limit. When the UI shows a shorter limit, rewrite before filling the field.

Use this shape:

```text
Hi <Name>, I saw <specific project, role, or milestone>. For <their product or market>, <one practical sourcing, manufacturing, launch, or quality point> matters. I work around <relevant area>. Glad to connect.
```

Good notes are specific and quiet:

- one concrete reason for connecting
- one relevant professional point
- no hard pitch
- no price, MOQ, catalog, or service dump
- no generic "happy to connect" as the whole note

## Send

Use a fail-closed OpenCLI command when an adapter exists:

```powershell
.\tool\opencli.ps1 linkedin connect <profile-url> --expected-name <name> --note "<note>" --send -f json
```

If OpenCLI cannot send but the page clearly shows the correct profile and `Connect` action, use Browser Bridge or Browser Harness:

1. Open the exact profile URL.
2. Confirm visible name, headline, and company or project context.
3. Click only the exact `Connect` action.
4. Click `Add a note` when available.
5. Fill the final note.
6. Click `Send`.
7. Verify the state changed to pending, waiting, or withdraw invitation.

Never send if the UI target is ambiguous, the profile does not match, or the page state changes unexpectedly.

## Log

Write local logs in the user's preferred language. Keep LinkedIn-facing notes in the target language used on LinkedIn.

For each candidate, record:

- account-readiness decision
- input source and candidate name
- profile URL or search evidence
- warm signal or lack of warm signal
- match evidence
- decision: sent, skipped, failed, or needs human review
- exact invite note when sent
- verification result after sending
- risk blocker when skipped

Use a local operations folder such as `.\linkedin_ops\YYYY-MM-DD_operations_log.md`. Do not commit logs.
