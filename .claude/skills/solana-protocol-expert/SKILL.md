---
name: solana-protocol-expert
description: Deep Solana protocol knowledge for analyzing benchmark results, understanding slot timing, landing rates, leader schedules, TPU pipeline, and consensus. Use when working on Heimdall's benchmarking logic, interpreting results, or debugging transaction landing behavior.
user-invocable: true
---

# Solana Protocol Expert

Deep protocol-level knowledge of Solana's architecture, consensus, and transaction processing pipeline — tuned for Heimdall's transaction landing benchmarks.

## When to Use This Skill

- Analyzing benchmark results (landing rates, slot deltas, timing spreads)
- Understanding why transactions land in different slots across providers
- Working on leader schedule logic or slot timing calculations
- Debugging TPU pipeline behavior (why a transaction was dropped)
- Understanding stake-weighted QoS and its effect on RPC provider performance
- Interpreting commitment levels (processed vs confirmed vs finalized)
- Working on `probe.rs`, `polling_service.rs`, or `dispatch_service.rs`

## Architecture Overview

```
                    ┌─────────────────────────────────────────────┐
                    │              CURRENT LEADER                 │
Client ──QUIC──►   │  Fetch ─► SigVerify ─► Banking ─► Broadcast │
                    │  (TPU)    (verify)    (execute)   (shreds)  │
                    └──────────────────────────┬──────────────────┘
                                               │ Turbine
                              ┌────────────────┼────────────────┐
                              ▼                ▼                ▼
                         Validator A      Validator B      Validator C
                          (vote)           (vote)           (vote)
                              │                │                │
                              └────────┬───────┘                │
                                       ▼                        │
                              Supermajority (2/3+)              │
                              = Confirmed                       │
                                       │                        │
                                       ▼                        │
                              31 slots rooted ──────────────────┘
                              = Finalized
```

**Heimdall's position**: Sends transactions via QUIC (through RPC nodes) to the TPU, then polls for confirmation using `getSignatureStatuses`.

## Slot & Epoch Timing

| Parameter | Value | Notes |
|-----------|-------|-------|
| Slot duration | 400ms | Target; actual varies ~380-420ms |
| Ticks per slot | 64 | PoH ticks |
| Consecutive leader slots | 4 | Same validator leads 4 slots in a row |
| Slots per epoch | 432,000 | ~2 days at 400ms/slot |
| Epoch duration | ~2.0 days | 432,000 * 400ms |
| Leader schedule lookahead | 1 epoch | Published one epoch ahead |

**Heimdall relevance**: Slot spread in benchmark results (`max_landed_slot - min_landed_slot`) directly reflects how quickly different providers' transactions reach the leader's banking stage. A spread of 0-1 slots means sub-second differences; spread of 4+ means transactions crossed leader rotation boundaries.

## TPU Pipeline Stages

### 1. Fetch Stage (QUIC Ingress)

```
Client ──QUIC──► TPU Port 8004
                    │
         Stake-Weighted QoS
         (high-stake nodes get more streams)
                    │
                    ▼
              Packet Queue
```

- Validators accept transactions over QUIC (UDP-based, TLS 1.3 encrypted).
- Stake-weighted QoS: validators allocate QUIC streams proportional to the sender's stake weight.
- Unstaked connections (most RPC nodes) share a limited pool — this is why provider choice matters in Heimdall benchmarks.
- Port: TPU at `8004`, TPU forward at `8006`.

### 2. SigVerify Stage

- Ed25519 signature verification on GPU (if available).
- Deduplication: transactions with duplicate signatures are dropped.
- Invalid signatures → packet dropped silently (no error returned to sender).

### 3. Banking Stage

- Processes transactions against the current slot's state.
- **Compute unit budget**: Each transaction declares CU limit (Heimdall uses `50,000` CU in `dispatch_service.rs`).
- **Priority fee ordering**: Higher `priority_fee` (microlamports/CU) gets scheduled first.
- Heimdall sets priority fee = `(tx_index + 1)` microlamports — deliberately low and unique per tx to avoid same-fee ordering ambiguity.
- Transactions that fail execution → included in block with error status (still charged fees).

### 4. Broadcast Stage (Turbine)

- Leader shreds the block and broadcasts via Turbine protocol.
- Shreds propagate through the validator tree (see Turbine section below).

## Turbine Block Propagation

```
              Leader
           ┌────┴────┐
     Neighborhood 0   │
      ┌──┬──┬──┐      │
      V1 V2 V3 V4     │
      │  │  │  │       │
      ▼  ▼  ▼  ▼      │
    Neighborhood 1     │
      ┌──┬──┬──┐      │
      V5 V6 V7 V8     │
      │  │  │  │       │
      ▼  ▼  ▼  ▼      │
    Neighborhood 2   ◄─┘
      V9 V10 V11 V12
```

| Parameter | Value |
|-----------|-------|
| Shred size | 1228 bytes payload |
| Erasure coding | Reed-Solomon (data + parity shreds) |
| Neighborhood size | ~200 validators (stake-weighted) |
| Fanout | ~200 per layer |
| Propagation hops | 2-3 for ~2000 validators |

**Why it matters for Heimdall**: Turbine propagation determines how quickly non-leader validators see the block — which affects when `getSignatureStatuses` returns `confirmed` depending on which validator the RPC node queries.

## Consensus: Tower BFT

Solana's consensus is Tower BFT — a PoH-optimized variant of PBFT.

| Concept | Description |
|---------|-------------|
| Vote transaction | Validators vote on each slot; votes are transactions themselves |
| Supermajority | 2/3+ of stake must vote on a slot |
| Lockout | Voting on slot N locks the validator out of voting for conflicting forks for 2^(vote_depth) slots |
| Optimistic confirmation | 2/3+ stake voted on slot → "confirmed" (~400ms after slot) |
| Finalization | Slot is rooted after 31 confirmations → "finalized" (~12-13s) |

**Heimdall uses `confirmed` commitment** in `polling_service.rs` — this is when 2/3+ of stake has voted on the slot containing the transaction.

## Stake-Weighted QoS

This is the single most important protocol mechanism affecting Heimdall benchmark results.

| Sender Type | Stake | TPU Priority | QUIC Streams | Effective |
|------------|-------|-------------|-------------|-----------|
| Top validator | High | First priority | Many dedicated | Near-guaranteed inclusion |
| Mid validator | Medium | Medium priority | Proportional | High inclusion |
| Staked RPC (e.g., Helius) | Some stake | Above unstaked | Proportional to stake | Better than pure RPC |
| Unstaked RPC node | None | Lowest priority | Shared limited pool | Best-effort only |
| Direct TPU (custom) | Varies | Depends on sender stake | Direct | Varies |

**Impact on benchmarks**: Two providers with identical network latency can have wildly different landing rates purely due to their stake weight and TPU access method. Heimdall captures this by measuring landing rate and slot delta per provider.

## RPC Nodes vs Validators

| Characteristic | RPC Node | Validator |
|---------------|----------|-----------|
| Stake | Usually none | Staked |
| Voting | No | Yes |
| TPU access | Forwards to leader | Direct (if leader) |
| `getSlot` freshness | 1-2 slots behind | Current |
| Transaction forwarding | Via QUIC to leader | Direct (if leader), forward (if not) |
| Block data | Full history (if configured) | Recent only |

**Heimdall's `probe.rs`** calls `getSlot` on each provider — the `response_slot` reveals how fresh the RPC node's view is. Slot delta (`max_slot - node_slot`) quantifies how far behind each provider is.

## Commitment Levels

| Level | Guarantee | Typical Latency | Heimdall Usage |
|-------|-----------|----------------|----------------|
| `processed` | Transaction processed by leader, not necessarily voted on | ~400ms | Not used (unreliable) |
| `confirmed` | 2/3+ stake voted on slot | ~400ms-2s | **Primary** — `polling_service.rs` checks this |
| `finalized` | Slot rooted (31+ confirmations) | ~12-13s | Not used (too slow for benchmarking) |

`polling_service.rs` uses `CommitmentConfig::confirmed()` when calling `get_signature_statuses` and `get_transaction_with_config`.

## Recent Protocol Changes

| Change | Impact on Heimdall |
|--------|-------------------|
| **QUIC migration** (2023) | Replaced UDP. Enables stake-weighted QoS. RPC providers need QUIC support. |
| **Local fee markets** (2024) | Priority fees now per-account, not global. Heimdall's low-CU benchmark txs rarely contend with DeFi activity. |
| **Priority fee scheduler** | Transactions ordered by fee within banking stage. Heimdall's ascending `(index+1)` fees create a deterministic ordering. |
| **Central scheduler** (2024) | Replaced random thread assignment in banking stage. Reduces duplicate processing. Better landing rates across the board. |
| **SIMD-0096 (reward timing)** | Moved reward calculation to EpochBoundary, reducing slot skip rates at epoch boundaries. |

## Heimdall File Mapping

| Protocol Concept | Heimdall File | How It's Used |
|-----------------|---------------|---------------|
| TPU submission | `sender/src/rpc.rs` | `send_standard_rpc` sends via `sendTransaction` with `skipPreflight: true` |
| Compute budget | `backend/src/services/dispatch_service.rs` | `set_compute_unit_limit(50_000)` + `set_compute_unit_price(priority_fee)` |
| Priority fees | `backend/src/services/dispatch_service.rs` | `priority_fee = (tx_index + 1)` microlamports — unique, ascending |
| Slot observation | `sender/src/probe.rs` | `getSlot` RPC probes, measures `response_slot` per provider |
| Slot delta | `backend/src/services/benchmark_service.rs` | `slot_delta = max_slot - row.response_slot` in `get_rpc_probes()` |
| Confirmation polling | `backend/src/services/polling_service.rs` | `get_signature_statuses` loop with `confirmed` commitment |
| Landed slot | `backend/src/services/polling_service.rs` | `get_transaction_with_config` extracts `landed_slot` from confirmed tx |
| Slot spread | `backend/src/services/benchmark_service.rs` | `slot_spread = max_landed_slot - min_landed_slot` in results |
| Landing rate | `backend/src/services/benchmark_service.rs` | `landing_rate = total_landed / total_sent` |
| Metrics | `backend/src/metrics.rs` | `TX_LANDING` counter tracks `landed`/`failed`/`timed_out` per tx |
| RabbitMQ dispatch | `shared/src/constants.rs` | `EXCHANGE_DISPATCH` exchange, region-based routing keys |

## Key Numbers for Benchmarking Context

| Metric | Typical Value | When to Investigate |
|--------|--------------|-------------------|
| Landing rate (good provider) | 85-99% | < 70% suggests QoS or routing issues |
| Landing rate (unstaked RPC) | 40-80% | Expected to be lower; depends on network load |
| Slot spread (same leader) | 0-1 | All txs hit same leader rotation |
| Slot spread (cross-leader) | 4-8 | Txs span leader boundaries — check blockhash age |
| Confirmation latency | 0.5-3s | > 5s suggests polling issues or network partition |
| Probe slot delta | 0-2 | > 3 means RPC node is significantly behind |
| DNS resolution | 1-50ms | > 100ms suggests DNS issues |
| TCP connect | 5-200ms | Correlates with geographic distance |
