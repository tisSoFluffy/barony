#!/usr/bin/env python3
"""
Godot Docs RAG — Neo4j backend

Usage:
  python3 tools/godot_docs_rag/godot_docs_rag.py query "how do I move a CharacterBody3D?"
  python3 tools/godot_docs_rag/godot_docs_rag.py query --context-only "what is Area3D?"
  python3 tools/godot_docs_rag/godot_docs_rag.py chat

Build the graph first:
  python3 tools/godot_docs_rag/build_neo4j.py

Neo4j connection: bolt://localhost:7687, user neo4j
Set NEO4J_PASSWORD (default: godotrag), LMSTUDIO_URL, LMSTUDIO_MODEL as needed.
"""

import os
import sys
import argparse

from neo4j import GraphDatabase
from sentence_transformers import SentenceTransformer
from openai import OpenAI

NEO4J_URI      = os.environ.get("NEO4J_URI", "bolt://localhost:7687")
NEO4J_USER     = os.environ.get("NEO4J_USER", "neo4j")
NEO4J_PASSWORD = os.environ.get("NEO4J_PASSWORD", "godotrag")
LMSTUDIO_URL   = os.environ.get("LMSTUDIO_URL", "http://localhost:1234/v1")
LMSTUDIO_MODEL = os.environ.get("LMSTUDIO_MODEL", "local-model")

EMBED_MODEL = "all-MiniLM-L6-v2"

SYSTEM_PROMPT = (
    "You are a Godot 4 game engine expert. Answer the user's question using the "
    "documentation excerpts provided. Be concise and include GDScript code examples "
    "where relevant. If the answer is not in the excerpts, say so clearly."
)

_model  = None
_driver = None


def _get_model() -> SentenceTransformer:
    global _model
    if _model is None:
        _model = SentenceTransformer(EMBED_MODEL)
    return _model


def _get_driver() -> GraphDatabase:
    global _driver
    if _driver is None:
        _driver = GraphDatabase.driver(NEO4J_URI, auth=(NEO4J_USER, NEO4J_PASSWORD))
    return _driver


# ── Retrieval ─────────────────────────────────────────────────────────────────

def retrieve(query: str, top_k: int = 5, hops: int = 1, max_words: int = 6000) -> str:
    model  = _get_model()
    driver = _get_driver()

    query_vec = model.encode([query])[0].tolist()

    with driver.session() as session:
        # Vector similarity search → then expand 1 hop via LINKS_TO
        if hops > 0:
            cypher = """
                CALL db.index.vector.queryNodes('doc_embeddings', $top_k, $vec)
                YIELD node AS seed, score
                WITH collect(seed) AS seeds
                UNWIND seeds AS seed
                OPTIONAL MATCH (seed)-[:LINKS_TO]->(neighbor)
                WITH seeds, collect(DISTINCT neighbor) AS neighbors
                WITH seeds + [n IN neighbors WHERE NOT n IN seeds] AS all_docs
                UNWIND all_docs AS d
                RETURN DISTINCT d.path_key AS path_key, d.title AS title, d.text AS text
                LIMIT $limit
            """
            limit = top_k * 6
        else:
            cypher = """
                CALL db.index.vector.queryNodes('doc_embeddings', $top_k, $vec)
                YIELD node AS d, score
                RETURN d.path_key AS path_key, d.title AS title, d.text AS text
            """
            limit = top_k

        result = session.run(cypher, vec=query_vec, top_k=top_k, limit=limit)
        rows = result.data()

    parts = []
    total_words = 0
    for row in rows:
        if total_words >= max_words:
            break
        words = (row["text"] or "").split()
        budget = max_words - total_words
        excerpt = " ".join(words[:budget])
        parts.append(f"## {row['title']}\n{excerpt}")
        total_words += min(len(words), budget)

    return "\n\n---\n\n".join(parts)


# ── LM Studio answer ──────────────────────────────────────────────────────────

def ask(question: str, top_k: int = 5, hops: int = 1, max_words: int = 2000) -> str:
    context = retrieve(question, top_k=top_k, hops=hops, max_words=max_words)
    client  = OpenAI(api_key="lm-studio", base_url=LMSTUDIO_URL)
    response = client.chat.completions.create(
        model=LMSTUDIO_MODEL,
        messages=[
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": f"Documentation:\n\n{context}\n\n---\n\nQuestion: {question}"},
        ],
        temperature=0.1,
        max_tokens=1024,
    )
    return response.choices[0].message.content


# ── CLI ───────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="Godot Docs RAG (Neo4j)")
    sub = parser.add_subparsers(dest="cmd")

    q = sub.add_parser("query", help="Ask a single question")
    q.add_argument("question", nargs="+")
    q.add_argument("--model",     default=LMSTUDIO_MODEL)
    q.add_argument("--url",       default=LMSTUDIO_URL)
    q.add_argument("--top-k",     type=int, default=5)
    q.add_argument("--hops",      type=int, default=1)
    q.add_argument("--max-words", type=int, default=2000)
    q.add_argument("--context-only", action="store_true")

    sub.add_parser("chat", help="Interactive chat loop")

    args = parser.parse_args()

    if args.cmd == "query":
        question = " ".join(args.question)
        if args.context_only:
            print(retrieve(question, top_k=args.top_k, hops=args.hops, max_words=args.max_words))
        else:
            print(ask(question, top_k=args.top_k, hops=args.hops, max_words=args.max_words))

    elif args.cmd == "chat":
        print("Godot Docs RAG (Neo4j)  |  type 'quit' to exit\n")
        while True:
            try:
                q_text = input("> ").strip()
            except (EOFError, KeyboardInterrupt):
                print()
                break
            if q_text.lower() in ("quit", "exit", "q"):
                break
            if not q_text:
                continue
            print()
            print(ask(q_text))
            print()

    else:
        parser.print_help()


if __name__ == "__main__":
    main()
