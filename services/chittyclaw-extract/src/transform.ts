import * as crypto from 'crypto';

function sha256(data: string): string {
  return crypto.createHash('sha256').update(data).digest('hex');
}

export function transformLogToEvent(logEntry: any): any {
  // Extract custom metadata provided by cf-aig-metadata header
  const metadata = logEntry.metadata || {};
  
  const chittyId = metadata.chitty_id || 'unknown-chitty-id';
  const substrate = metadata.substrate || 'openclaw';
  const sessionId = metadata.session_id || 'unknown-session-id';
  
  // Create a minimal payload representation
  const payloadMin = {
    request: logEntry.request_contentType === 'application/json' && typeof logEntry.request_body === 'string' ? JSON.parse(logEntry.request_body) : logEntry.request_body,
    response: logEntry.response_contentType === 'application/json' && typeof logEntry.response_body === 'string' ? JSON.parse(logEntry.response_body) : logEntry.response_body,
    model: logEntry.model,
    provider: logEntry.provider,
  };
  
  const payloadHash = sha256(JSON.stringify(payloadMin));
  
  // Construct the CanonicalEvent shape per mychitty-v1-light-the-substrate.md §9.3
  const canonicalEvent = {
    event_id: `ext_${logEntry.id || crypto.randomUUID()}`,
    entity_cid: chittyId,
    session_id: sessionId,
    event_type: "interaction.observed", // Default type for model interactions
    substrate: substrate,
    plane: "digital",
    occurred_at: logEntry.created_at || new Date().toISOString(),
    received_at: new Date().toISOString(),
    sequence: 0, // Will be allocated by the gateway proper later
    prev_hash: null, // Deferred to Phase 1 proper
    event_hash: null, // Deferred to Phase 1 proper
    signer_cid: null, // Deferred to Phase 1 proper
    signature_proof: null, // Deferred to Phase 1 proper
    raw_event_id: logEntry.id,
    payload_hash: payloadHash,
    payload_ref: undefined,
    payload_min: payloadMin,
    canon_version: "1.0"
  };
  
  return canonicalEvent;
}
