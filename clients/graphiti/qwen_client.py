"""
Qwen + Ollama client for Graphiti.

Uses Ollama's native /api/chat with think=false and format=json for
reliable structured output from Qwen 3.5. The OpenAI-compatible
endpoint doesn't support think=false, causing empty responses.

Usage:
    from qwen_client import create_qwen_graphiti

    g = await create_qwen_graphiti()
    await g.add_episode(...)
    results = await g.search(...)
"""

import json
import logging
from types import SimpleNamespace

import httpx
from pydantic import BaseModel

from graphiti_core import Graphiti
from graphiti_core.llm_client import OpenAIClient, LLMConfig
from graphiti_core.embedder.client import EmbedderClient

logger = logging.getLogger(__name__)

# Few-shot examples keyed by Pydantic model __name__. MUST match actual schemas.
# Updated 2026-04-11 to match current graphiti_core schemas.
_FEW_SHOT_EXAMPLES: dict[str, str] = {
    'ExtractedEntities': '{"extracted_entities": [{"name": "FAISS", "entity_type_id": 0}, {"name": "PostgreSQL", "entity_type_id": 1}]}',
    'ExtractedEdges': '{"edges": [{"source_entity_name": "SystemA", "target_entity_name": "SystemB", "relation_type": "DEPENDS_ON", "fact": "SystemA depends on SystemB for data", "valid_at": null, "invalid_at": null}]}',
    'SummarizedEntities': '{"summaries": [{"name": "SystemA", "summary": "SystemA is a backend service that processes data"}]}',
    'NodeResolutions': '{"entity_resolutions": [{"id": "abc-123", "name": "SystemA", "duplicate_name": ""}]}',
    'EdgeDuplicate': '{"duplicate_facts": [], "contradicted_facts": []}',
    'SummaryDescription': '{"summary": "A component that does X", "description": "Detailed description of the component"}',
}


def _flatten_schema(schema: dict) -> dict:
    """Inline $ref/$defs so Qwen sees a flat schema without indirection.
    Handles circular references via a visited set."""
    defs = schema.pop('$defs', {})
    if not defs:
        return schema

    def _resolve(obj, _visiting: frozenset = frozenset()):
        if isinstance(obj, dict):
            if '$ref' in obj:
                ref_name = obj['$ref'].split('/')[-1]
                if ref_name in defs and ref_name not in _visiting:
                    return _resolve(dict(defs[ref_name]), _visiting | {ref_name})
                return obj  # cycle or missing -- leave as-is
            return {k: _resolve(v, _visiting) for k, v in obj.items()}
        if isinstance(obj, list):
            return [_resolve(item, _visiting) for item in obj]
        return obj

    return _resolve(schema)


# 2026-04-18: synonym-key map for robust wrapper remapping.
# Qwen 9B often returns plausible but wrong wrapper keys. We remap to the
# required top-level key if exactly one array/object is present.
_KEY_SYNONYMS: dict[str, set[str]] = {
    'extracted_entities': {
        'entities', 'entity_nodes', 'nodes', 'items', 'results',
        'entity_list', 'extractedEntities',
    },
    'edges': {
        'relations', 'relationships', 'extracted_edges', 'triples',
        'facts', 'edge_list',
    },
    'entity_resolutions': {
        'resolutions', 'nodes', 'resolved', 'entity_resolution',
    },
    'summaries': {
        'summarized_entities', 'summary_list', 'items',
    },
    'duplicate_facts': {'duplicates', 'duplicated_facts'},
    'contradicted_facts': {'contradictions'},
    'summary': {'text', 'description'},
}

# 2026-04-18: item-level synonym map for when Qwen uses wrong field names
# INSIDE array items (e.g. `entity` instead of `name`).
_ITEM_FIELD_SYNONYMS: dict[str, set[str]] = {
    'name': {'entity', 'entity_name', 'node', 'node_name', 'label', 'text'},
    'entity_type_id': {'type_id', 'entityTypeId', 'entity_type', 'type'},
    'source_entity_name': {'source', 'src', 'from', 'source_name', 'subject'},
    'target_entity_name': {'target', 'dst', 'to', 'target_name', 'object'},
    'relation_type': {'type', 'relation', 'predicate', 'verb', 'edge_type'},
    'fact': {'description', 'text', 'content', 'statement'},
    'summary': {'text', 'description', 'content'},
    'duplicate_name': {'duplicate', 'dup', 'dup_name', 'alias'},
    'id': {'idx', 'index'},
}


def _coerce_int_type_id(value):
    """Coerce a string entity_type_id to integer 0.

    Qwen often returns `"Component"` / `"System"` strings instead of integers.
    Since Graphiti defaults to a single `Entity` type (id=0), mapping any
    string to 0 is correct by default. Integers pass through unchanged.
    """
    if isinstance(value, int):
        return value
    if isinstance(value, str):
        # Try parse as integer first ("0", "1", etc.)
        try:
            return int(value)
        except ValueError:
            # Any non-numeric string → default type 0
            return 0
    if isinstance(value, float):
        return int(value)
    return 0


def _normalize_item(item: dict, required_fields: dict) -> dict:
    """Fix wrong field names + types inside one array item.

    Args:
        item: dict like {"entity": "X", "entity_type_id": "Component"}
        required_fields: dict mapping required field name -> JSON schema type

    Returns a dict with proper field names and coerced types.
    """
    if not isinstance(item, dict):
        return item
    out = dict(item)

    # Step 1: remap synonym field names to canonical names
    for canonical, synonyms in _ITEM_FIELD_SYNONYMS.items():
        if canonical not in out:
            for syn in synonyms:
                if syn in out:
                    out[canonical] = out.pop(syn)
                    break

    # Step 2: coerce types for known-integer fields
    if 'entity_type_id' in out:
        out['entity_type_id'] = _coerce_int_type_id(out['entity_type_id'])
    if 'id' in out and isinstance(out['id'], str):
        try:
            out['id'] = int(out['id'])
        except ValueError:
            pass  # leave as-is; Graphiti will error if needed

    # Step 3: ensure required fields exist; fill with sensible defaults
    for field_name, field_schema in required_fields.items():
        if field_name in out:
            continue
        ftype = field_schema.get('type') if isinstance(field_schema, dict) else None
        if ftype == 'integer':
            out[field_name] = 0
        elif ftype == 'string':
            out[field_name] = ''
        elif ftype == 'array':
            out[field_name] = []
        elif ftype == 'object':
            out[field_name] = {}
        elif ftype == 'boolean':
            out[field_name] = False
        elif ftype is None or ftype == 'null':
            out[field_name] = None

    return out


def _normalize_array_items(arr: list, item_schema: dict) -> list:
    """Apply item-level normalization to every element of an array."""
    if not isinstance(arr, list):
        return arr
    # Extract required fields from the items schema
    props = (item_schema or {}).get('properties', {}) or {}
    required = (item_schema or {}).get('required', []) or []
    required_fields = {k: v for k, v in props.items() if k in required}
    if not required_fields:
        # No known schema — pass through, just remap field names
        required_fields = {k: v for k, v in props.items()}
    return [_normalize_item(x, required_fields) for x in arr]


# 2026-04-18: regex patterns for prose-parsing Qwen's markdown responses.
# When Qwen ignores "JSON ONLY" and returns a numbered/bulleted list, extract
# the names directly instead of retrying (which loses content).
import re as _re
_PROSE_ENTITY_PATTERNS = [
    # "1. **Entity**: Name" or "- **Entity**: Name"
    _re.compile(r'(?m)^\s*(?:[-*]|\d+\.)\s+\*\*(?:Entity|Name)\*\*\s*:\s*[`"]?([^\n`"]+?)[`"]?\s*$'),
    # "- Name: `value`" pattern (bold name with backticks around entity)
    _re.compile(r'(?m)^\s*(?:[-*]|\d+\.)\s+\*\*([^*\n]+?)\*\*\s*[:\-]\s*[`"]([^\n`"]+)[`"]'),
    # "* entity_name" - simple bullet where the whole line is the entity
    _re.compile(r'(?m)^\s*[-*]\s+`?([A-Z][A-Za-z0-9_]{2,})`?\s*$'),
]

_PROSE_EDGE_PATTERNS = [
    # "- **Source Entity**: X" / "- **Target Entity**: Y" / "- **Relation Type**: Z" / "- **Fact**: F"
    # We extract per-edge block separated by blank lines or headers.
    None,  # sentinel — we use _parse_prose_edges below
]


def _parse_prose_entities(content: str) -> list[dict]:
    """Extract entity names from markdown prose.

    Returns a list of {"name": str, "entity_type_id": 0} dicts.
    Deduplicates by name, preserves order.
    """
    seen: set[str] = set()
    entities: list[dict] = []
    for pattern in _PROSE_ENTITY_PATTERNS:
        for match in pattern.finditer(content):
            name = match.group(1).strip().strip('`"')
            # Filter out common noise
            if len(name) < 2 or len(name) > 80:
                continue
            if name.lower() in {
                'entity', 'name', 'relation type', 'source entity', 'target entity',
                'fact', 'reasoning', 'classification', 'based on', 'note',
                'relationship', 'facts extracted',
            }:
                continue
            if name not in seen:
                seen.add(name)
                entities.append({'name': name, 'entity_type_id': 0})
    return entities


def _parse_prose_edges(content: str) -> list[dict]:
    """Extract edges from Qwen's markdown prose edge descriptions.

    Looks for blocks with **Source Entity**, **Target Entity**, **Relation Type**,
    and **Fact** patterns. Returns list of edge dicts.
    """
    # Split by edge separator (blank lines, horizontal rules, or "Facts Extracted:" header)
    # Each edge block should have all 4 components.
    edges: list[dict] = []
    src_re = _re.compile(r'\*\*(?:Source\s*Entity|Source|From|Subject)\*\*\s*:\s*`?([^\n`]+?)`?\s*(?:\n|$)', _re.IGNORECASE)
    tgt_re = _re.compile(r'\*\*(?:Target\s*Entity|Target|To|Object)\*\*\s*:\s*`?([^\n`]+?)`?\s*(?:\n|$)', _re.IGNORECASE)
    rel_re = _re.compile(r'\*\*(?:Relation\s*Type|Relation|Predicate|Verb)\*\*\s*:\s*`?([A-Z_][A-Z0-9_]*)`?\s*(?:\n|$)', _re.IGNORECASE)
    fact_re = _re.compile(r'\*\*(?:Fact|Description|Statement)\*\*\s*:\s*(.+?)(?:\n\n|\n\s*-\s*\*\*|\Z)', _re.IGNORECASE | _re.DOTALL)

    # Split content into candidate blocks (paragraphs / bullet groups)
    blocks = _re.split(r'\n\s*(?:\n+|---+)\s*', content)
    for block in blocks:
        src = src_re.search(block)
        tgt = tgt_re.search(block)
        rel = rel_re.search(block)
        fact = fact_re.search(block)
        if src and tgt and rel:
            edges.append({
                'source_entity_name': src.group(1).strip().strip('`"'),
                'target_entity_name': tgt.group(1).strip().strip('`"'),
                'relation_type': rel.group(1).strip().strip('`"').upper().replace(' ', '_'),
                'fact': (fact.group(1).strip().strip('`"') if fact else f"{src.group(1).strip()} {rel.group(1).strip().lower()} {tgt.group(1).strip()}"),
                'valid_at': None,
                'invalid_at': None,
            })
    return edges


def _salvage_prose(content: str, flat_schema: dict, model_name: str) -> str | None:
    """When Qwen returns markdown prose, extract structured data via regex.

    Returns JSON-encoded result matching schema, or None if prose pattern
    doesn't match.
    """
    req_props = flat_schema.get('properties', {}) or {}
    # Pick the primary array-valued required key
    array_keys = [k for k, v in req_props.items() if v.get('type') == 'array']
    if not array_keys:
        return None

    primary = array_keys[0]
    # Entity-type schemas
    if primary in ('extracted_entities',):
        items = _parse_prose_entities(content)
        if items:
            logger.debug(f'{model_name}: prose-extracted {len(items)} entities')
            return json.dumps({primary: items})
    # Edge-type schemas
    if primary in ('edges',):
        items = _parse_prose_edges(content)
        if items:
            logger.debug(f'{model_name}: prose-extracted {len(items)} edges')
            return json.dumps({primary: items})
    # Other schemas (resolutions, summaries, duplicates) — not handled by prose parser
    return None


def _strip_markdown_fences(content: str) -> str:
    """Strip ```json ... ``` or ``` ... ``` fences if present."""
    s = content.strip()
    if s.startswith('```'):
        # Remove opening fence (```json\n or ```\n)
        first_nl = s.find('\n')
        if first_nl > 0:
            s = s[first_nl + 1:]
        # Remove closing fence
        if s.rstrip().endswith('```'):
            s = s.rstrip()[:-3].rstrip()
    return s


def _parse_multiple_top_level(s: str) -> list | None:
    """Parse multiple JSON objects/arrays at top level, comma/newline-separated.
    Returns a list of parsed values, or None if nothing parsed."""
    decoder = json.JSONDecoder()
    results = []
    idx = 0
    s = s.strip()
    while idx < len(s):
        # Skip whitespace and separators
        while idx < len(s) and s[idx] in ' \t\n\r,':
            idx += 1
        if idx >= len(s):
            break
        try:
            val, end = decoder.raw_decode(s, idx)
            results.append(val)
            idx = end
        except json.JSONDecodeError:
            break
    return results if results else None


def _salvage_qwen_json(content: str, flat_schema: dict, model_name: str) -> str | None:
    """Parse Qwen response and coerce it into the required schema shape.

    Returns a JSON-encoded string matching the schema, or None if unsalvageable.

    Handles:
      - markdown code fences
      - naked arrays (wraps in expected key)
      - multiple top-level JSON objects (collects into array, wraps)
      - synonym wrapper keys (e.g. `entities` -> `extracted_entities`)
    """
    req_props = flat_schema.get('properties', {}) or {}
    req_keys = list(req_props.keys())
    if not req_keys:
        return content  # no schema constraint

    content = _strip_markdown_fences(content)
    if not content:
        return None

    # Try to parse as single value first
    try:
        decoder = json.JSONDecoder()
        # Find first JSON start token (either { or [)
        brace = content.find('{')
        bracket = content.find('[')
        starts = [s for s in (brace, bracket) if s >= 0]
        if not starts:
            return None
        start = min(starts)
        parsed, _end = decoder.raw_decode(content[start:])
    except json.JSONDecodeError:
        # Try multi-top-level parse
        parsed_list = _parse_multiple_top_level(content)
        if not parsed_list:
            return None
        # If we have multiple dicts, wrap under expected key (first array-valued prop)
        array_keys = [k for k, v in req_props.items() if v.get('type') == 'array']
        if array_keys:
            return json.dumps({array_keys[0]: parsed_list})
        return None

    # Got a parsed value. If it's a dict and has a required key, done.
    if isinstance(parsed, dict):
        if any(k in parsed for k in req_keys):
            # Normalize items inside any array-valued required key
            for rk, rv in req_props.items():
                if rv.get('type') == 'array' and isinstance(parsed.get(rk), list):
                    item_schema = rv.get('items', {}) or {}
                    parsed[rk] = _normalize_array_items(parsed[rk], item_schema)
            return json.dumps(parsed)
        # Try synonym remapping
        for req_key in req_keys:
            synonyms = _KEY_SYNONYMS.get(req_key, set())
            for syn in synonyms:
                if syn in parsed:
                    # Remap: use parsed[syn] as value for req_key
                    remapped = {req_key: parsed[syn]}
                    # Preserve other required keys if they happen to exist
                    for other in req_keys:
                        if other != req_key and other in parsed:
                            remapped[other] = parsed[other]
                    # Normalize array items if applicable
                    if req_props.get(req_key, {}).get('type') == 'array' and isinstance(remapped[req_key], list):
                        item_schema = req_props[req_key].get('items', {}) or {}
                        remapped[req_key] = _normalize_array_items(remapped[req_key], item_schema)
                    logger.debug(f'{model_name}: remapped wrapper {syn!r} -> {req_key!r}')
                    return json.dumps(remapped)
        # No synonym match. Maybe the dict itself is one item of the expected array.
        array_keys = [k for k, v in req_props.items() if v.get('type') == 'array']
        if array_keys and len(parsed) > 0:
            # Check if there are multiple top-level objects we should collect
            remainder = content[start:][_end:].strip()
            extras = _parse_multiple_top_level(remainder) if remainder else []
            wrapped = [parsed] + (extras or [])
            item_schema = req_props[array_keys[0]].get('items', {}) or {}
            wrapped = _normalize_array_items(wrapped, item_schema)
            logger.debug(f'{model_name}: wrapping {len(wrapped)} single-object(s) as array under {array_keys[0]!r}')
            return json.dumps({array_keys[0]: wrapped})
        return None

    # Got a parsed list (naked array case)
    if isinstance(parsed, list):
        array_keys = [k for k, v in req_props.items() if v.get('type') == 'array']
        if array_keys:
            item_schema = req_props[array_keys[0]].get('items', {}) or {}
            normalized = _normalize_array_items(parsed, item_schema)
            logger.debug(f'{model_name}: wrapping naked array under {array_keys[0]!r} ({len(normalized)} items normalized)')
            return json.dumps({array_keys[0]: normalized})
        return None

    return None


def _make_openai_response(content: str):
    """Create a minimal OpenAI-compatible response object for Graphiti's parser.

    Must satisfy both:
    - _handle_json_response: response.choices[0].message.content
    - _handle_structured_response: response.output_text, response.usage
    """
    message = SimpleNamespace(content=content, role='assistant')
    choice = SimpleNamespace(message=message, index=0, finish_reason='stop')
    usage = SimpleNamespace(input_tokens=0, output_tokens=0, prompt_tokens=0, completion_tokens=0)
    return SimpleNamespace(
        choices=[choice], id='ollama', model='qwen3.5:9b',
        output_text=content, usage=usage,
    )


class OllamaQwenClient(OpenAIClient):
    """
    Graphiti LLM client that uses Ollama's NATIVE /api/chat endpoint
    with think=false to disable Qwen 3.5's thinking mode.

    Why not OpenAI-compatible /v1/chat/completions?
    - Ollama's OpenAI shim doesn't support think=false
    - Without think=false, Qwen 3.5 puts output in 'thinking' field, returns empty 'response'
    - This causes all structured output to fail (empty JSON -> retry loop -> GPU maxed)
    """

    OLLAMA_BASE = 'http://localhost:11434'

    def __init__(self, config, **kwargs):
        super().__init__(config, **kwargs)
        self._http_client = httpx.AsyncClient(timeout=180.0)

    async def _create_structured_completion(
        self,
        model: str,
        messages: list,
        temperature: float | None,
        max_tokens: int,
        response_model: type[BaseModel],
        reasoning: str | None = None,
        verbosity: str | None = None,
    ):
        """
        Use Ollama's native /api/chat with think=false + format=json.
        Single attempt -- Graphiti's own retry loop handles failures.
        """
        schema = response_model.model_json_schema()
        flat_schema = _flatten_schema(dict(schema))
        model_name = response_model.__name__

        # Build system prompt with flattened schema + few-shot example
        parts = [
            'RESPOND WITH ONLY ONE VALID JSON OBJECT.',
            'NO explanations. NO markdown. NO code fences. NO text before or after the JSON.',
            'The JSON must be complete and properly terminated (all brackets and braces closed).',
            f'Required JSON schema: {json.dumps(flat_schema)}',
        ]
        if model_name in _FEW_SHOT_EXAMPLES:
            parts.append(f'Example of a correct response: {_FEW_SHOT_EXAMPLES[model_name]}')

        # messages are already OpenAI-format dicts (converted by _generate_response)
        ollama_messages = [{'role': 'system', 'content': '\n'.join(parts)}]
        for m in messages:
            ollama_messages.append({
                'role': m.get('role', 'user'),
                'content': str(m.get('content', '')),
            })

        # 1 retry (2 attempts total) -- sweet spot for 4B model.
        # 0 retries = too many failures. 3 retries = GPU saturation.
        for attempt in range(2):
            payload = {
                'model': model,
                'messages': ollama_messages,
                'format': 'json',
                'stream': False,
                'think': False,  # CRITICAL: disables Qwen thinking mode
                'options': {
                    'temperature': temperature or 0,
                    'num_predict': max(max_tokens, 2000),
                },
            }

            # Call Ollama with actionable error messages
            # DIAGNOSTIC 2026-04-18: log payload + response to /tmp/graphiti_trace.log
            import os as _os
            _trace = _os.environ.get('GRAPHITI_TRACE_LOG')
            if _trace:
                try:
                    with open(_trace, 'a') as _f:
                        _f.write(f'\n=== REQUEST model={model_name} attempt={attempt} ===\n')
                        _f.write(json.dumps(payload, default=str)[:4000] + '\n')
                except Exception:
                    pass
            try:
                resp = await self._http_client.post(f'{self.OLLAMA_BASE}/api/chat', json=payload)
                resp.raise_for_status()
                data = resp.json()
                if _trace:
                    try:
                        with open(_trace, 'a') as _f:
                            _f.write(f'=== RESPONSE model={model_name} attempt={attempt} ===\n')
                            _f.write(json.dumps(data, default=str)[:4000] + '\n')
                    except Exception:
                        pass
            except httpx.ConnectError:
                raise ConnectionError(
                    f'Cannot connect to Ollama at {self.OLLAMA_BASE}. Is Ollama running?'
                )
            except httpx.TimeoutException:
                raise TimeoutError(
                    f'Ollama did not respond within 180s. GPU may be overloaded. Model: {model}'
                )
            except httpx.HTTPStatusError as e:
                raise RuntimeError(
                    f'Ollama HTTP {e.response.status_code}: {e.response.text[:200]}'
                )

            # Check for Ollama error responses (200 with error body)
            if 'error' in data:
                raise RuntimeError(f'Ollama error: {data["error"]}')

            content = data.get('message', {}).get('content', '').strip()
            if not content:
                if attempt == 0:
                    logger.debug(f'Empty content for {model_name}, retrying...')
                    ollama_messages.append({'role': 'assistant', 'content': '{}'})
                    ollama_messages.append({'role': 'user', 'content': 'Your response was empty. Return valid JSON.'})
                    continue
                logger.warning(f'Ollama returned empty content for {model_name} after retry')
                raise ValueError(f'Ollama returned empty content for {model_name}')

            # 2026-04-18 robust parser (Stage 1): strip fences, salvage naked arrays,
            # parse multi-top-level-object output, remap synonym wrapper keys,
            # coerce item-level field names + types.
            salvaged = _salvage_qwen_json(content, flat_schema, model_name)
            if salvaged is not None:
                return _make_openai_response(salvaged)

            # 2026-04-18 Stage 2: prose extractor. If Qwen returned markdown
            # prose (ignoring "JSON ONLY" instruction), extract entities/edges
            # via regex. This preserves attempt-0 content which retry would lose.
            prose_salvaged = _salvage_prose(content, flat_schema, model_name)
            if prose_salvaged is not None:
                logger.info(f'{model_name}: prose-salvaged attempt-{attempt} content')
                return _make_openai_response(prose_salvaged)

            # All salvage failed — only retry on first attempt
            if attempt == 0:
                logger.debug(f'{model_name}: unparseable, retrying... first 200 chars: {content[:200]}')
                example = _FEW_SHOT_EXAMPLES.get(model_name, '')
                req_keys = list(flat_schema.get('properties', {}).keys())
                # Stronger hint: emphasize preserving the prior content, not regenerating
                hint = (
                    f'Your last response was not valid JSON. Convert your PREVIOUS response into JSON '
                    f'matching the schema EXACTLY. Required top-level keys: {req_keys}. '
                    f'DO NOT reduce the item count. DO NOT add commentary. Respond with ONLY the JSON.'
                )
                if example:
                    hint += f' Example: {example}'
                ollama_messages.append({'role': 'assistant', 'content': content[:2000]})
                ollama_messages.append({'role': 'user', 'content': hint})
                continue

            # Second attempt also unparseable — return raw, let Graphiti handle
            return _make_openai_response(content)

        return _make_openai_response(content)

    def _handle_structured_response(self, response):
        """Delegate to JSON response handler (we use chat/completions format)."""
        return self._handle_json_response(response)


class Model2VecEmbedder(EmbedderClient):
    """Local Model2Vec embedder -- zero API calls, 29K sentences/sec."""

    def __init__(self, model_name: str = 'minishlab/potion-multilingual-128M'):
        from model2vec import StaticModel
        self.model = StaticModel.from_pretrained(model_name)
        self.dim = self.model.dim

    async def create(self, input_data):
        if isinstance(input_data, str):
            input_data = [input_data]
        elif not isinstance(input_data, list):
            input_data = list(input_data)
        texts = [str(t) for t in input_data]
        vectors = self.model.encode(texts, normalize=True)
        if len(vectors) != 1:
            raise ValueError(f'create() received {len(texts)} inputs; use create_batch()')
        return vectors[0].tolist()

    async def create_batch(self, input_data_list):
        texts = [str(t) for t in input_data_list]
        vectors = self.model.encode(texts, normalize=True)
        return [v.tolist() for v in vectors]


class NonIndexingFalkorDriver:
    """FalkorDB driver that skips index creation (indexes already exist)."""
    pass


async def create_qwen_graphiti(
    graph_name: str = 'default',
    falkordb_host: str = 'localhost',
    falkordb_port: int = 6379,
    ollama_url: str = 'http://localhost:11434/v1',
    model: str = 'qwen3.5:9b',
) -> Graphiti:
    """
    Create a fully-local Graphiti instance:
    - LLM: Qwen 3.5 via Ollama (free)
    - Embeddings: Model2Vec (free, local)
    - Graph DB: FalkorDB (free, Docker)
    """
    from graphiti_core.driver.falkordb_driver import FalkorDriver

    llm_client = OllamaQwenClient(LLMConfig(
        api_key='ollama',
        base_url=ollama_url,
        model=model,
        small_model=model,
    ))
    # Set native Ollama base URL (strip /v1 suffix)
    base = ollama_url.rstrip('/')
    llm_client.OLLAMA_BASE = base[:-3] if base.endswith('/v1') else base

    embedder = Model2VecEmbedder()

    # FalkorDB crashes the connection when CREATE INDEX hits an
    # already-existing index. The FalkorDriver constructor schedules
    # build_indices_and_constraints as a background task, which kills
    # the connection for subsequent searches.
    #
    # Fix: Create FalkorDB client directly, then create a patched driver
    # that skips index creation (indexes already exist from first run).
    from falkordb.asyncio import FalkorDB as AsyncFalkorDB

    fdb_client = AsyncFalkorDB(host=falkordb_host, port=falkordb_port)

    # Temporarily disable asyncio loop detection so the constructor
    # doesn't schedule the background index task (which crashes the connection)
    import asyncio
    _orig_get_loop = asyncio.get_running_loop

    def _no_loop():
        raise RuntimeError('no loop')

    asyncio.get_running_loop = _no_loop
    try:
        driver = FalkorDriver(falkor_db=fdb_client)
        driver._database = graph_name
    finally:
        asyncio.get_running_loop = _orig_get_loop

    g = Graphiti(
        graph_driver=driver,
        llm_client=llm_client,
        embedder=embedder,
    )
    # Do NOT call build_indices_and_constraints -- indexes already exist

    return g
