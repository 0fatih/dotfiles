---
name: network-expert
description: Deep networking knowledge for analyzing latency, jitter, DNS/TCP measurement, HTTP/2, QUIC, and geographic factors. Use when working on Heimdall's probe system, interpreting network metrics, or optimizing connection performance.
user-invocable: true
---

# Network Expert

Production networking knowledge — DNS, TCP, TLS, HTTP/2, QUIC, latency measurement, and statistical analysis — tuned for Heimdall's RPC endpoint benchmarking.

## When to Use This Skill

- Adding or modifying probe types in `sender/src/probe.rs`
- Analyzing jitter, latency percentiles, or network metrics
- Optimizing DNS/TCP/TLS measurement accuracy
- Interpreting geographic latency patterns in benchmark results
- Working on `benchmark_service.rs` jitter stats or probe series
- Understanding HTTP/2 connection pooling behavior with `reqwest`
- Debugging network-related error categories (`timeout`, `network_error`, `dns`)

## Connection Lifecycle

```
  probe.rs                   Network                    RPC Endpoint
  ────────                   ───────                    ────────────
     │                          │                            │
     │  DNS Resolve             │                            │
     │  (tokio::net::lookup)    │                            │
     │ ─────────────────────►   │                            │
     │ ◄─────────────────────   │                            │
     │  dns_ms                  │                            │
     │                          │                            │
     │  TCP Connect             │                            │
     │  (TcpStream::connect)    │                            │
     │ ─────── SYN ──────────►  │                            │
     │ ◄────── SYN-ACK ───────  │                            │
     │ ─────── ACK ──────────►  │                            │
     │  tcp_ms                  │                            │
     │                          │                            │
     │  TLS Handshake (implicit in reqwest)                  │
     │ ─────── ClientHello ──────────────────────────────►   │
     │ ◄────── ServerHello + Cert ───────────────────────    │
     │ ─────── Finished ─────────────────────────────────►   │
     │                          │                            │
     │  HTTP/2 Request (reqwest::Client)                     │
     │  POST / (JSON-RPC)       │                            │
     │ ─────────────────────────────────────────────────►    │
     │ ◄─────────────────────────────────────────────────    │
     │  rtt_ms (full round-trip including JSON parse)        │
     │                          │                            │
```

**Heimdall field mapping:**

| Measurement | `probe.rs` Field | What It Captures |
|-------------|-----------------|------------------|
| DNS resolve | `dns_ms` | Time to resolve hostname → IP address |
| TCP connect | `tcp_ms` | 3-way handshake (1 RTT to endpoint) |
| RPC probe RTT | `rtt_ms` | Full HTTP request-response (includes TLS, HTTP/2 framing, server processing) |
| Response slot | `response_slot` | Slot number from `getSlot` response (RPC freshness indicator) |

## DNS Resolution

### Process

```
Application ──► Stub Resolver ──► Recursive Resolver ──► Root/TLD/Auth
                (OS cache)        (ISP / 8.8.8.8)        DNS servers
```

### Heimdall's DNS Measurement

```rust
// probe.rs — measure_network_latency()
let start = Instant::now();
let addrs: Vec<SocketAddr> = tokio::net::lookup_host(host_port)
    .await?
    .collect();
let dns_ms = start.elapsed().as_millis() as u32;
```

| Factor | Impact | Notes |
|--------|--------|-------|
| First query (cold cache) | 10-100ms | Full recursive resolution |
| Cached (within TTL) | 0-5ms | OS/resolver cache hit |
| TTL (typical RPC) | 60-300s | After TTL expiry, re-resolves |
| GeoDNS providers | Varies | May return different IPs per region — affects benchmark consistency |
| DNS failure | `dns_ms = None` | `classify_error` → `"network_error"` (matches `"dns"`) |

**Benchmarking impact**: First probe in a benchmark session pays the DNS penalty. Subsequent probes within TTL hit cache. Heimdall runs DNS measurement once per provider per benchmark in `measure_network_latency`.

## TCP Connection

### 3-Way Handshake

```
Sender                     Endpoint
  │                           │
  │ ──── SYN ───────────────► │
  │                           │  (1 RTT: sender → endpoint)
  │ ◄─── SYN-ACK ──────────  │
  │                           │  (1 RTT: endpoint → sender)
  │ ──── ACK ───────────────► │
  │                           │
  Total: 1 full RTT           │
```

### Heimdall's TCP Measurement

```rust
// probe.rs — measure_network_latency()
let start = Instant::now();
let _stream = tokio::time::timeout(
    Duration::from_secs(5),
    TcpStream::connect(&addr)
).await??;
let tcp_ms = start.elapsed().as_millis() as u32;
```

| Setting | Value | Rationale |
|---------|-------|-----------|
| Timeout | 5 seconds | Generous; production RPC endpoints should respond < 1s |
| Port fallback | 443 | If URL doesn't specify port, assumes HTTPS default |
| Connection reuse | No | Each measurement creates a fresh connection |

### TCP Tuning (relevant for `reqwest` client)

| Parameter | Effect | Heimdall Default |
|-----------|--------|-----------------|
| `TCP_NODELAY` | Disable Nagle's algorithm; send small packets immediately | `reqwest` enables by default |
| `SO_KEEPALIVE` | Detect dead connections | OS default |
| Congestion control (CUBIC/BBR) | Affects throughput ramp-up | OS default (CUBIC on Linux, CUBIC on macOS) |

## TLS

### TLS 1.3 Handshake (1 RTT)

```
Client                                Server
  │                                      │
  │ ──── ClientHello ──────────────────► │
  │      (supported ciphers,             │
  │       key share,                     │
  │       SNI hostname)                  │
  │                                      │
  │ ◄─── ServerHello ──────────────────  │
  │      + EncryptedExtensions           │
  │      + Certificate                   │
  │      + CertificateVerify             │
  │      + Finished                      │
  │                                      │
  │ ──── Finished ─────────────────────► │
  │                                      │
  │      (1 RTT total for full handshake)│
```

| Feature | TLS 1.3 | TLS 1.2 |
|---------|---------|---------|
| Handshake RTTs | 1 | 2 |
| 0-RTT resumption | Yes (PSK) | No |
| Cipher suites | AEAD only (AES-GCM, ChaCha20) | Negotiable |
| Certificate compression | Supported | No |

**For `reqwest`**: Uses `rustls` (Rust TLS implementation) by default. TLS 1.3 is preferred. The TLS handshake cost is amortized across the probe series since `reqwest::Client` reuses connections.

## HTTP/2 & QUIC

### Comparison

| Feature | HTTP/1.1 | HTTP/2 | HTTP/3 (QUIC) |
|---------|----------|--------|---------------|
| Multiplexing | No (one req/conn) | Yes (streams) | Yes (streams) |
| Head-of-line blocking | Connection-level | TCP-level | None (per-stream) |
| Handshake RTTs | TCP + TLS = 2-3 RTT | TCP + TLS = 2-3 RTT | 1 RTT (0-RTT resumption) |
| Transport | TCP | TCP | UDP |
| Header compression | None | HPACK | QPACK |
| Connection migration | No | No | Yes (connection ID) |

### Relevance to Heimdall

| Protocol | Where Used |
|----------|-----------|
| HTTP/2 over TLS | `reqwest::Client` for JSON-RPC calls (probes + sendTransaction). Most RPC endpoints serve HTTP/2. |
| QUIC | Solana TPU transaction submission (validator-to-validator and client-to-validator). Not directly measured by Heimdall's probes. |

**Connection pooling**: `reqwest::Client` maintains a connection pool. Within a probe series (`run_probes` loop), the same HTTP/2 connection is reused for sequential `getSlot` and `getBalance` calls. This means:
- First probe pays TCP + TLS handshake cost
- Subsequent probes measure pure request-response RTT
- This is the desired behavior — measures steady-state RPC performance

## Latency Measurement

### RTT Decomposition

```
Total RTT = DNS + TCP Handshake + TLS Handshake + HTTP Request/Response
            │         │               │                │
            │         │               │         Server processing
            │         │               │         + JSON serialization
            │         │               │         + network transit
            │         │         Amortized after
            │         │         first request
            │    Amortized after
            │    first request
       Cached after
       first resolve
```

For Heimdall's probe series (N probes per provider):
- **Probe 0**: DNS + TCP + TLS + HTTP (cold)
- **Probe 1-N**: HTTP only (warm — connection reused)

This is why `measure_network_latency` (DNS + TCP) is measured separately from the probe loop.

### Percentile Analysis

| Percentile | Meaning | Typical Use |
|------------|---------|-------------|
| p50 (median) | Half of measurements below this | "Normal" latency |
| p95 | 5% of measurements exceed this | SLO target for most services |
| p99 | 1% of measurements exceed this | Tail latency indicator |
| max | Worst observed | Outlier detection |
| min | Best observed | Theoretical floor (≈ speed of light RTT) |

## Jitter Analysis

### Heimdall's Jitter Calculation (`benchmark_service.rs`)

```sql
-- get_jitter_stats SQL aggregation
SELECT
    MIN(rtt_ms), MAX(rtt_ms),
    AVG(rtt_ms), STDDEV_POP(rtt_ms),
    COUNT(*), COUNT(CASE WHEN error IS NOT NULL THEN 1 END)
FROM benchmark_probe_series
GROUP BY benchmark_id, provider_id, region_id, method
```

| Metric | Formula | What It Reveals |
|--------|---------|-----------------|
| Jitter | `max_rtt_ms - min_rtt_ms` | Range of variation; sensitive to outliers |
| Std deviation | `STDDEV_POP(rtt_ms)` | Statistical spread; more robust than range |
| Coefficient of variation | `stddev / avg * 100%` | Relative variability; comparable across different latency scales |
| Failure rate | `failure_count / total_count` | Connection reliability |

### Interpreting Jitter

| CV (%) | Interpretation | Likely Cause |
|--------|---------------|-------------|
| < 5% | Very stable | Dedicated infrastructure, same datacenter |
| 5-15% | Normal | Typical cloud hosting, reasonable routing |
| 15-30% | Moderate jitter | Shared infrastructure, variable load |
| > 30% | High jitter | Network congestion, geographic routing issues, overloaded endpoint |

## Geographic Factors

### Distance-Latency Estimates

| Route | Distance | Min RTT (speed of light) | Typical RTT | Notes |
|-------|----------|-------------------------|-------------|-------|
| Same datacenter | < 1km | < 0.01ms | 0.1-1ms | Loopback + switch latency |
| Same region (e.g., us-east) | 100-500km | 0.5-2.5ms | 2-10ms | Intra-region fiber |
| Cross-region (us-east → us-west) | ~4,000km | ~20ms | 30-60ms | Transcontinental fiber |
| Transatlantic (us-east → eu-west) | ~6,000km | ~30ms | 60-90ms | Submarine cable |
| Transpacific (us-west → ap-east) | ~10,000km | ~50ms | 100-180ms | Submarine cable + routing |

**Speed of light in fiber**: ~200,000 km/s (2/3 of vacuum speed). Minimum RTT ≈ 2 * distance / 200,000 * 1000 ms.

### Heimdall's Multi-Region Design

```
  Region: us-east (sender)                Region: eu-west (sender)
  ┌──────────────────────┐                ┌──────────────────────┐
  │ probe.rs measures:   │                │ probe.rs measures:   │
  │  DNS: 2ms            │                │  DNS: 45ms           │
  │  TCP: 8ms            │                │  TCP: 75ms           │
  │  getSlot: 15ms       │                │  getSlot: 85ms       │
  └──────────┬───────────┘                └──────────┬───────────┘
             │                                       │
             │        ┌──────────────────┐           │
             └───────►│  RPC Provider    │◄──────────┘
                      │  (us-east based) │
                      └──────────────────┘
```

Each sender instance runs in a specific region and measures all providers from that vantage point. This reveals:
- **Co-located providers**: Low DNS + TCP from nearby sender
- **Remote providers**: Higher base latency, potentially more jitter
- **GeoDNS effects**: Provider may resolve to different IPs per region

## RPC Endpoint Benchmarking

### JSON-RPC Overhead

| Component | Overhead | Notes |
|-----------|----------|-------|
| HTTP framing | ~50-100 bytes | Headers, content-length |
| JSON-RPC envelope | ~80 bytes | `{"jsonrpc":"2.0","id":1,"method":...}` |
| TLS record | ~20 bytes per record | Encryption overhead |
| JSON parsing (server) | 0.01-0.1ms | Negligible for simple methods |
| JSON parsing (client) | 0.01-0.1ms | Negligible |

### Heimdall Probe Sequence (`run_probes`)

For each provider:
1. **DNS + TCP** measurement (once, via `measure_network_latency`)
2. **Loop** `probe_count` times:
   - `getSlot` probe → records `rtt_ms` + `response_slot`
   - `getBalance` probe → records `rtt_ms` only
3. First iteration (`seq == 0`) produces a `ProbeResult` (summary with DNS/TCP)
4. Every iteration produces `SeriesProbeResult` entries (time series)

### Connection Warm-Up Effects

```
Probe #  | RTT (ms) | Why
---------|----------|----------------------------------
0        | 145      | Cold: DNS + TCP + TLS + HTTP/2 negotiation
1        | 42       | Warm: connection reused, only HTTP/2 stream
2        | 38       | Warm: steady state
3        | 41       | Warm: steady state
4        | 39       | Warm: steady state (typical variance)
```

**Analysis tip**: When viewing probe series, probe 0 often has 2-4x the RTT of subsequent probes. This is normal — it reflects connection establishment cost, not endpoint performance. `get_jitter_stats` includes all probes, so min/avg/stddev will capture this. For pure endpoint performance, filter to `seq > 0`.

## Statistical Analysis

### Outlier Detection (IQR Method)

```
Sorted RTTs: [38, 39, 41, 42, 42, 43, 145, 180]
                          │
Q1 = 39.5               Q3 = 92.5
IQR = Q3 - Q1 = 53
Lower fence = Q1 - 1.5 * IQR = -40    (no lower outliers)
Upper fence = Q3 + 1.5 * IQR = 172    → 180 is an outlier
```

### Sample Size Considerations

| Probe Count | Statistical Power | Trade-off |
|------------|-------------------|-----------|
| 3-5 | Low; can detect large differences only | Fast, cheap |
| 10-20 | Moderate; reasonable percentile estimates | Good balance |
| 30-50 | Good; stable p95 estimates | More time + cost |
| 100+ | High; reliable p99 estimates | Expensive, diminishing returns |

Rule of thumb: Need ~100/p samples for reliable p-th percentile estimate (e.g., 100 samples for p99, 20 for p95).

### Coefficient of Variation for Cross-Provider Comparison

```
Provider A: avg=40ms, stddev=5ms  → CV = 12.5%
Provider B: avg=120ms, stddev=12ms → CV = 10.0%

Provider B has lower relative variability despite higher absolute jitter.
CV normalizes for different latency scales.
```

## Rust Implementation Patterns

### DNS + TCP Measurement (`probe.rs` pattern)

```rust
// DNS
let start = Instant::now();
let addrs: Vec<SocketAddr> = tokio::net::lookup_host(format!("{}:{}", host, port))
    .await
    .map_err(|e| ...)?
    .collect();
let dns_ms = start.elapsed().as_millis() as u32;

// TCP (using first resolved address)
let start = Instant::now();
let _stream = tokio::time::timeout(
    Duration::from_secs(5),
    TcpStream::connect(&addrs[0])
).await??;
let tcp_ms = start.elapsed().as_millis() as u32;
```

### HTTP Client Configuration (`reqwest`)

Key settings that affect network measurement:

| Setting | Effect | Heimdall |
|---------|--------|----------|
| `pool_idle_timeout` | How long idle connections survive | Default (90s) |
| `pool_max_idle_per_host` | Connection pool size | Default |
| `timeout` | Per-request timeout | Set per probe |
| `connect_timeout` | TCP + TLS timeout | Set if needed |
| `tcp_nodelay(true)` | Disable Nagle | Default in reqwest |
| `http2_prior_knowledge()` | Skip HTTP/1.1 → HTTP/2 upgrade | Not set (uses ALPN) |

### Measuring Connection Phases with `reqwest`

`reqwest` doesn't expose per-phase timing. Heimdall's approach:
- **DNS + TCP**: Measured separately in `measure_network_latency` using raw `tokio::net`
- **Full RTT**: Measured by timing the `reqwest` request-response cycle in `probe_get_slot`/`probe_get_balance`
- **TLS**: Implicit in the first request; amortized in subsequent requests

### Concurrent Probe Execution

```rust
// run_probes spawns one task per provider
for (rpc_url, provider_id) in providers {
    let handle = tokio::spawn(async move {
        let (dns_ms, tcp_ms) = measure_network_latency(&rpc_url).await;
        let mut probes = Vec::new();
        for seq in 0..probe_count {
            let slot_result = probe_get_slot(&client, &rpc_url).await;
            let balance_result = probe_get_balance(&client, &rpc_url).await;
            // collect results...
        }
        (probes, series)
    });
}
```

All providers are probed concurrently (one Tokio task per provider), but within each provider the probes are sequential. This ensures:
- Probes don't contend with each other on the provider
- Each probe series accurately reflects that provider's individual performance
- Cross-provider measurements happen simultaneously for fair comparison
