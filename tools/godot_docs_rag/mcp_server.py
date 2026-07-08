#!/usr/bin/env python3
"""
MCP stdio server — Godot Docs RAG (Neo4j backend)

Implements JSON-RPC 2.0 over stdio (MCP transport).
Loads the embedding model once at startup; queries Neo4j for retrieval;
LM Studio synthesizes answers. Falls back to truncated context if LM Studio is down.

Env vars:
  NEO4J_URI            bolt://localhost:7687  (default)
  NEO4J_USER           neo4j                  (default)
  NEO4J_PASSWORD       godotrag               (default)
  LMSTUDIO_URL         http://localhost:1234/v1 (default)
  LMSTUDIO_MODEL       local-model            (default)
  LMSTUDIO_MAX_WORDS   context words sent to LM Studio   (default: 2000)
  LMSTUDIO_FALLBACK_WORDS  words returned to Claude when LM Studio is down (default: 400)
"""

import json
import os
import sys

from neo4j import GraphDatabase
from sentence_transformers import SentenceTransformer
from openai import OpenAI

# ── Config ────────────────────────────────────────────────────────────────────

NEO4J_URI      = os.environ.get("NEO4J_URI", "bolt://localhost:7687")
NEO4J_USER     = os.environ.get("NEO4J_USER", "neo4j")
NEO4J_PASSWORD = os.environ.get("NEO4J_PASSWORD", "godotrag")
LMSTUDIO_URL   = os.environ.get("LMSTUDIO_URL", "http://localhost:1234/v1")
LMSTUDIO_MODEL = os.environ.get("LMSTUDIO_MODEL", "local-model")
MAX_WORDS      = int(os.environ.get("LMSTUDIO_MAX_WORDS", "2000"))
FALLBACK_WORDS = int(os.environ.get("LMSTUDIO_FALLBACK_WORDS", "400"))
EMBED_MODEL    = "all-MiniLM-L6-v2"

SYSTEM_PROMPT = (
    "You are a Godot 4 game engine expert. Answer the user's question using the "
    "documentation excerpts provided. Be concise and include GDScript code examples "
    "where relevant. If the answer is not in the excerpts, say so clearly."
)

# ── Startup: load model + connect to Neo4j ────────────────────────────────────

try:
    _embed_model = SentenceTransformer(EMBED_MODEL)
    _driver      = GraphDatabase.driver(NEO4J_URI, auth=(NEO4J_USER, NEO4J_PASSWORD))
    _INIT_ERROR  = None
except Exception as e:
    _embed_model = None
    _driver      = None
    _INIT_ERROR  = str(e)

# ── Retrieval ─────────────────────────────────────────────────────────────────

def _retrieve(query: str, max_words: int) -> str:
    vec = _embed_model.encode([query])[0].tolist()

    with _driver.session() as session:
        result = session.run("""
            CALL db.index.vector.queryNodes('doc_embeddings', 5, $vec)
            YIELD node AS seed, score
            WITH collect(seed) AS seeds
            UNWIND seeds AS seed
            OPTIONAL MATCH (seed)-[:LINKS_TO]->(neighbor)
            WITH seeds, collect(DISTINCT neighbor) AS neighbors
            WITH seeds + [n IN neighbors WHERE NOT n IN seeds] AS all_docs
            UNWIND all_docs AS d
            RETURN DISTINCT d.path_key AS path_key, d.title AS title, d.text AS text
            LIMIT 30
        """, vec=vec)
        rows = result.data()

    parts = []
    total = 0
    for row in rows:
        if total >= max_words:
            break
        words = (row["text"] or "").split()
        budget = max_words - total
        parts.append(f"## {row['title']}\n{' '.join(words[:budget])}")
        total += min(len(words), budget)

    return "\n\n---\n\n".join(parts)


# ── Tool implementation ───────────────────────────────────────────────────────

def search_godot_docs(query: str) -> str:
    if _INIT_ERROR:
        return f"RAG unavailable: {_INIT_ERROR}"

    context = _retrieve(query, MAX_WORDS)

    try:
        client = OpenAI(api_key="lm-studio", base_url=LMSTUDIO_URL)
        response = client.chat.completions.create(
            model=LMSTUDIO_MODEL,
            messages=[
                {"role": "system", "content": SYSTEM_PROMPT},
                {"role": "user", "content": f"Documentation:\n\n{context}\n\n---\n\nQuestion: {query}"},
            ],
            temperature=0.1,
            max_tokens=1024,
        )
        return response.choices[0].message.content

    except Exception as e:
        fallback = _retrieve(query, FALLBACK_WORDS)
        return (
            f"[LM Studio unavailable ({e}). Returning context for Claude to process.]\n\n"
            f"{fallback}"
        )


# ── MCP JSON-RPC stdio transport ──────────────────────────────────────────────

TOOL_DEF = {
    "name": "search_godot_docs",
    "description": (
        "Search the local Godot 4 documentation graph RAG (Neo4j + vector embeddings). "
        "Returns a synthesized answer from 1,591 Godot docs pages. "
        "Use whenever you need to look up a Godot 4 class, method, signal, "
        "property, or tutorial — prefer this over guessing from training data."
    ),
    "inputSchema": {
        "type": "object",
        "properties": {
            "query": {
                "type": "string",
                "description": "The question or topic to look up in the Godot docs",
            }
        },
        "required": ["query"],
    },
}


def _send(obj: dict) -> None:
    sys.stdout.write(json.dumps(obj) + "\n")
    sys.stdout.flush()


def _handle(msg: dict) -> None:
    method = msg.get("method", "")
    msg_id = msg.get("id")

    if method == "initialize":
        _send({
            "jsonrpc": "2.0",
            "id": msg_id,
            "result": {
                "protocolVersion": "2024-11-05",
                "capabilities": {"tools": {}},
                "serverInfo": {"name": "godot-docs-rag", "version": "2.0.0"},
            },
        })

    elif method == "notifications/initialized":
        pass

    elif method == "tools/list":
        _send({
            "jsonrpc": "2.0",
            "id": msg_id,
            "result": {"tools": [TOOL_DEF]},
        })

    elif method == "tools/call":
        params = msg.get("params", {})
        name   = params.get("name")
        args   = params.get("arguments", {})

        if name == "search_godot_docs":
            try:
                answer = search_godot_docs(args.get("query", ""))
                _send({
                    "jsonrpc": "2.0",
                    "id": msg_id,
                    "result": {
                        "content": [{"type": "text", "text": answer}],
                        "isError": False,
                    },
                })
            except Exception as e:
                _send({
                    "jsonrpc": "2.0",
                    "id": msg_id,
                    "result": {
                        "content": [{"type": "text", "text": f"Tool error: {e}"}],
                        "isError": True,
                    },
                })
        else:
            _send({
                "jsonrpc": "2.0",
                "id": msg_id,
                "error": {"code": -32601, "message": f"Unknown tool: {name}"},
            })

    elif msg_id is not None:
        _send({
            "jsonrpc": "2.0",
            "id": msg_id,
            "error": {"code": -32601, "message": f"Unknown method: {method}"},
        })


def main() -> None:
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            _handle(json.loads(line))
        except json.JSONDecodeError as e:
            sys.stderr.write(f"[godot-docs-rag] JSON error: {e}\n")
            sys.stderr.flush()


if __name__ == "__main__":
    main()
