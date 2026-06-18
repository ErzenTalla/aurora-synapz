import fs from 'node:fs';
import path from 'node:path';
import { put, head, list, BlobNotFoundError } from '@vercel/blob';

const PROFILE_PATHNAME = 'profile.md';
const BRIEFINGS_PREFIX = 'daily-briefings/';

function findProfileSeedPath() {
  const candidates = [
    path.join(process.cwd(), 'context', 'profile.md'),
    path.resolve(import.meta.dirname, '..', '..', 'context', 'profile.md'),
  ];
  return candidates.find((p) => fs.existsSync(p)) || candidates[0];
}

export async function getProfile() {
  try {
    const meta = await head(PROFILE_PATHNAME);
    const res = await fetch(meta.url);
    return await res.text();
  } catch (err) {
    if (!(err instanceof BlobNotFoundError)) throw err;
    const seed = fs.readFileSync(findProfileSeedPath(), 'utf-8');
    await saveProfile(seed);
    return seed;
  }
}

export async function saveProfile(content) {
  await put(PROFILE_PATHNAME, content, {
    access: 'public',
    addRandomSuffix: false,
    allowOverwrite: true,
    contentType: 'text/markdown',
  });
}

export async function listBriefings() {
  const { blobs } = await list({ prefix: BRIEFINGS_PREFIX });
  return blobs
    .map((blob) => ({
      date: blob.pathname.slice(BRIEFINGS_PREFIX.length).replace(/\.md$/, ''),
      url: blob.url,
    }))
    .sort((a, b) => b.date.localeCompare(a.date));
}

export async function getBriefing(date) {
  const meta = await head(`${BRIEFINGS_PREFIX}${date}.md`);
  const res = await fetch(meta.url);
  return await res.text();
}

export function extractBriefingText(savedFileContent) {
  const marker = '## Briefing\n';
  const index = savedFileContent.indexOf(marker);
  return index === -1 ? savedFileContent.trim() : savedFileContent.slice(index + marker.length).trim();
}

export async function saveBriefing(date, content) {
  await put(`${BRIEFINGS_PREFIX}${date}.md`, content, {
    access: 'public',
    addRandomSuffix: false,
    allowOverwrite: true,
    contentType: 'text/markdown',
  });
}
