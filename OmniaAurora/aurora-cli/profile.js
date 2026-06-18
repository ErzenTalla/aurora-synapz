import 'dotenv/config';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { getProfile, saveProfile } from './lib/store.js';

const ROOT = path.resolve(import.meta.dirname, '..');
const LOCAL_PROFILE_PATH = path.join(ROOT, 'context', 'profile.md');

async function main() {
  const current = await getProfile();

  if (process.argv[2] === '--print') {
    console.log(current);
    return;
  }

  const tmpPath = path.join(os.tmpdir(), `aurora-profile-${Date.now()}.md`);
  fs.writeFileSync(tmpPath, current);

  const editor = process.env.EDITOR || 'vi';
  const result = spawnSync(editor, [tmpPath], { stdio: 'inherit' });
  if (result.status !== 0) {
    console.error(`Editor exited with an error — profile not saved.`);
    fs.unlinkSync(tmpPath);
    process.exit(1);
  }

  const updated = fs.readFileSync(tmpPath, 'utf-8');
  fs.unlinkSync(tmpPath);

  if (updated === current) {
    console.log('No changes made.');
    return;
  }

  await saveProfile(updated);
  fs.writeFileSync(LOCAL_PROFILE_PATH, updated);
  console.log(`Profile updated — synced to Blob and ${LOCAL_PROFILE_PATH}`);
}

main().catch((err) => {
  console.error('aurora-cli profile failed:', err.message);
  process.exit(1);
});
