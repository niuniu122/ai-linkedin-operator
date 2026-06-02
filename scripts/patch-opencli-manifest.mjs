import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { fileURLToPath } from 'node:url';

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const openCliDir = path.resolve(process.argv[2] || path.join(repoRoot, 'tool', 'OpenCLI'));
const manifestPath = path.join(openCliDir, 'cli-manifest.json');
const entryPath = path.join(repoRoot, 'tools', 'opencli-overrides', 'manifest', 'linkedin-post-video.json');

if (!fs.existsSync(manifestPath)) {
  throw new Error(`OpenCLI manifest not found: ${manifestPath}`);
}

const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
const entry = JSON.parse(fs.readFileSync(entryPath, 'utf8'));

const existingIndex = manifest.findIndex((item) => item.site === entry.site && item.name === entry.name);
if (existingIndex >= 0) {
  manifest[existingIndex] = entry;
} else {
  const linkedinSafeSendIndex = manifest.findIndex((item) => item.site === 'linkedin' && item.name === 'safe-send');
  const insertAt = linkedinSafeSendIndex >= 0 ? linkedinSafeSendIndex : manifest.length;
  manifest.splice(insertAt, 0, entry);
}

fs.writeFileSync(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`, 'utf8');
console.log(`Patched ${manifestPath}`);
