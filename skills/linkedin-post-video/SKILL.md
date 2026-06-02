---
name: linkedin-post-video
description: Publish or prepare a native LinkedIn video post through the user's OpenCLI and Browser Harness workflow. Use when Codex needs to upload a local video to LinkedIn, write or polish the video caption, post a product/process video, verify whether a LinkedIn video post was published, or recover from LinkedIn video upload UI issues such as media_button_missing or hidden file inputs.
---

# LinkedIn Video Post

## Workflow

Use only the packaged local browser stack for browser actions:

- OpenCLI: `.\tool\opencli.ps1`
- Browser stack wrapper: `.\tool\browser-stack.ps1`

Prefer the `linkedin-browser-stack` skill for browser readiness, login-state checks, OpenCLI-to-Harness handoff, and troubleshooting.

Do not use a generic browser plugin, native browser shortcuts, or unrelated browser automation when the local stack is available.

## Prepare

1. Confirm the video path exists.
2. Inspect video basics when useful:
   `ffprobe -v error -show_entries format=duration,size -show_streams <file>`
3. Draft the caption in English unless the user says otherwise.
4. Keep LinkedIn copy vertical and buyer-useful: one concrete production issue, one practical checklist or viewpoint, no broad sales pitch.
5. Use no more than 2 focused hashtags. Choose tags from the target industry instead of using a fixed template.
6. Save the caption to `.\linkedin_ops\YYYY-MM-DD_video_post_caption.txt` or the user's preferred local operations folder.

For niche manufacturing accounts, prefer concrete topics like material choice, finish, packaging, sample approval, and sample-to-bulk consistency.

## Publish

Try the LinkedIn adapter first:

```powershell
.\tool\opencli.ps1 linkedin post-video --file "<absolute-video-path>" --text-file "<caption-file>" --execute true -f yaml
```

If it returns `media_button_missing` or cannot open the picker, use Browser Harness/CDP:

1. Open LinkedIn feed with OpenCLI:
   `.\tool\opencli.ps1 browser li open https://www.linkedin.com/feed/`
2. Click the share box with OpenCLI or Browser Harness.
3. Open the media upload flow.
4. Locate the file input, commonly `#media-editor-file-selector__file-input`.
5. Use CDP `DOM.setFileInputFiles` through Browser Harness when the input is hidden.
6. Wait until the video preview is visible or the upload finishes.
7. Fill the caption.
8. Publish only if the user has approved publishing in this run or has an active standing instruction that publishing does not require confirmation.

If there is no active permission, leave the post prepared and show the exact caption and target account before publishing.

## Verify

After publishing, verify from the profile activity page:

```powershell
.\tool\opencli.ps1 browser li open "https://www.linkedin.com/in/<profile-slug>/recent-activity/all/"
.\tool\opencli.ps1 browser li state
```

LinkedIn can delay showing a new video. Wait and re-check before posting a fallback. If a fallback text post was accidentally published and the video later appears, delete the duplicate and keep the stronger video post.

Record:

- video file path
- caption text
- publish result
- any fallback used
- profile activity verification
- early metrics if visible

Write logs under `.\linkedin_ops\YYYY-MM-DD_operations_log.md` or the user's preferred local operations folder; keep LinkedIn-facing text in English.
