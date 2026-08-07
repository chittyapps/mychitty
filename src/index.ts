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

    // /whoami is intentionally absent FOR NOW. It is meant to come back — as a
    // real consumer call. Read this before reinstating it.
    //
    // MyChitty IS the front door. It is the identity experience for both humans
    // and AI clients, and that is its job. What it is NOT is the protocol
    // authority.
    //
    //   front door      -> mychitty          (experience: human + AI)
    //   protocol authority -> auth.chitty.cc (OAuth/OIDC/JWKS)
    //   identity        -> id.chitty.cc
    //   PKI registry    -> cert.chitty.cc    (canonical JWKS per D7)
    //   events          -> ChittyLedger
    //
    // So MyChitty consumes ChittyAuth exactly the way it consumes ChittyID and
    // ChittyLedger. Concretely: `api.mychitty.com` must NOT become a second
    // identity anchor. Serving identity here instead of proxying to the
    // authority is the specific mistake this comment exists to prevent —
    // ChittyAuth and ChittyCert were both gutted and pointed at
    // `api.mychitty.com/whoami`, a host that did not resolve, and the whole
    // auth plane was down until 2026-07-25.
    //
    // The previous implementation returned a hardcoded ChittyID, a fabricated
    // service token and a truncated placeholder certificate. That is fake auth
    // material and must not exist in the tree.
    //
    // Reinstate as: front-door UX over a real ChittyAuth call, validated
    // end-to-end against the live service. Never as locally-minted identity.

    return new Response('Not Found', { status: 404 });
  }
};
