---
name: solana-transaction-expert
description: Deep Solana transaction knowledge for debugging tx failures, understanding send methods, interpreting landing rates, error categories, and transaction lifecycle. Use when working on Heimdall's transaction sending, confirmation, or result analysis.
user-invocable: true
---

# Solana Transaction Expert

Complete transaction lifecycle knowledge — from construction through confirmation — tuned for Heimdall's multi-provider benchmarking system.

## When to Use This Skill

- Debugging transaction failures or unexpected error categories
- Adding or modifying send methods in `sender/src/rpc.rs`
- Interpreting landing rates, slot deltas, or error distributions
- Working on transaction construction in `dispatch_service.rs`
- Understanding confirmation polling in `polling_service.rs`
- Analyzing why one provider lands transactions faster than another
- Working with Jito bundles, BloxRoute, or other MEV-aware submission

## Transaction Lifecycle

```
  dispatch_service.rs          sender/             RPC Provider        Solana
  ─────────────────          ──────────           ────────────        ──────
        │                        │                      │                │
   Build Tx                      │                      │                │
   (CU limit,                    │                      │                │
    priority fee,                │                      │                │
    tip transfer,                │                      │                │
    record_benchmark ix)         │                      │                │
        │                        │                      │                │
   Sign & Serialize              │                      │                │
        │                        │                      │                │
   Publish to RabbitMQ ────────► │                      │                │
   (EXCHANGE_DISPATCH,           │                      │                │
    routing_key=region_id)       │                      │                │
                                 │                      │                │
                            Consume msg                 │                │
                                 │                      │                │
                            send_transaction ─────────► │                │
                            (method-specific)           │                │
                                 │                  Forward ───────────► │
                                 │                  via QUIC             │
                                 │                      │          TPU Pipeline
                                 │                      │          (SigVerify →
                                 │                      │           Banking →
                                 │                      │           Broadcast)
                                 │                      │                │
                            Publish result ◄─── 200 OK (signature)      │
                            to EXCHANGE_RESULTS         │                │
                                 │                      │                │
  polling_service.rs             │                      │                │
  ──────────────────             │                      │                │
        │                        │                      │                │
   getSignatureStatuses ───────────────────────────────►│                │
   (poll loop, 2s interval)     │                      │                │
        │                       │                      │                │
   Status = confirmed? ◄────────────────────────────────│                │
        │ yes                   │                      │                │
   getTransaction ──────────────────────────────────────►                │
   (get landed_slot,            │                      │                │
    block_time)                 │                      │                │
        │                       │                      │                │
   Update DB: Landed            │                      │                │
```

## Transaction Anatomy

| Component | Size | Description |
|-----------|------|-------------|
| Header | 3 bytes | `num_required_signatures`, `num_readonly_signed`, `num_readonly_unsigned` |
| Signatures | 64 bytes each | Ed25519 signatures (1 for Heimdall — single signer) |
| Account keys | 32 bytes each | All accounts referenced by instructions |
| Recent blockhash | 32 bytes | Expires after ~150 blocks (~60s) |
| Instructions | Variable | Compact array of `(program_id_index, account_indices, data)` |
| **Total MTU** | **1232 bytes** | Hard limit for UDP/QUIC packet; larger txs are rejected |

### Heimdall Transaction Structure

Each benchmark transaction contains these instructions (built in `dispatch_service.rs`):

1. `set_compute_unit_price(priority_fee)` — priority fee in microlamports/CU
2. `set_compute_unit_limit(50_000)` — CU cap for the transaction
3. `record_benchmark(...)` — Heimdall's on-chain program instruction
4. `system_instruction::transfer(tip)` — optional, only if `tip_lamports > 0` and provider has a tip account

## Legacy vs Versioned Transactions (v0)

| Feature | Legacy | Versioned (v0) |
|---------|--------|----------------|
| Format | No version prefix | `0x80` prefix byte |
| Address Lookup Tables | No | Yes — fits more accounts in 1232 bytes |
| Account key limit | ~35 accounts | ~256 via ALTs |
| Heimdall usage | **Yes** | Not currently used |

Heimdall uses legacy transactions — benchmark txs reference few accounts (payer, program, benchmark PDA, tip account) so ALTs are unnecessary.

## Compute Budget & Priority Fees

### How Heimdall Sets Fees

```rust
// dispatch_service.rs — per transaction
let priority_fee = (i as u64) + 1;  // index-based, ascending

// Instructions added:
ComputeBudgetInstruction::set_compute_unit_price(priority_fee)  // microlamports/CU
ComputeBudgetInstruction::set_compute_unit_limit(50_000)         // CU cap
```

| Parameter | Value | Why |
|-----------|-------|-----|
| CU limit | 50,000 | Enough for `record_benchmark` + tip transfer; conservatively set |
| Priority fee | `(tx_index + 1)` | 1, 2, 3... microlamports/CU — unique per tx, deterministic ordering |
| Base fee | 5,000 lamports | Standard Solana base fee (automatic) |
| Actual priority cost | `priority_fee * 50,000` microlamports | At fee=1: 50,000 microlamports = 0.00005 lamports (negligible) |

**Why ascending fees**: Each transaction gets a unique priority, preventing same-fee ordering ambiguity in the banking stage. The fees are deliberately tiny — the benchmark measures provider speed, not fee bidding power.

### Priority Fee Economics

| Fee (microlamports/CU) | Cost per tx (50K CU) | Use Case |
|------------------------|---------------------|----------|
| 1 | 0.00005 lamports | Heimdall benchmark (minimum unique fee) |
| 1,000 | 0.05 lamports | Low-priority DeFi |
| 100,000 | 5 lamports | Normal DeFi arbitrage |
| 10,000,000 | 500 lamports | High-priority MEV |

## Send Methods

Heimdall supports multiple send methods, dispatched in `sender/src/rpc.rs`:

| Method | Function | URL Transform | Encoding | Special Headers/Params |
|--------|----------|--------------|----------|----------------------|
| `"standard"` | Uses provider's own `sendTransaction` endpoint | None | Base64 | `skipPreflight: true` |
| `"jito"` | `send_jito()` | Optional `?bundleOnly=true` if `revertProtection` feature | Base64 | `skipPreflight: true` |
| `"jito_bundle"` | `send_jito_bundle()` | Appends `/api/v1/bundles` to path | Base64 | `sendBundle` RPC method, double-array wrapping |
| `"bloxroute"` | `send_bloxroute()` | Rewrites path to `/api/v2/submit` | bs58 | REST body with feature flags |

### Standard RPC (`send_standard_rpc`)

```
POST {rpc_url}
Content-Type: application/json

{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "sendTransaction",
  "params": [
    "<base64-encoded-tx>",
    { "encoding": "base64", "skipPreflight": true }
  ]
}
```

`skipPreflight: true` — skips simulation on the RPC node, reducing latency. Heimdall doesn't need preflight since benchmark txs are known-valid.

### Jito Submission

Two modes:

1. **`send_jito`** — Standard `sendTransaction` but through Jito's block engine.
   - If provider has `revertProtection` feature, appends `?bundleOnly=true` to the URL.
   - Jito forwards to its own validators (Jito-staked leaders) with MEV protection.

2. **`send_jito_bundle`** — Bundles API at `/api/v1/bundles`.
   - Wraps single tx as `[[base64_tx]]` (double array).
   - Atomic: bundle either fully lands or doesn't.
   - Only lands on Jito-staked leader slots (~20-25% of slots).

### BloxRoute Submission

```
POST {base_url}/api/v2/submit
Content-Type: application/json

{
  "transaction": { "content": "<bs58-encoded-tx>" },
  "frontRunningProtection": true/false,
  "revertProtection": true/false,
  "useStakedRPCs": true/false,
  "fastBestEffort": true
}
```

- Uses bs58 encoding (not base64).
- Feature flags from provider config: `frontRunningProtection`, `revertProtection`, `useStakedRPCs`.
- `fastBestEffort: true` always set — trades protection guarantees for speed.

## MEV & Jito

| Concept | Description | Heimdall Relevance |
|---------|-------------|-------------------|
| Tip accounts | 8 Jito tip accounts; tx includes transfer instruction | `dispatch_service.rs` appends `system_instruction::transfer` if tip > 0 |
| Tip amount | Per-provider config: `min_tip_lamports` / `max_tip_lamports` | Validated in `benchmark_service.rs` `create_benchmark` |
| Bundles | Atomic tx groups; all-or-nothing inclusion | `send_jito_bundle` wraps single tx as bundle |
| Revert protection | Failed txs not included in block (no fee charged) | `bundleOnly=true` param in Jito, feature flag in BloxRoute |
| Front-running protection | Tx not visible in mempool before inclusion | BloxRoute `frontRunningProtection` flag |
| Jito leader coverage | ~20-25% of slots have Jito-staked leaders | Bundles can only land in Jito slots — affects landing rate |

**Tip handling in dispatch_service.rs:**

```
For each pending transaction:
  1. Check provider_configs[provider_id].tip_lamports (provider-level override)
  2. Fallback to benchmark_config.tip_lamports (global benchmark setting)
  3. If tip > 0 AND provider has a tip_account:
     - Append system_instruction::transfer(payer, tip_account, tip_lamports)
     - Update benchmark_transactions.tip_lamports in DB
```

## Confirmation Strategy

### Polling Loop (`polling_service.rs`)

```
┌─────────────────────────────────────────────────┐
│  Start: sleep(poll_interval_secs)               │
│                                                 │
│  Loop while unresolved.len() > 0:               │
│    │                                            │
│    ├─ Check timeout (elapsed > poll_timeout_secs)│
│    │   └─ Yes: mark remaining Sent→TimedOut     │
│    │          error = "blockhash expired"        │
│    │          break                              │
│    │                                            │
│    ├─ get_signature_statuses(&signatures)        │
│    │                                            │
│    ├─ For each status:                          │
│    │   ├─ Some + err    → Failed                │
│    │   ├─ Some + confirmed → get_transaction    │
│    │   │                    → extract slot, time │
│    │   │                    → Landed            │
│    │   ├─ Some + not confirmed → keep polling   │
│    │   └─ None          → keep polling          │
│    │                                            │
│    └─ sleep(poll_interval_secs)                 │
│                                                 │
│  Record POLLING_DURATION histogram              │
└─────────────────────────────────────────────────┘
```

| Parameter | Source | Typical Value |
|-----------|--------|--------------|
| `poll_interval_secs` | Benchmark config | 2 seconds |
| `poll_timeout_secs` | Benchmark config | 60 seconds |
| Commitment | Hardcoded | `confirmed` |

### Why Not WebSocket Subscriptions?

`signatureSubscribe` WebSocket exists but has drawbacks for benchmarking:
- Requires maintaining WebSocket connections per provider
- Less reliable across different RPC providers
- Polling gives consistent measurement methodology
- Benchmark resolution (seconds) doesn't need sub-second notification

## Blockhash Expiry & Retry

| Parameter | Value | Notes |
|-----------|-------|-------|
| Blockhash validity | ~150 blocks | After 150 blocks, tx with old blockhash is dropped |
| Time validity | ~60-90 seconds | 150 * 400ms = 60s nominal; actual varies |
| Heimdall poll timeout | Configurable | Set per benchmark; typically 60s |
| Heimdall retry | None | No retry — each tx is sent once to measure raw landing |

**No retry by design**: Heimdall measures single-attempt landing rate. Retrying would conflate provider speed with retry strategy effectiveness.

## Error Taxonomy

Error classification in `sender/src/classify.rs` — pattern-matched in priority order:

| Category | Triggers (lowercased) | Typical Cause | Heimdall Impact |
|----------|----------------------|---------------|-----------------|
| `rate_limited` | `"429"`, `"rate limit"`, `"too many requests"` | Provider throttling sender | Indicates provider capacity limits |
| `server_error` | `"503"`, `"502"`, `"500"`, `"internal error"` | Provider-side failure | Provider reliability issue |
| `timeout` | `"timeout"`, `"timed out"`, `"deadline"` | Network or provider too slow | Latency / distance problem |
| `network_error` | `"connection"`, `"dns"`, `"network"`, `"refused"`, `"reset"` | Connectivity failure | Sender region → provider route issue |
| `deserialization_error` | `"deserialize"`, `"parse"`, `"json"`, `"bincode"`, `"base64"` | Malformed response | Provider API incompatibility |
| `unknown` | Everything else | Unrecognized error pattern | Needs investigation |

### Error Flow

```
sender/src/rpc.rs
  send_transaction() fails
       │
       ▼
  classify_error(&error_string)
       │
       ▼
  TxResult {
    signature: None,
    error: Some(sanitized_msg),
    error_category: Some(category)
  }
       │
       ▼
  Published to EXCHANGE_RESULTS
       │
       ▼
  backend processes → benchmark_transactions.error_message,
                      benchmark_transactions.error_category
```

All error messages pass through `sanitize_urls()` before logging or storage — RPC URLs are scrubbed to protect confidential endpoints.

### Polling-Stage Errors

Separate from send errors, `polling_service.rs` can produce:

| Outcome | DB Status | Error Message | Counter |
|---------|-----------|---------------|---------|
| Confirmed with `status.err` | `Failed` | Error from chain | `TX_LANDING["failed"]` |
| Timeout (no confirmation) | `TimedOut` | `"blockhash expired"` | `TX_LANDING["timed_out"]` |
| Confirmed, no error | `Landed` | None | `TX_LANDING["landed"]` |

## Performance Optimizations

| Technique | Description | Used in Heimdall? |
|-----------|-------------|-------------------|
| `skipPreflight: true` | Skip RPC-side simulation | Yes — all send methods |
| Priority fees | Higher fee = earlier scheduling | Yes — ascending `(index+1)` |
| Jito tips | Pay validators directly for inclusion | Yes — configurable per provider |
| Direct TPU send | Bypass RPC, send QUIC to leader | No — benchmarks RPC providers |
| Staked connections | Use staked identity for QoS | No — depends on provider |
| Multiple leader sends | Send to current + next leaders | No — single send per provider |
| Address Lookup Tables | Fit more accounts in 1232 bytes | No — txs are small enough |
| Transaction preheating | Prepare txs before slot boundary | Partial — blockhash fetched at dispatch time |
| Durable nonces | Use nonce instead of blockhash (no expiry) | No — would remove timing pressure that benchmarks need |

## What Affects Landing Rate

Synthesis of factors that Heimdall's benchmarks reveal:

### Provider-Side Factors
1. **Stake weight** — Determines TPU QoS allocation. Staked providers get more QUIC streams.
2. **TPU forwarding path** — Direct validator vs multi-hop forwarding.
3. **Geographic proximity to leader** — Provider's node location vs current leader's location.
4. **Rate limiting** — Provider-imposed limits can throttle high-volume sends.
5. **Send method** — Jito bundles only land on Jito leaders (~20-25% of slots).

### Transaction-Side Factors
6. **Priority fee** — Higher fee = earlier scheduling in banking stage.
7. **Compute budget** — Lower CU = more txs fit in a slot.
8. **Transaction size** — Must fit in 1232 bytes (not a concern for Heimdall).
9. **Account contention** — Write-locked accounts serialize tx processing (Heimdall uses unique PDAs).

### Network-Side Factors
10. **DNS resolution time** — Measured in `probe.rs`, can add 1-50ms.
11. **TCP/TLS handshake** — Measured in `probe.rs`, correlates with distance.
12. **Network jitter** — Measured in `benchmark_service.rs` `get_jitter_stats()`.
13. **Route quality** — BGP path between sender region and provider affects latency consistency.

### Timing Factors
14. **Leader rotation** — Tx sent at end of leader's 4-slot window may land in next leader's slots.
15. **Blockhash age** — Near-expiry blockhash risks tx being dropped before processing.
16. **Network congestion** — High-traffic periods saturate TPU queues.

## Heimdall Metrics

| Metric | Labels | Tracks |
|--------|--------|--------|
| `heimdall_benchmarks_created_total` | `signing_mode` | Benchmark creation volume |
| `heimdall_tx_landing_total` | `status` (`landed`/`failed`/`timed_out`) | Transaction outcomes |
| `heimdall_benchmarks_active` | (none) | Currently running benchmarks |
| `heimdall_dispatch_duration_seconds` | `outcome` | Time to build + publish dispatch messages |
| `heimdall_polling_duration_seconds` | `outcome` | Time to poll region's transactions to completion |
