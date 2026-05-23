#!/usr/bin/env node
// Migration runner — reads connection string from env file, NOT from CLI args.
// Usage: node run_migration.js <sql_file_path> [--verify] [--behavioral-test]
//
// Connection source priority:
//   1. NEON_MIGRATION_CONN env var (if explicitly set for this session)
//   2. NEON_CONNECTION_STRING from /home/ubuntu/.config/ai-parity.env

'use strict';

const fs = require('fs');
const path = require('path');
const { Client } = require('pg');

function loadEnvFile(filePath) {
  try {
    const content = fs.readFileSync(filePath, 'utf8');
    const env = {};
    for (const line of content.split('\n')) {
      const trimmed = line.trim();
      if (!trimmed || trimmed.startsWith('#')) continue;
      const idx = trimmed.indexOf('=');
      if (idx < 0) continue;
      const key = trimmed.slice(0, idx).trim();
      const val = trimmed.slice(idx + 1).trim();
      env[key] = val;
    }
    return env;
  } catch (e) {
    return {};
  }
}

function getConnectionString() {
  if (process.env.NEON_MIGRATION_CONN) return process.env.NEON_MIGRATION_CONN;
  const envFile = loadEnvFile('/home/ubuntu/.config/ai-parity.env');
  if (envFile.NEON_CONNECTION_STRING) return envFile.NEON_CONNECTION_STRING;
  throw new Error('No connection string found. Set NEON_MIGRATION_CONN or ensure ai-parity.env has NEON_CONNECTION_STRING');
}

async function runSQL(client, sql, label) {
  console.log(`\n--- ${label} ---`);
  try {
    const result = await client.query(sql);
    // result may be array if multiple statements
    const rows = Array.isArray(result) ? result : [result];
    for (const r of rows) {
      if (r.rows && r.rows.length > 0) {
        console.log(JSON.stringify(r.rows, null, 2));
      } else if (r.command) {
        console.log(`Command: ${r.command}, rowCount: ${r.rowCount}`);
      }
    }
    return { ok: true, result };
  } catch (e) {
    console.error(`ERROR: ${e.message}`);
    return { ok: false, error: e.message };
  }
}

async function main() {
  const args = process.argv.slice(2);
  const mode = args[0];

  const connStr = getConnectionString();
  // Use unpooled endpoint for DDL (replace -pooler in hostname if present, unless already direct)
  const directConn = connStr.replace(/-pooler\./, '.');

  console.log(`Connecting to Neon (direct/unpooled endpoint for DDL)...`);
  const client = new Client({ connectionString: directConn, ssl: { rejectUnauthorized: false } });
  await client.connect();

  // Confirm which DB we are on
  const dbCheck = await client.query('SELECT current_database() AS db, pg_postmaster_start_time() AS started');
  console.log(`Connected to DB: ${dbCheck.rows[0].db}`);

  if (mode === '--verify') {
    // Run all 6 verification checks
    console.log('\n=== VERIFICATION SUITE ===\n');

    const checks = [
      {
        label: 'V1: New columns count (expect 13)',
        sql: `SELECT COUNT(*) AS count FROM information_schema.columns
              WHERE table_schema='public' AND table_name='event_ledger'
                AND column_name IN ('signer_cid','signature_proof','signature_alg','signature_kid',
                                    'payload_hash','payload_ref','bond_id','linked_event_hash',
                                    'substrate','plane','sequence','occurred_at','canon_version');`
      },
      {
        label: 'V2: New enum values count (expect 12)',
        sql: `SELECT COUNT(*) AS count FROM pg_enum
              WHERE enumtypid = 'public.event_type'::regtype
                AND enumlabel IN ('INTERACTION_OBSERVED','DECISION_COMMITTED','ACTION_REQUESTED',
                                  'ACTION_EXECUTED','BONDED_ACTION_REQUESTED','BONDED_ACTION_EXECUTED',
                                  'SPONSOR_BOND_CREATED','SPONSOR_BOND_SEVERED','SYNTHESIS_COMPLETED',
                                  'SURFACE_PACK_READ','MIRROR_EXPORTED','AUTHORITY_UPDATED');`
      },
      {
        label: 'V3: New CHECK constraints (expect 3)',
        sql: `SELECT COUNT(*) AS count FROM pg_constraint
              WHERE conrelid = 'public.event_ledger'::regclass AND contype = 'c'
                AND conname IN ('event_ledger_substrate_check','event_ledger_plane_check','event_ledger_bond_link_pair');`
      },
      {
        label: 'V4: New partial indexes (expect 4)',
        sql: `SELECT COUNT(*) AS count FROM pg_indexes
              WHERE tablename = 'event_ledger' AND schemaname = 'public'
                AND indexname IN ('idx_event_ledger_substrate','idx_event_ledger_bond_id',
                                  'idx_event_ledger_signer_cid','idx_event_ledger_chain_replay');`
      },
      {
        label: 'V5: Append-only triggers (expect 2)',
        sql: `SELECT COUNT(*) AS count FROM pg_trigger
              WHERE tgrelid = 'public.event_ledger'::regclass AND NOT tgisinternal
                AND tgname IN ('event_ledger_block_update','event_ledger_block_delete');`
      },
      {
        label: 'V6: Row count (pre vs post stored separately)',
        sql: `SELECT COUNT(*) AS total_rows FROM public.event_ledger;`
      }
    ];

    const results = [];
    for (const check of checks) {
      const r = await client.query(check.sql);
      const val = r.rows[0];
      console.log(`${check.label}: ${JSON.stringify(val)}`);
      results.push({ label: check.label, value: val });
    }

    await client.end();
    return;
  }

  if (mode === '--behavioral-test') {
    console.log('\n=== BEHAVIORAL TESTS ===\n');

    // Test 1: UPDATE should fail
    console.log('Test 1: UPDATE should raise append-only error...');
    try {
      await client.query(`UPDATE public.event_ledger SET action='_test_' WHERE id = (SELECT id FROM public.event_ledger LIMIT 1);`);
      console.log('FAIL: UPDATE succeeded (trigger not working!)');
    } catch (e) {
      if (e.message.includes('append-only')) {
        console.log(`PASS: UPDATE blocked with: ${e.message}`);
      } else {
        console.log(`UNEXPECTED ERROR: ${e.message}`);
      }
    }

    // Test 2: DELETE should fail
    console.log('\nTest 2: DELETE should raise append-only error...');
    try {
      await client.query(`DELETE FROM public.event_ledger WHERE id = (SELECT id FROM public.event_ledger LIMIT 1);`);
      console.log('FAIL: DELETE succeeded (trigger not working!)');
    } catch (e) {
      if (e.message.includes('append-only')) {
        console.log(`PASS: DELETE blocked with: ${e.message}`);
      } else {
        console.log(`UNEXPECTED ERROR: ${e.message}`);
      }
    }

    // Test 3: INSERT should succeed (benign test row)
    console.log('\nTest 3: INSERT should succeed...');
    try {
      const r = await client.query(`
        INSERT INTO public.event_ledger (event_type, service_name, action, chitty_id, scope)
        VALUES ('AUDIT', 'chitty-neon-platform-integrator', 'migration_apply_verify', 'sys-migration-probe', 'platform')
        RETURNING id, event_type, action;
      `);
      console.log(`PASS: INSERT succeeded — row id=${r.rows[0].id}, event_type=${r.rows[0].event_type}`);
      // Leave the row in place — it is a legitimate audit event
    } catch (e) {
      console.log(`FAIL: INSERT failed with: ${e.message}`);
    }

    await client.end();
    return;
  }

  // Default mode: apply a SQL file
  if (!mode || mode.startsWith('--')) {
    console.error('Usage: node run_migration.js <sql_file> [--verify] [--behavioral-test]');
    process.exit(1);
  }

  const sqlFile = path.resolve(mode);
  if (!fs.existsSync(sqlFile)) {
    console.error(`SQL file not found: ${sqlFile}`);
    process.exit(1);
  }

  const sql = fs.readFileSync(sqlFile, 'utf8');
  console.log(`\nApplying: ${path.basename(sqlFile)}`);
  console.log(`SQL length: ${sql.length} bytes`);

  // Check if migration contains ALTER TYPE ADD VALUE (cannot be in a transaction in some PG versions)
  const hasAlterTypeAddValue = /ALTER\s+TYPE\s+.*ADD\s+VALUE/i.test(sql);
  if (hasAlterTypeAddValue) {
    console.log('NOTE: Migration contains ALTER TYPE ADD VALUE — these run outside of explicit transactions in PG 17.');
    // Run the whole file as-is; PG 17 supports it inside a BEGIN block as long as the new values
    // are not used in the same transaction.
  }

  await runSQL(client, sql, 'migration apply');

  await client.end();
  console.log('\nDone.');
}

main().catch(e => {
  console.error('Fatal:', e.message);
  process.exit(1);
});
