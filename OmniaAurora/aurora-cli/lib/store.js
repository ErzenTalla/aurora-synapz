import fs from 'node:fs';
import path from 'node:path';
import { put, get, list } from '@vercel/blob';

const PROFILE_PATHNAME = 'profile.md';
const BRIEFINGS_PREFIX = 'daily-briefings/';

function findProfileSeedPath() {
  const candidates = [
    path.join(process.cwd(), 'context', 'profile.md'),
    path.resolve(import.meta.dirname, '..', '..', 'context', 'profile.md'),
  ];
  return candidates.find((p) => fs.existsSync(p)) || candidates[0];
}

// Public blobs are always served from CDN cache with no way to bypass it
// (useCache is "ignored for public blobs" per the SDK) — read-after-write was
// returning stale content. Private blobs + useCache:false fetch straight from
// origin storage every time, and it's the more appropriate access level for
// personal data anyway (profile, tasks, notes — none of this should be a
// guessable public URL).
async function readBlobText(pathname) {
  const result = await get(pathname, { access: 'private', useCache: false });
  if (!result) return null;
  return await new Response(result.stream).text();
}

async function writeBlob(pathname, content, contentType) {
  await put(pathname, content, {
    access: 'private',
    addRandomSuffix: false,
    allowOverwrite: true,
    contentType,
  });
}

export async function getProfile() {
  const text = await readBlobText(PROFILE_PATHNAME);
  if (text !== null) return text;
  const seed = fs.readFileSync(findProfileSeedPath(), 'utf-8');
  await saveProfile(seed);
  return seed;
}

export async function saveProfile(content) {
  await writeBlob(PROFILE_PATHNAME, content, 'text/markdown');
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
  const text = await readBlobText(`${BRIEFINGS_PREFIX}${date}.md`);
  if (text === null) throw new Error(`No briefing found for ${date}`);
  return text;
}

export function extractBriefingText(savedFileContent) {
  const marker = '## Briefing\n';
  const index = savedFileContent.indexOf(marker);
  return index === -1 ? savedFileContent.trim() : savedFileContent.slice(index + marker.length).trim();
}

export async function saveBriefing(date, content) {
  await writeBlob(`${BRIEFINGS_PREFIX}${date}.md`, content, 'text/markdown');
}

export async function getJSON(pathname, fallback) {
  const text = await readBlobText(pathname);
  if (text !== null) return JSON.parse(text);
  await saveJSON(pathname, fallback);
  return fallback;
}

export async function saveJSON(pathname, data) {
  await writeBlob(pathname, JSON.stringify(data, null, 2), 'application/json');
}

export async function getTrackedContext() {
  const [{ tasks }, { notes }, { facts }] = await Promise.all([
    getJSON('tasks.json', { tasks: [] }),
    getJSON('notes.json', { notes: [] }),
    getJSON('knowledge.json', { facts: [] }),
  ]);
  return { tasks, notes, facts };
}
