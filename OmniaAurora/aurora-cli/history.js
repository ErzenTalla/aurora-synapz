import 'dotenv/config';
import { listBriefings, getBriefing, extractBriefingText } from './lib/store.js';

async function main() {
  const date = process.argv[2];

  if (!date) {
    const briefings = await listBriefings();
    if (briefings.length === 0) {
      console.log('No briefings saved yet.');
      return;
    }
    console.log('Saved briefings (most recent first):\n');
    briefings.forEach(({ date }) => console.log(`  ${date}`));
    console.log('\nRun `npm run history -- YYYY-MM-DD` to view one in full.');
    return;
  }

  const content = await getBriefing(date);
  console.log(extractBriefingText(content));
}

main().catch((err) => {
  console.error('aurora-cli history failed:', err.message);
  process.exit(1);
});
