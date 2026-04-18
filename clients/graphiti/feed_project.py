"""
Feed all project knowledge to Graphiti — one episode at a time.
Run: python3 ~/.graphiti/feed_project.py

Architecture:
- Sequential processing (one at a time, no GPU overload)
- Automatic retry (3 passes: initial + 2 retries)
- Failures collected and retried, permanent failures listed
- Preflight probe before starting
- Safe read with encoding fallback
"""
import sys
sys.path.insert(0, '/home/neil1988/.graphiti')

import asyncio
import time
from datetime import datetime, timezone
from pathlib import Path
from qwen_client import create_qwen_graphiti

PROJECT = Path('/home/neil1988/LocalizationTools')
MEMORY = Path('/home/neil1988/.claude/projects/-home-neil1988-LocalizationTools/memory')
MAX_BODY = 1500  # chars per episode — keeps Qwen fast and accurate
MAX_PASSES = 3   # Total passes: 1 initial + 2 retries

# Priority-ordered file list
FILES = [
    # P1: Architecture
    'docs/architecture/ARCHITECTURE_SUMMARY.md',
    'docs/architecture/OFFLINE_ONLINE_MODE.md',
    'docs/architecture/CLIENT_SERVER_PROCESSING.md',
    'docs/architecture/DB_ABSTRACTION_LAYER.md',
    'docs/architecture/BACKEND_PRINCIPLES.md',
    'docs/architecture/ASYNC_PATTERNS.md',
    'docs/architecture/PLATFORM_PATTERN.md',
    'docs/architecture/TM_HIERARCHY_PLAN.md',
    # P2: Recent handoffs
    'docs/current/HANDOFF_PHASE130.md',
    'docs/current/HANDOFF_PHASE129_CORS.md',
    'docs/current/HANDOFF_PHASE128.md',
    'docs/current/HANDOFF_PHASE127.md',
    'docs/current/HANDOFF_PHASE126.md',
    'docs/current/HANDOFF_PHASE125.md',
    'docs/current/HANDOFF_PHASE124.md',
    # P3: Memory reference
    str(MEMORY / 'reference/tm_architecture.md'),
    str(MEMORY / 'reference/client_server_processing.md'),
    str(MEMORY / 'reference/factory_pattern.md'),
    str(MEMORY / 'reference/build_types.md'),
    str(MEMORY / 'reference/build_pipeline.md'),
    str(MEMORY / 'reference/lan_auth_model.md'),
    str(MEMORY / 'reference/security_state.md'),
    str(MEMORY / 'reference/model2vec_build.md'),
    str(MEMORY / 'reference/xml_patterns.md'),
    # P4: Older handoffs
    'docs/current/HANDOFF_PHASE123.md',
    'docs/current/HANDOFF_PHASE122.md',
    'docs/current/HANDOFF_PHASE121.md',
    'docs/current/HANDOFF_PHASE120.md',
    'docs/current/HANDOFF_PHASE119.md',
    'docs/current/HANDOFF_PHASE118.md',
    'docs/current/HANDOFF_PHASE117.md',
    'docs/current/HANDOFF_PHASE116.md',
    'docs/current/HANDOFF_PHASE115.md',
]


def read_and_truncate(filepath: str) -> str:
    """Read file and truncate to MAX_BODY chars. Safe encoding fallback."""
    full_path = Path(filepath) if filepath.startswith('/') else PROJECT / filepath

    try:
        text = full_path.read_text(encoding='utf-8')
    except UnicodeDecodeError:
        text = full_path.read_text(encoding='utf-8', errors='replace')
    except FileNotFoundError:
        return ''

    # Strip frontmatter (look for closing --- on its own line)
    if text.startswith('---'):
        end = text.find('\n---', 3)
        if end > 0:
            text = text[end + 4:].strip()

    # Truncate
    if len(text) > MAX_BODY:
        text = text[:MAX_BODY] + '\n[truncated]'
    return text


def _episode_name(filepath: str) -> str:
    """Generate unique episode name from filepath (avoids collisions)."""
    p = Path(filepath)
    # Use parent dir + stem for uniqueness: e.g. "architecture-OFFLINE_ONLINE_MODE"
    parent = p.parent.name or 'root'
    return f'project-{parent}-{p.stem}'


async def feed_files(g, files, pass_num=1):
    """Feed a list of files. Returns (failed_files, skipped_count)."""
    total = len(files)
    success = 0
    skipped = 0
    failed_files = []

    label = f'Pass {pass_num}' if pass_num > 1 else 'Feeding'
    print(f'{label}: {total} files...', flush=True)

    for i, filepath in enumerate(files):
        name = Path(filepath).stem

        # Safe read — encoding errors caught here, not crashing the run
        try:
            body = read_and_truncate(filepath)
        except Exception as e:
            print(f'[{i+1}/{total}] READ-ERROR {name}: {e}', flush=True)
            failed_files.append(filepath)
            continue

        if not body:
            print(f'[{i+1}/{total}] SKIP {name}', flush=True)
            skipped += 1
            continue

        t0 = time.time()
        try:
            await g.add_episode(
                name=_episode_name(filepath),
                episode_body=body,
                source_description=filepath,
                reference_time=datetime.now(timezone.utc),
                group_id='localizationtools',
            )
            elapsed = time.time() - t0
            success += 1
            print(f'[{i+1}/{total}] OK {name} ({elapsed:.1f}s)', flush=True)
        except Exception as e:
            elapsed = time.time() - t0
            failed_files.append(filepath)
            print(f'[{i+1}/{total}] FAIL {name} ({elapsed:.1f}s): {str(e)[:80]}', flush=True)

    print(f'{label} done: {success} OK, {len(failed_files)} FAIL, {skipped} SKIP', flush=True)
    return failed_files, skipped


async def main():
    g = await create_qwen_graphiti(graph_name='localizationtools')

    # Preflight probe — fail fast if Graphiti/Ollama/FalkorDB is down
    try:
        probe = await g.search('probe', group_ids=['localizationtools'])
        print(f'Preflight OK — graph reachable, {len(probe)} existing facts', flush=True)
    except Exception as e:
        print(f'FATAL: Graphiti not reachable: {e}', flush=True)
        sys.exit(1)

    total = len(FILES)
    remaining = list(FILES)
    total_skipped = 0

    for pass_num in range(1, MAX_PASSES + 1):
        if not remaining:
            break
        # Re-create connection on retry passes (in case FalkorDB dropped)
        if pass_num > 1:
            print(f'\n--- Retrying {len(remaining)} failures (pass {pass_num}/{MAX_PASSES}) ---\n', flush=True)
            g = await create_qwen_graphiti(graph_name='localizationtools')
        remaining, skipped = await feed_files(g, remaining, pass_num)
        total_skipped += skipped

    added = total - len(remaining) - total_skipped
    print(f'\n=== FINAL: {added}/{total} added, {len(remaining)} failed, {total_skipped} skipped ===', flush=True)
    if remaining:
        print('Permanently failed:', flush=True)
        for f in remaining:
            print(f'  - {Path(f).stem}', flush=True)

    # Verify
    results = await g.search('architecture', group_ids=['localizationtools'])
    print(f'Verification search "architecture": {len(results)} facts', flush=True)


if __name__ == '__main__':
    import logging
    logging.basicConfig(level=logging.WARNING)
    asyncio.run(main())
