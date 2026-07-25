import * as dotenv from 'dotenv';
import { fetchGatewayLogs } from './poll-logs';
import { transformLogToEvent } from './transform';

// Load environment variables if .env is present
dotenv.config();

const ACCOUNT_ID = process.env.CF_ACCOUNT_ID || '0bc21e3a5a9de1a4cc843be9c3e98121';
const GATEWAY_ID = process.env.CF_GATEWAY_ID || 'chittyclaw';
const TOKEN = process.env.chittyclaw_ai_gateway_api_token;

async function run() {
  if (!TOKEN) {
    console.error('Error: chittyclaw_ai_gateway_api_token environment variable is not set.');
    process.exit(1);
  }

  try {
    console.error(`Fetching logs for AI Gateway: ${GATEWAY_ID}...`);
    const logs = await fetchGatewayLogs(ACCOUNT_ID, GATEWAY_ID, TOKEN);
    
    if (logs.length === 0) {
      console.error('No logs found.');
      return;
    }

    console.error(`Fetched ${logs.length} logs. Transforming to CanonicalEvent...`);
    
    for (const log of logs) {
      const canonicalEvent = transformLogToEvent(log);
      // Emit NDJSON to stdout
      console.log(JSON.stringify(canonicalEvent));
    }
    
    console.error('Dry-run completed successfully.');
  } catch (err) {
    console.error('Dry-run failed:', err);
    process.exit(1);
  }
}

run();
