require('dotenv').config();
const app   = require('./app');
const setup = require('./db/setup');

const PORT = process.env.PORT || 3000;

async function start() {
  await setup();
  app.listen(PORT, () => {
    console.log(`\n  Aurora Synapz running → http://localhost:${PORT}`);
    console.log(`  Portal login         → http://localhost:${PORT}/login.html`);
    console.log(`  Demo credentials     → demo@aurorasyanapz.com / Demo1234!\n`);
  });
}

start().catch(console.error);
