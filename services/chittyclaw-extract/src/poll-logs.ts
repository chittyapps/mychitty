import * as https from 'https';

export async function fetchGatewayLogs(accountId: string, gatewayId: string, token: string): Promise<any[]> {
  const url = `https://api.cloudflare.com/client/v4/accounts/${accountId}/ai-gateway/gateways/${gatewayId}/logs`;

  return new Promise((resolve, reject) => {
    const req = https.get(url, {
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json',
      }
    }, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        if (res.statusCode && res.statusCode >= 400) {
          return reject(new Error(`CF API Error: ${res.statusCode} ${data}`));
        }
        try {
          const parsed = JSON.parse(data);
          resolve(parsed.result || []);
        } catch (err) {
          reject(new Error(`Failed to parse CF API response: ${err}`));
        }
      });
    });

    req.on('error', reject);
    req.end();
  });
}
