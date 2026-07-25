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

    // /whoami is intentionally absent.
    //
    // MyChitty is a CONSUMER of the identity plane — ChittyAuth (auth.chitty.cc)
    // for tokens/JWKS, ChittyID (id.chitty.cc) for identity, ChittyCert
    // (cert.chitty.cc) for the canonical JWKS registry per D7, ChittyLedger for
    // events. It is not a substitute for any of them.
    //
    // The previous implementation returned a hardcoded ChittyID, a fabricated
    // service token and a truncated placeholder certificate. That is fake auth
    // material and must not exist in the tree. Reinstate this route only as a
    // real consumer call against a live ChittyAuth, validated end-to-end.

    return new Response('Not Found', { status: 404 });
  }
};
