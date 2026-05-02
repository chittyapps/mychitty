-- Migration B — add v1 columns + enum extensions to public.event_ledger
--
-- Source spec: docs/specs/mychitty-v1-light-the-substrate.md §9.3 (CanonicalEvent),
--              §9.4 (SponsorBond), §11.2 (Signing model)
-- Source verification: docs/verification/phase-0/01-ledger-spine.md §8.2
--
-- Target Neon project: ChittyLedger (id shy-sound-75632194, org ChittyFoundation)
-- Verified state pre-migration (2026-05-02):
--   - 224 rows in public.event_ledger
--   - existing columns already cover: id, event_id, event_type, event_severity,
--     service_name, action, chitty_id, scope, canonical_entity_type,
--     parent_chitty_id, prev_hash, event_hash, session_id, group_id, project,
--     metadata, timestamp
--   - missing per spec: signer_cid, signature_proof, payload_hash, payload_ref,
--     bond_id, linked_event_hash, substrate, plane, sequence, occurred_at,
--     canon_version
--
-- This migration is additive only:
--   - new columns are NULL-able with no defaults that would mutate existing rows
--   - existing 224 rows remain valid (legacy v0 events; v1 hash chain begins
--     at the first new write per chitty_id, never backfilled — Axiom Zero §3.2)
--   - enum additions in PostgreSQL are non-blocking and non-rewriting
--
-- Rollback notes:
--   - dropping the columns is straightforward (DROP COLUMN)
--   - enum values cannot be removed in PostgreSQL without recreating the type;
--     downgrade leaves the new enum values in place (harmless if unused)

BEGIN;

-- ---------------------------------------------------------------------------
-- Column additions
-- ---------------------------------------------------------------------------

ALTER TABLE public.event_ledger
  ADD COLUMN IF NOT EXISTS signer_cid        text,
  ADD COLUMN IF NOT EXISTS signature_proof   text,
  ADD COLUMN IF NOT EXISTS signature_alg     text,
  ADD COLUMN IF NOT EXISTS signature_kid     text,
  ADD COLUMN IF NOT EXISTS payload_hash      text,
  ADD COLUMN IF NOT EXISTS payload_ref       text,
  ADD COLUMN IF NOT EXISTS bond_id           text,
  ADD COLUMN IF NOT EXISTS linked_event_hash text,
  ADD COLUMN IF NOT EXISTS substrate         text,
  ADD COLUMN IF NOT EXISTS plane             text,
  ADD COLUMN IF NOT EXISTS sequence          bigint,
  ADD COLUMN IF NOT EXISTS occurred_at       timestamptz,
  ADD COLUMN IF NOT EXISTS canon_version     text;

COMMENT ON COLUMN public.event_ledger.signer_cid IS
  'ChittyID of the entity authorized to sign this event (§11.2)';
COMMENT ON COLUMN public.event_ledger.signature_proof IS
  'Delegated-signing proof (§11.2). Format defined by ChittyConnect signing model';
COMMENT ON COLUMN public.event_ledger.signature_alg IS
  'Signing algorithm (e.g. EdDSA, ES256). NULL for pre-v1 legacy rows';
COMMENT ON COLUMN public.event_ledger.signature_kid IS
  'Key ID / JWKS reference for verification (§11.2)';
COMMENT ON COLUMN public.event_ledger.payload_hash IS
  'SHA-256 of the canonical payload, separate from event_hash. Allows hashed-only sensitive content (§9.3)';
COMMENT ON COLUMN public.event_ledger.payload_ref IS
  'Optional R2/blob URL for offloaded payload bodies (§9.3)';
COMMENT ON COLUMN public.event_ledger.bond_id IS
  'Sponsor bond linkage; required for bonded actions (§9.4, §10.5)';
COMMENT ON COLUMN public.event_ledger.linked_event_hash IS
  'Cross-link hash to the paired entry in a bonded dual-write (§10.5)';
COMMENT ON COLUMN public.event_ledger.substrate IS
  'Substrate of origin: claude_code | openclaw | chatgpt | chitty_cli | system (§9.1)';
COMMENT ON COLUMN public.event_ledger.plane IS
  'Plane of action: digital | legal | physical. v1 is digital-only (§9.1, §11.3)';
COMMENT ON COLUMN public.event_ledger.sequence IS
  'Per-(chitty_id, scope) monotonic sequence number; populated by gateway at write time';
COMMENT ON COLUMN public.event_ledger.occurred_at IS
  'When the event actually happened on the substrate; distinct from timestamp (received_at)';
COMMENT ON COLUMN public.event_ledger.canon_version IS
  'Canonical-event schema version (e.g. "1.0"). Enables future format evolution';

-- ---------------------------------------------------------------------------
-- Constraints (additive)
-- ---------------------------------------------------------------------------

ALTER TABLE public.event_ledger
  ADD CONSTRAINT event_ledger_substrate_check
    CHECK (substrate IS NULL OR substrate IN ('claude_code','openclaw','chatgpt','chitty_cli','system'));

ALTER TABLE public.event_ledger
  ADD CONSTRAINT event_ledger_plane_check
    CHECK (plane IS NULL OR plane IN ('digital','legal','physical'));

-- bonded events require both bond_id and linked_event_hash to be present together
ALTER TABLE public.event_ledger
  ADD CONSTRAINT event_ledger_bond_link_pair
    CHECK (
      (bond_id IS NULL AND linked_event_hash IS NULL)
      OR (bond_id IS NOT NULL AND linked_event_hash IS NOT NULL)
    );

-- ---------------------------------------------------------------------------
-- Indexes (partial, only where useful)
-- ---------------------------------------------------------------------------

CREATE INDEX IF NOT EXISTS idx_event_ledger_substrate
  ON public.event_ledger (substrate)
  WHERE substrate IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_event_ledger_bond_id
  ON public.event_ledger (bond_id)
  WHERE bond_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_event_ledger_signer_cid
  ON public.event_ledger (signer_cid)
  WHERE signer_cid IS NOT NULL;

-- supports per-chain replay: WHERE chitty_id = $1 AND scope = $2 ORDER BY sequence
CREATE INDEX IF NOT EXISTS idx_event_ledger_chain_replay
  ON public.event_ledger (chitty_id, scope, sequence)
  WHERE sequence IS NOT NULL;

-- ---------------------------------------------------------------------------
-- Enum extensions (additive, safe in PostgreSQL)
-- ---------------------------------------------------------------------------

-- Spec §9.3 CanonicalEventType values not present in the existing event_type enum
-- (existing covers: USER_ACTION, SYSTEM_EVENT, API_CALL, SERVICE_INTERACTION, ERROR,
--  SECURITY, AUDIT, INTEGRATION, SESSION_INGEST, ENTITY_CREATED, ENTITY_FISSION,
--  ENTITY_FUSION, ENTITY_SUSPENSION, ENTITY_RETIREMENT, ENTITY_REWARMING,
--  SESSION_START, SESSION_END, SESSION_MERGE, TOOL_CALL, ROUTING_DECISION,
--  LIFECYCLE_SIGNAL, TRUST_OBSERVATION, ALCHEMIST_PROPOSAL, CHANNEL_REGISTERED)

ALTER TYPE public.event_type ADD VALUE IF NOT EXISTS 'INTERACTION_OBSERVED';
ALTER TYPE public.event_type ADD VALUE IF NOT EXISTS 'DECISION_COMMITTED';
ALTER TYPE public.event_type ADD VALUE IF NOT EXISTS 'ACTION_REQUESTED';
ALTER TYPE public.event_type ADD VALUE IF NOT EXISTS 'ACTION_EXECUTED';
ALTER TYPE public.event_type ADD VALUE IF NOT EXISTS 'BONDED_ACTION_REQUESTED';
ALTER TYPE public.event_type ADD VALUE IF NOT EXISTS 'BONDED_ACTION_EXECUTED';
ALTER TYPE public.event_type ADD VALUE IF NOT EXISTS 'SPONSOR_BOND_CREATED';
ALTER TYPE public.event_type ADD VALUE IF NOT EXISTS 'SPONSOR_BOND_SEVERED';
ALTER TYPE public.event_type ADD VALUE IF NOT EXISTS 'SYNTHESIS_COMPLETED';
ALTER TYPE public.event_type ADD VALUE IF NOT EXISTS 'SURFACE_PACK_READ';
ALTER TYPE public.event_type ADD VALUE IF NOT EXISTS 'MIRROR_EXPORTED';
ALTER TYPE public.event_type ADD VALUE IF NOT EXISTS 'AUTHORITY_UPDATED';

COMMIT;

-- Verification (run after apply):
--
-- 1. New columns present:
--   SELECT column_name FROM information_schema.columns
--   WHERE table_schema='public' AND table_name='event_ledger'
--     AND column_name IN ('signer_cid','signature_proof','signature_alg','signature_kid',
--                         'payload_hash','payload_ref','bond_id','linked_event_hash',
--                         'substrate','plane','sequence','occurred_at','canon_version')
--   ORDER BY column_name;
-- Expected: 13 rows.
--
-- 2. New enum values present:
--   SELECT enumlabel FROM pg_enum
--   WHERE enumtypid = 'public.event_type'::regtype
--     AND enumlabel IN ('INTERACTION_OBSERVED','DECISION_COMMITTED','ACTION_REQUESTED',
--                       'ACTION_EXECUTED','BONDED_ACTION_REQUESTED','BONDED_ACTION_EXECUTED',
--                       'SPONSOR_BOND_CREATED','SPONSOR_BOND_SEVERED','SYNTHESIS_COMPLETED',
--                       'SURFACE_PACK_READ','MIRROR_EXPORTED','AUTHORITY_UPDATED')
--   ORDER BY enumlabel;
-- Expected: 12 rows.
--
-- 3. Existing rows still queryable:
--   SELECT COUNT(*) FROM public.event_ledger;
-- Expected: 224 (unchanged).
--
-- 4. CHECK constraints registered:
--   SELECT conname FROM pg_constraint
--   WHERE conrelid = 'public.event_ledger'::regclass AND contype = 'c'
--   ORDER BY conname;
-- Expected: includes event_ledger_substrate_check, event_ledger_plane_check,
--           event_ledger_bond_link_pair (plus pre-existing canonical_entity_type_check, scope_check)
