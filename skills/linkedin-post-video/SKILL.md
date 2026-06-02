---
name: linkedin-post-video
description: Publish or prepare a native LinkedIn video post through the user's OpenCLI/browser-harness workflow. Use when the user asks Codex to upload a local video to LinkedIn, write or polish the video caption, post a factory/product/process video, verify whether a LinkedIn video post was published, or recover from LinkedIn video upload UI issues such as media_button_missing.
---

# LinkedIn Video Post

## Workflow

Use only the user's configured browser tools for browser actions:

- OpenCLI: `E:\machine text\tool\opencli.ps1`
- Browser harness wrapper: `E:\machine text\tool\browser-stack.ps1`

Do not use the Browser plugin, native browser shortcuts, or unrelated browser automation when the user requires the `tool` directory workflow.

## Prepare

1. Confirm the video path exists.
2. Inspect video basics when useful:
   `ffprobe -v error -show_entries format=duration,size -show_streams <file>`
3. Draft the caption in English unless the user says otherwise.
4. Keep LinkedIn copy vertical and buyer-useful: one concrete production issue, one practical checklist or viewpoint, no broad sales pitch.
5. Use no more than 2 focused hashtags. Choose tags from the target industry instead of using a fixed template.
6. Save the caption to `E:\machine text\linkedin_ops\YYYY-MM-DD_video_post_caption.txt`.

For niche manufacturing accounts, prefer concrete topics like material choice, finish, packaging, sample approval, and sample-to-bulk consistency.

## Publish

Try the LinkedIn adapter first:

```powershell
.\tool\opencli.ps1 linkedin post-video --file "<absolute-video-path>" --text-file "<caption-file>" --execute true -f yaml
```

If it returns `media_button_missing` or cannot open the picker, use browser-harness/CDP:

1. Open LinkedIn feed with OpenCLI:
   `.\tool\opencli.ps1 browser li open https://www.linkedin.com/feed/`
2. Click the share box with OpenCLI or browser-harness.
3. Open the media upload flow.
4. Locate the file input, commonly `#media-editor-file-selector__file-input`.
5. Use CDP `DOM.setFileInputFiles` through browser-harness when the input is hidden.
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

Write logs in Chinese under `E:\machine text\linkedin_ops\YYYY-MM-DD_运营记录.md`; keep LinkedIn-facing text in English.
