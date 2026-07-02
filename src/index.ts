export interface Env {}

export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    const url = new URL(request.url);
    const path = url.pathname;

    if (request.method === 'OPTIONS') {
      return new Response(null, {
        headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
          'Access-Control-Allow-Headers': 'Content-Type, Authorization',
        }
      });
    }

    if (path === '/health') {
      return new Response('OK', { status: 200 });
    }

    if (path === '/whoami') {
      const payload = {
        entity: {
          chitty_id: "03-1-USA-7087-A-2607-0-35",
          role: "SessionCoordinator",
          status: "ACTIVE"
        },
        auth: {
          chittyconnect_token: "chitty_sk_cluster_local_99x",
          sovereignty_cert: "-----BEGIN CERTIFICATE-----\nMIIDdD...\n-----END CERTIFICATE-----"
        },
        state: {
          active_context_id: "7259d24b-bbba-4b58-a95e-a4337b0f2422",
          last_memory_flush: new Date().toISOString()
        }
      };

      return Response.json(payload, {
        headers: {
          'Access-Control-Allow-Origin': '*',
          'Content-Type': 'application/json'
        }
      });
    }

    return new Response('Not Found', { status: 404 });
  }
};
