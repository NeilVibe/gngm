---
name: VRAM-HYGIENE — Never long-pin Qwen 3.5:9B (or any model) on a dev GPU
description: Hard rule against long-pinning the Graphiti extraction model (or any >4 GB model) in GPU VRAM. keep_alive by scenario, the correct pre-warm pattern, the mandatory end-of-session unload diagnostic. Also covers the CPU-starvation case — an add_episode timeout with a clear GPU is not VRAM contention. Codified after a real incident where keep_alive=600 pinned 8.6 GB for 10 minutes on a 12 GB card.
type: gngm-protocol
version: 2
last_verified: 2026-05-17
trigger: self-applied around every Graphiti add_episode and GPU model load
---

# VRAM-HYGIENE — Never long-pin Qwen 3.5:9B (or any model) on a dev GPU

> **Status:** Hard rule. Codified 2026-05-15 after a real-user incident.
> **Scope:** Any GNGM-using developer on a single consumer GPU (≤ 24 GB)
> who also runs other GPU workloads (Qwen3-VL, local image-gen, vision-review, etc).

## The incident (concrete reference case)

2026-05-15, LocaNext session, RTX 4070 Ti 12 GB. After a Graphiti
`add_episode` cold-load timeout (180s), I issued a pre-warm with
`keep_alive: 600` (10 min) before retrying. The retry succeeded in
~30s; the model then sat at **8.6 GB VRAM for 9.5 more minutes**,
leaving only 3.4 GB free on a 12 GB card.

The user runs Qwen3-VL (6.1 GB) for AVQA / vision-review on the same
card; the pin forced everything else into CPU fallback or OOM. User
reaction:

> "WHY IS IT PINNED" /
> "WHY DO YOU KEEP PINNING IT" /
> "FUCKINHELL CHANGE THE CODE"

The performance hit was real and severe. This protocol exists so it
NEVER repeats.

## Why pinning happens at all

The Graphiti client (`qwen_client.py`) calls Ollama's `/api/generate`
without specifying `keep_alive`. **Ollama's default is 5 minutes** (300s).
That alone is bounded and tolerable.

Pinning gets dangerous when developers explicitly set higher values
"to stay warm" between calls. The 2026-05-15 incident: `keep_alive: 600`.
The right value for that scenario was **`keep_alive: 60`** + explicit
`keep_alive: 0` unload immediately after the dependent work finished.

## The rules — `keep_alive` by scenario

| Scenario | Correct `keep_alive` | Notes |
|---|---|---|
| Pre-warm before a known single `add_episode` | **`60`** (60s) max | Episode is 20-40s; 60s buys safety margin |
| Inside `add_episode` itself | **omit** (Ollama default 5min) | Already bounded; no patch needed |
| Back-to-back batch of ≥3 episodes | **`300`** (5min) | Match Ollama default; explicit unload after batch |
| Episodes scattered over 10+ min | **DO NOT pin** | Accept 30-60s cold load between calls |
| Permanent pin (`-1`) | **FORBIDDEN** | No exception. Redesign the task. |
| Right after any Graphiti session ends | **explicit `keep_alive: 0` unload** | Mandatory close-out |

## The pattern (correct pre-warm)

```bash
# 1. Pre-warm with a SHORT bound — never 300, never 600, NEVER -1
curl -s -X POST http://localhost:11434/api/generate \
  -H 'Content-Type: application/json' \
  -d '{"model":"qwen3.5:9b","keep_alive":60,"prompt":"hi","stream":false}' > /dev/null

# 2. Run the dependent add_episode IMMEDIATELY (within ~30s)
python3 -c "<add_episode call>"

# 3. ALWAYS unload immediately after the work, even with the 60s bound at step 1
curl -s -X POST http://localhost:11434/api/generate \
  -H 'Content-Type: application/json' \
  -d '{"model":"qwen3.5:9b","keep_alive":0,"prompt":"","stream":false}' > /dev/null

# 4. Verify with 5-SECOND wait (not 2s) — Ollama needs 3-4s after API return
sleep 5 && curl -s http://localhost:11434/api/ps | python3 -c \
  "import json,sys; d=json.load(sys.stdin); ms=d.get('models',[]); \
   print('LEAK' if ms else 'CLEAN')"
# expect: CLEAN
```

## End-of-session diagnostic (REQUIRED after any GNGM work)

```bash
sleep 5 && curl -s http://localhost:11434/api/ps | python3 -c \
  "import json,sys; d=json.load(sys.stdin); ms=d.get('models',[]); \
   print('LEAK' if any('qwen' in m['name'].lower() for m in ms) else 'CLEAN')"
```

- "CLEAN" → session safe to wrap
- "LEAK" → unload immediately with `keep_alive: 0`, then re-verify

## Why the user perceives "computer obliterated"

A pinned 8.6 GB Qwen3.5:9b on a 12 GB card leaves only 3.4 GB free.
Below that threshold:

- Qwen3-VL (6.1 GB) won't load → AVQA / vision-review broken
- Local image-gen (4-10 GB depending on model) → can't run
- Browser / system GPU compositor → starts swapping
- Some apps hit CPU fallback, others OOM-crash

The threshold is binary, not gradual. Going from "Graphiti runs OK"
to "everything else stops working" happens the instant Qwen pins.
The user feels this as their workstation grinding to a halt — and
they're right to feel it that way.

## Generalization to other heavy models

Same rule applies to any model with size_vram > 4 GB:

- Z-Image NF4 (~5 GB)
- Wan VACE 1.3B (~6 GB peak)
- Whisper large-v3 (~3 GB — borderline; can usually stay pinned briefly)
- Stable Diffusion XL (~7 GB)

**Rule:** never pin > 60s without explicit user opt-in for a known
batch workload.

## Snapshot timing gotcha (sub-rule)

Ollama's `/api/ps` is a SNAPSHOT, not a live query. After issuing
`keep_alive: 0`, the process takes **3-4 seconds** to actually unload
the model from VRAM. A `sleep 2 && /api/ps` check will still show the
model as "loaded" even though it's already evicting.

**Always `sleep 5` before re-checking, and cross-check with
`nvidia-smi --query-gpu=memory.used --format=csv`.** The nvidia-smi
reading reflects actual VRAM state; `/api/ps` reflects Ollama's
in-memory bookkeeping.

## CPU starvation — a non-VRAM cause of `add_episode` timeout (sub-rule)

Not every `add_episode` timeout is a VRAM problem. The model cold-load
(reading 6.6 GB off disk + CPU-side tensor setup) is **disk- and
CPU-bound**, not GPU-bound. When an unrelated process is saturating the
CPU, the cold-load crawls and `add_episode` times out **even though the
GPU is completely free** — so eviction has nothing to evict, and
restarting Ollama does nothing (Ollama is healthy).

**Distinguish it from VRAM contention before acting:**

| Check | VRAM contention | CPU starvation |
|---|---|---|
| `/api/ps` | another model loaded (e.g. qwen3-vl) | **empty** |
| `nvidia-smi` VRAM | near full | plenty free |
| `uptime` loadavg | normal | **far above `nproc`** |

If `/api/ps` is empty AND VRAM is free AND loadavg is far above core
count → it is CPU starvation. Escapes:

1. **Use the smaller model** — `create_qwen_graphiti(..., model='qwen3.5:4b')`.
   The 4b cold-load is ~half the 9b's (3.4 GB vs 6.6 GB), so it completes
   inside the timeout where 9b does not. Extraction is slightly weaker —
   an acceptable trade for an episode that otherwise never lands.
2. **Defer** the episode until the CPU hog finishes.
3. Do **not** `renice`/kill the other process without the user's say-so —
   it may be a deliberate run.

**Verified 2026-05-17 (LocaNext):** a 9b `add_episode` was SIGKILL'd at a
400 s cap while an unrelated backtest held ~1000 % CPU; the GPU was clear
the whole time. The `qwen3.5:4b` retry landed it — its first attempt
still hit the 180 s cold-load timeout, but the client's built-in retry
then succeeded on the now-warm model.

```
add_episode times out, BOTH attempts
  ├─ /api/ps shows another model loaded? → VRAM contention → evict it
  └─ /api/ps empty?
       ├─ uptime loadavg far above nproc? → CPU starvation
       │     → retry with qwen3.5:4b, OR defer. NOT an Ollama fault.
       └─ loadavg normal? → Ollama daemon issue → restart Ollama
```

## Related

- [DEBUG.md R5](DEBUG.md) — vision-pipeline batch case where `keep_alive=-1` IS appropriate (DIFFERENT scenario — dedicated production batch, not interactive dev)
- [GIT-SAFETY.md](GIT-SAFETY.md) — sister discipline: don't destroy user state silently
- [GIT-HYGIENE.md](GIT-HYGIENE.md) — sister discipline: don't lose user work
- [`docs/02-PROTOCOL.md`](../docs/02-PROTOCOL.md) §"Anti-patterns" — pointer back to this file

## Docs

- `../clients/graphiti/qwen_client.py` — caps `keep_alive` at 60s; provides the `unload_qwen()` helper
- `../docs/08-GRAPHITI-MASTERY.md` §"The local-Qwen reality" — VRAM hygiene inside the Graphiti workflow
- Ollama `/api/generate` + `/api/ps` — the `keep_alive` parameter and the load-state snapshot

## Changelog

- 2026-05-17 — v2. Added the CPU-starvation sub-rule: an `add_episode` timeout with `/api/ps` empty + GPU free + loadavg far above `nproc` is CPU starvation, NOT VRAM contention and NOT an Ollama fault. Distinguish via the checks table; escape with `qwen3.5:4b` or defer. Verified same day on LocaNext (9b killed at a 400 s cap under a ~1000 % CPU backtest; the 4b retry landed).
- 2026-05-15 — v1. Codified after LocaNext incident: pre-warm with `keep_alive: 600` pinned 8.6 GB for 10 min on user's 12 GB card.
