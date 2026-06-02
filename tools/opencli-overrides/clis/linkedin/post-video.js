import { cli, Strategy } from '@jackwener/opencli/registry';
import { ArgumentError, AuthRequiredError, CommandExecutionError } from '@jackwener/opencli/errors';
import fs from 'node:fs';
import path from 'node:path';

const LINKEDIN_DOMAIN = 'www.linkedin.com';
const SHARE_URL = 'https://www.linkedin.com/feed/?shareActive=true';

function normalizeWhitespace(value) {
  return String(value ?? '').replace(/[\u00a0\u202f]/g, ' ').replace(/\s+/g, ' ').trim();
}

function requireStringArg(args, name, label = name) {
  const value = String(args?.[name] ?? '').trim();
  if (!value) throw new ArgumentError(`Missing required ${label}`);
  return value;
}

function requireExistingFile(rawPath, label) {
  const absPath = path.resolve(String(rawPath || ''));
  if (!fs.existsSync(absPath)) throw new ArgumentError(`${label} not found: ${absPath}`);
  if (!fs.statSync(absPath).isFile()) throw new ArgumentError(`${label} is not a file: ${absPath}`);
  return absPath;
}

function readPostText(args) {
  if (args?.['text-file']) {
    return fs.readFileSync(requireExistingFile(args['text-file'], '--text-file'), 'utf8').trim();
  }
  const text = String(args?.text ?? '').trim();
  if (!text) throw new ArgumentError('Missing post text. Pass --text or --text-file.');
  return text;
}

function unwrap(payload) {
  if (payload && typeof payload === 'object' && 'data' in payload && 'session' in payload) return payload.data;
  return payload;
}

async function evaluate(page, js) {
  return unwrap(await page.evaluate(js));
}

function assertLinkedInPageStatus(probe) {
  if (probe?.authRequired) throw new AuthRequiredError('LinkedIn login required');
  if (!probe?.shadowRootFound) {
    throw new CommandExecutionError(
      'LinkedIn share dialog was not available',
      `URL: ${probe?.url || 'unknown'} Title: ${probe?.title || 'unknown'} Body: ${normalizeWhitespace(probe?.bodyText || '').slice(0, 300)}`,
    );
  }
}

async function probeShareDialog(page) {
  return evaluate(page, `(() => {
    const bodyText = document.body ? document.body.innerText || '' : '';
    const root = document.querySelector('#interop-outlet')?.shadowRoot;
    const hasEditor = !!root?.querySelector('div[contenteditable="true"]');
    const hasUploadInput = !!root?.querySelector('input[type="file"]');
    const hasMediaButton = !!root?.querySelector('button.share-promoted-detour-button');
    const shadowText = root ? String(root.textContent || '') : '';
    return {
      url: location.href,
      title: document.title,
      bodyText,
      authRequired: /sign in|join now|登录|注册/i.test(bodyText) && !root,
      shadowRootFound: !!root,
      hasEditor,
      hasUploadInput,
      hasMediaButton,
      activeShareDialog: hasEditor || hasUploadInput || hasMediaButton || /想讨论|start a post|what do you want to talk/i.test(shadowText),
    };
  })()`);
}

async function waitForShareDialog(page, timeoutSeconds = 30) {
  const deadline = Date.now() + timeoutSeconds * 1000;
  let last = null;
  while (Date.now() < deadline) {
    last = await probeShareDialog(page);
    if (last?.activeShareDialog) return last;
    await page.wait(1);
  }
  assertLinkedInPageStatus(last);
  return last;
}

async function clickStartPostFromFeed(page) {
  const result = await evaluate(page, `(() => {
    function visible(el) {
      if (!el) return false;
      const rect = el.getBoundingClientRect();
      const style = getComputedStyle(el);
      return rect.width > 0 && rect.height > 0 && style.visibility !== 'hidden' && style.display !== 'none';
    }
    const candidates = Array.from(document.querySelectorAll('button, [role="button"], a'))
      .filter(visible)
      .map((el) => ({
        el,
        text: String(el.innerText || el.textContent || el.getAttribute('aria-label') || '').replace(/\\s+/g, ' ').trim(),
      }));
    const target = candidates.find((item) => /发动态|start a post|create a post/i.test(item.text));
    if (!target) {
      return { ok: false, reason: 'start_post_button_missing', sample: candidates.slice(0, 20).map((item) => item.text).filter(Boolean) };
    }
    target.el.click();
    return { ok: true, text: target.text };
  })()`);
  if (!result?.ok) {
    throw new CommandExecutionError(
      `Could not open LinkedIn composer from feed: ${result?.reason || 'unknown'}`,
      Array.isArray(result?.sample) ? result.sample.join(' | ') : '',
    );
  }
  return result;
}

async function openShareComposer(page) {
  await page.goto(SHARE_URL);
  await page.wait(5);
  try {
    return await waitForShareDialog(page, 12);
  } catch {
    await page.goto('https://www.linkedin.com/feed/');
    await page.wait(5);
    await clickStartPostFromFeed(page);
    return waitForShareDialog(page, 35);
  }
}

async function openMediaPicker(page) {
  const result = await evaluate(page, `(() => {
    const root = document.querySelector('#interop-outlet')?.shadowRoot;
    if (!root) return { ok: false, reason: 'shadow_root_missing' };
    if (root.querySelector('input[type="file"]')) return { ok: true, alreadyOpen: true };
    const buttons = Array.from(root.querySelectorAll('button.share-promoted-detour-button'));
    const mediaButton = buttons.find((button) => {
      const label = button.getAttribute('aria-label') || '';
      const html = button.innerHTML || '';
      return /media|image|媒体|图片|文件/i.test(label) || html.includes('image-medium');
    }) || buttons[0];
    if (!mediaButton) return { ok: false, reason: 'media_button_missing' };
    mediaButton.click();
    return { ok: true, alreadyOpen: false };
  })()`);
  if (!result?.ok) throw new CommandExecutionError(`Could not open LinkedIn media picker: ${result?.reason || 'unknown'}`);

  const deadline = Date.now() + 20_000;
  let status = null;
  while (Date.now() < deadline) {
    status = await evaluate(page, `(() => {
      const root = document.querySelector('#interop-outlet')?.shadowRoot;
      const input = root?.querySelector('input[type="file"]');
      return {
        ok: !!input,
        accept: input?.getAttribute('accept') || '',
        text: root ? String(root.textContent || '').replace(/\\s+/g, ' ').trim().slice(0, 200) : '',
      };
    })()`);
    if (status?.ok) return status;
    await page.wait(1);
  }
  throw new CommandExecutionError('LinkedIn media picker did not expose a file input', JSON.stringify(status || {}));
}

function findFileInputNodeId(node) {
  if (!node || typeof node !== 'object') return null;
  const attrs = {};
  const rawAttrs = Array.isArray(node.attributes) ? node.attributes : [];
  for (let i = 0; i < rawAttrs.length; i += 2) attrs[String(rawAttrs[i] || '').toLowerCase()] = String(rawAttrs[i + 1] || '');
  if (String(node.nodeName || '').toUpperCase() === 'INPUT' && String(attrs.type || '').toLowerCase() === 'file') {
    return typeof node.nodeId === 'number' ? node.nodeId : null;
  }
  const groups = [node.children, node.shadowRoots, node.pseudoElements, node.contentDocument ? [node.contentDocument] : null];
  for (const group of groups) {
    if (!Array.isArray(group)) continue;
    for (const child of group) {
      const found = findFileInputNodeId(child);
      if (found) return found;
    }
  }
  return null;
}

async function uploadWithCdp(page, absVideoPath) {
  if (typeof page.cdp !== 'function') return { ok: false, reason: 'cdp_unavailable' };
  try {
    await page.cdp('DOM.enable', {});
    const doc = await page.cdp('DOM.getDocument', { depth: -1, pierce: true });
    const nodeId = findFileInputNodeId(doc?.root);
    if (!nodeId) return { ok: false, reason: 'file_input_node_not_found' };
    await page.cdp('DOM.setFileInputFiles', { files: [absVideoPath], nodeId });
    const verification = await evaluate(page, `(() => {
      const root = document.querySelector('#interop-outlet')?.shadowRoot;
      const input = root?.querySelector('input[type="file"]');
      if (!input) return { ok: false };
      input.dispatchEvent(new Event('input', { bubbles: true, composed: true }));
      input.dispatchEvent(new Event('change', { bubbles: true, composed: true }));
      return { ok: true, files: input.files ? input.files.length : 0 };
    })()`);
    if (!verification?.ok || !verification.files) return { ok: false, reason: 'cdp_set_files_not_reflected' };
    return { ok: true, via: 'cdp' };
  } catch (error) {
    return { ok: false, reason: String(error?.message || error) };
  }
}

async function uploadWithCdpDrop(page, absVideoPath) {
  if (typeof page.cdp !== 'function') return { ok: false, reason: 'cdp_unavailable' };
  try {
    const point = await evaluate(page, `(() => {
      const root = document.querySelector('#interop-outlet')?.shadowRoot;
      if (!root) return { ok: false, reason: 'shadow_root_missing' };
      const input = root.querySelector('input[type="file"]');
      const target = input?.closest('section') || root.querySelector('section') || root.host;
      const rect = target.getBoundingClientRect();
      const x = Math.round(rect.left + rect.width / 2);
      const y = Math.round(rect.top + rect.height / 2);
      return { ok: true, x, y, width: Math.round(rect.width), height: Math.round(rect.height) };
    })()`);
    if (!point?.ok) return { ok: false, reason: point?.reason || 'drop_target_missing' };
    const data = {
      items: [],
      files: [absVideoPath],
      dragOperationsMask: 1,
    };
    await page.cdp('Input.dispatchDragEvent', { type: 'dragEnter', x: point.x, y: point.y, data });
    await page.wait(0.3);
    await page.cdp('Input.dispatchDragEvent', { type: 'dragOver', x: point.x, y: point.y, data });
    await page.wait(0.3);
    await page.cdp('Input.dispatchDragEvent', { type: 'drop', x: point.x, y: point.y, data });
    await page.wait(1);
    const verification = await evaluate(page, `(() => {
      const root = document.querySelector('#interop-outlet')?.shadowRoot;
      const input = root?.querySelector('input[type="file"]');
      const text = root ? String(root.textContent || '') : '';
      return {
        ok: !!root,
        files: input?.files?.length || 0,
        hasFileName: text.includes(${JSON.stringify(path.basename(absVideoPath))}),
      };
    })()`);
    if (!verification?.files && !verification?.hasFileName) return { ok: false, reason: 'cdp_drop_not_reflected' };
    return { ok: true, via: 'cdp_drop' };
  } catch (error) {
    return { ok: false, reason: String(error?.message || error) };
  }
}

async function uploadWithBrowserFile(page, absVideoPath) {
  const base64 = fs.readFileSync(absVideoPath).toString('base64');
  const fileName = path.basename(absVideoPath);
  const mimeType = 'video/mp4';
  const chunkSize = 384 * 1024;

  await evaluate(page, `(() => {
    window.__codexLinkedInUploadChunks = [];
    return { ok: true };
  })()`);

  for (let start = 0; start < base64.length; start += chunkSize) {
    const chunk = base64.slice(start, start + chunkSize);
    await evaluate(page, `(() => {
      window.__codexLinkedInUploadChunks.push(${JSON.stringify(chunk)});
      return { ok: true, chunks: window.__codexLinkedInUploadChunks.length };
    })()`);
  }

  const result = await evaluate(page, `(async () => {
    const root = document.querySelector('#interop-outlet')?.shadowRoot;
    const input = root?.querySelector('input[type="file"]');
    if (!input) return { ok: false, reason: 'file_input_missing' };
    const b64 = (window.__codexLinkedInUploadChunks || []).join('');
    delete window.__codexLinkedInUploadChunks;
    const binary = atob(b64);
    const bytes = new Uint8Array(binary.length);
    for (let i = 0; i < binary.length; i += 1) bytes[i] = binary.charCodeAt(i);
    const file = new File([bytes], ${JSON.stringify(fileName)}, { type: ${JSON.stringify(mimeType)}, lastModified: Date.now() });
    const dt = new DataTransfer();
    dt.items.add(file);
    const target = input.closest('section') || root.querySelector('section') || input;
    for (const type of ['dragenter', 'dragover']) {
      target.dispatchEvent(new DragEvent(type, { bubbles: true, composed: true, cancelable: true, dataTransfer: dt }));
    }
    target.dispatchEvent(new DragEvent('drop', { bubbles: true, composed: true, cancelable: true, dataTransfer: dt }));
    input.files = dt.files;
    input.dispatchEvent(new Event('input', { bubbles: true, composed: true }));
    input.dispatchEvent(new Event('change', { bubbles: true, composed: true }));
    return { ok: true, files: input.files ? input.files.length : 0, name: input.files && input.files[0] ? input.files[0].name : '', size: file.size };
  })()`);
  if (!result?.ok) throw new CommandExecutionError(`Browser-side file upload failed: ${result?.reason || 'unknown'}`);
  return { ok: true, via: 'browser_file', ...result };
}

async function waitForMediaReady(page, timeoutSeconds = 180) {
  const deadline = Date.now() + timeoutSeconds * 1000;
  let last = null;
  while (Date.now() < deadline) {
    last = await evaluate(page, `(() => {
      const root = document.querySelector('#interop-outlet')?.shadowRoot;
      const buttons = root ? Array.from(root.querySelectorAll('button')) : [];
      const primary = buttons.find((button) => String(button.className || '').includes('share-box-footer__primary-btn'));
      const disabled = !primary || primary.disabled || primary.classList.contains('artdeco-button--disabled') || primary.getAttribute('aria-disabled') === 'true';
      const text = root ? String(root.textContent || '').replace(/\\s+/g, ' ').trim().slice(0, 500) : '';
      const hasVideo = !!root?.querySelector('video, img, canvas, [class*="preview"], [class*="thumbnail"], [class*="media"]');
      return { ready: !!primary && !disabled, disabled, hasVideo, text };
    })()`);
    if (last?.ready) return last;
    await page.wait(2);
  }
  throw new CommandExecutionError('LinkedIn video upload did not finish before timeout', JSON.stringify(last || {}));
}

async function clickMediaNext(page) {
  const result = await evaluate(page, `(() => {
    const root = document.querySelector('#interop-outlet')?.shadowRoot;
    const buttons = root ? Array.from(root.querySelectorAll('button')) : [];
    const primary = buttons.find((button) => String(button.className || '').includes('share-box-footer__primary-btn'));
    if (!primary) return { ok: false, reason: 'next_button_missing' };
    const disabled = primary.disabled || primary.classList.contains('artdeco-button--disabled') || primary.getAttribute('aria-disabled') === 'true';
    if (disabled) return { ok: false, reason: 'next_button_disabled' };
    primary.click();
    return { ok: true };
  })()`);
  if (!result?.ok) throw new CommandExecutionError(`Could not continue from LinkedIn media editor: ${result?.reason || 'unknown'}`);
}

async function waitForComposerWithMedia(page, timeoutSeconds = 60) {
  const deadline = Date.now() + timeoutSeconds * 1000;
  let last = null;
  while (Date.now() < deadline) {
    last = await evaluate(page, `(() => {
      const root = document.querySelector('#interop-outlet')?.shadowRoot;
      const editor = root?.querySelector('div[contenteditable="true"]');
      const publish = root ? Array.from(root.querySelectorAll('button')).find((button) => String(button.className || '').includes('share-actions__primary-action')) : null;
      return {
        ready: !!editor && !!publish,
        hasEditor: !!editor,
        hasPublish: !!publish,
        text: root ? String(root.textContent || '').replace(/\\s+/g, ' ').trim().slice(0, 300) : '',
      };
    })()`);
    if (last?.ready) return last;
    await page.wait(1);
  }
  throw new CommandExecutionError('LinkedIn composer did not return after media upload', JSON.stringify(last || {}));
}

async function fillPostText(page, postText) {
  const result = await evaluate(page, `(() => {
    const root = document.querySelector('#interop-outlet')?.shadowRoot;
    const editor = root?.querySelector('div[contenteditable="true"]');
    if (!editor) return { ok: false, reason: 'editor_missing' };
    const text = ${JSON.stringify(postText)};
    editor.focus();
    editor.textContent = '';
    editor.appendChild(document.createTextNode(text));
    editor.dispatchEvent(new InputEvent('input', { bubbles: true, composed: true, inputType: 'insertText', data: text }));
    return { ok: true, actual: editor.innerText || editor.textContent || '' };
  })()`);
  if (!result?.ok) throw new CommandExecutionError(`Could not fill LinkedIn post text: ${result?.reason || 'unknown'}`);
  if (normalizeWhitespace(result.actual) !== normalizeWhitespace(postText)) {
    throw new CommandExecutionError('LinkedIn post text verification failed');
  }
  return result;
}

async function waitForPublishEnabled(page, timeoutSeconds = 90) {
  const deadline = Date.now() + timeoutSeconds * 1000;
  let last = null;
  while (Date.now() < deadline) {
    last = await evaluate(page, `(() => {
      const root = document.querySelector('#interop-outlet')?.shadowRoot;
      const publish = root ? Array.from(root.querySelectorAll('button')).find((button) => String(button.className || '').includes('share-actions__primary-action')) : null;
      const disabled = !publish || publish.disabled || publish.classList.contains('artdeco-button--disabled') || publish.getAttribute('aria-disabled') === 'true';
      return { ready: !!publish && !disabled, disabled, text: publish ? publish.textContent || '' : '' };
    })()`);
    if (last?.ready) return last;
    await page.wait(2);
  }
  throw new CommandExecutionError('LinkedIn publish button did not enable before timeout', JSON.stringify(last || {}));
}

async function clickPublish(page) {
  const result = await evaluate(page, `(() => {
    const root = document.querySelector('#interop-outlet')?.shadowRoot;
    const publish = root ? Array.from(root.querySelectorAll('button')).find((button) => String(button.className || '').includes('share-actions__primary-action')) : null;
    if (!publish) return { ok: false, reason: 'publish_button_missing' };
    const disabled = publish.disabled || publish.classList.contains('artdeco-button--disabled') || publish.getAttribute('aria-disabled') === 'true';
    if (disabled) return { ok: false, reason: 'publish_button_disabled' };
    publish.click();
    return { ok: true };
  })()`);
  if (!result?.ok) throw new CommandExecutionError(`Could not click LinkedIn publish: ${result?.reason || 'unknown'}`);
}

cli({
  site: 'linkedin',
  name: 'post-video',
  access: 'write',
  description: 'Create a LinkedIn feed post with one native video using the logged-in browser session',
  domain: LINKEDIN_DOMAIN,
  strategy: Strategy.UI,
  browser: true,
  args: [
    { name: 'file', required: true, help: 'Local video file path' },
    { name: 'text', help: 'Post text' },
    { name: 'text-file', help: 'Read post text from a UTF-8 file' },
    { name: 'execute', type: 'bool', default: false, help: 'Actually click Publish. Default leaves the prepared post open.' },
  ],
  columns: ['status', 'video_file', 'text_chars', 'upload_via', 'published'],
  func: async (page, args) => {
    if (!page) throw new CommandExecutionError('Browser session required for linkedin post-video');
    const absVideoPath = requireExistingFile(requireStringArg(args, 'file', '--file'), '--file');
    const postText = readPostText(args);
    const videoStats = fs.statSync(absVideoPath);
    if (videoStats.size > 200 * 1024 * 1024) {
      throw new ArgumentError(`Video is too large for this helper fallback: ${(videoStats.size / 1024 / 1024).toFixed(1)} MB`);
    }

    const probe = await openShareComposer(page);
    assertLinkedInPageStatus(probe);

    await openMediaPicker(page);

    let upload = await uploadWithCdp(page, absVideoPath);
    if (!upload.ok) upload = await uploadWithCdpDrop(page, absVideoPath);
    if (!upload.ok) upload = await uploadWithBrowserFile(page, absVideoPath);

    await waitForMediaReady(page, 180);
    await clickMediaNext(page);
    await waitForComposerWithMedia(page, 90);
    await fillPostText(page, postText);
    await waitForPublishEnabled(page, 120);

    if (args.execute) {
      await clickPublish(page);
      await page.wait(5);
      return [{ status: 'published', video_file: path.basename(absVideoPath), text_chars: postText.length, upload_via: upload.via || '', published: true }];
    }

    return [{ status: 'prepared', video_file: path.basename(absVideoPath), text_chars: postText.length, upload_via: upload.via || '', published: false }];
  },
});
