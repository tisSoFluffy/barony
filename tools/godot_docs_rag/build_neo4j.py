#!/usr/bin/env python3
"""
Build the Godot docs graph in Neo4j.

Usage:
  python3 tools/godot_docs_rag/build_neo4j.py [--wipe]

Reads RST source files from godot/godot-docs-html-stable/_sources,
embeds each page with all-MiniLM-L6-v2, and writes DocPage nodes +
LINKS_TO edges into Neo4j.

Neo4j connection: bolt://localhost:7687, user neo4j
Set NEO4J_PASSWORD env var (default: godotrag).
"""

import os
import re
import sys
from pathlib import Path

from neo4j import GraphDatabase
from sentence_transformers import SentenceTransformer

NEO4J_URI      = os.environ.get("NEO4J_URI", "bolt://localhost:7687")
NEO4J_USER     = os.environ.get("NEO4J_USER", "neo4j")
NEO4J_PASSWORD = os.environ.get("NEO4J_PASSWORD", "godotrag")

DOCS_DIR   = Path(__file__).parent.parent.parent / "godot" / "godot-docs-html-stable" / "_sources"
EMBED_MODEL = "all-MiniLM-L6-v2"
EMBED_DIMS  = 384
BATCH_SIZE  = 64


# ── RST parsing (same logic as godot_docs_rag.py) ────────────────────────────

def parse_rst(filepath: Path) -> dict:
    text = filepath.read_text(encoding="utf-8", errors="replace")

    anchor_match = re.search(r'^\.\. _([^:]+):\s*$', text, re.MULTILINE)
    anchor = anchor_match.group(1).strip() if anchor_match else None

    title_match = re.search(r'^(.+)\n[=\-~^#"]{3,}\s*$', text, re.MULTILINE)
    title = title_match.group(1).strip() if title_match else filepath.stem

    ref_targets = re.findall(r':ref:`[^<`]*<([^>]+)>`', text)
    doc_targets = re.findall(r':doc:`[^<`]*<([^>]+)>`', text)

    return {
        "anchor": anchor or "",
        "title": title,
        "text": _strip_rst(text),
        "ref_targets": ref_targets,
        "doc_targets": doc_targets,
    }


def _strip_rst(text: str) -> str:
    text = re.sub(r'^\.\. [a-z_-]+::.*\n((?:[ \t]+.*\n|\n)*)', '', text, flags=re.MULTILINE)
    text = re.sub(r':(?:ref|doc|class|meth|func|attr|prop|signal|const|enum|type|gdscript)`([^<`]+)\s*(?:<[^>]+>)?`', r'\1', text)
    text = re.sub(r'\*\*([^*]+)\*\*', r'\1', text)
    text = re.sub(r'\*([^*]+)\*', r'\1', text)
    text = re.sub(r'``([^`]+)``', r'\1', text)
    text = re.sub(r'`([^`]+)`__?', r'\1', text)
    text = re.sub(r'^\.\. .*\n', '', text, flags=re.MULTILINE)
    text = re.sub(r'^[ \t]*[+\-|]{3,}.*\n', '', text, flags=re.MULTILINE)
    text = re.sub(r'^[=\-~^#"]{3,}\s*$', '', text, flags=re.MULTILINE)
    text = re.sub(r'\n{3,}', '\n\n', text)
    return text.strip()


def _embed_text(doc: dict) -> str:
    words = doc["text"].split()
    snippet = doc["title"] + ". " + " ".join(words[:300])
    return snippet


# ── Neo4j helpers ─────────────────────────────────────────────────────────────

def _create_schema(session):
    session.run("""
        CREATE CONSTRAINT doc_page_key IF NOT EXISTS
        FOR (d:DocPage) REQUIRE d.path_key IS UNIQUE
    """)
    session.run(f"""
        CREATE VECTOR INDEX doc_embeddings IF NOT EXISTS
        FOR (d:DocPage) ON d.embedding
        OPTIONS {{indexConfig: {{
            `vector.dimensions`: {EMBED_DIMS},
            `vector.similarity_function`: 'cosine'
        }}}}
    """)
    print("Schema ready (constraint + vector index)")


def _wipe(session):
    session.run("MATCH (d:DocPage) DETACH DELETE d")
    print("Wiped existing DocPage nodes")


def _upsert_nodes_batch(session, batch: list[dict]):
    session.run("""
        UNWIND $rows AS row
        MERGE (d:DocPage {path_key: row.path_key})
        SET d.title   = row.title,
            d.anchor  = row.anchor,
            d.text    = row.text
    """, rows=batch)


def _set_embeddings_batch(session, batch: list[dict]):
    session.run("""
        UNWIND $rows AS row
        MATCH (d:DocPage {path_key: row.path_key})
        SET d.embedding = row.embedding
    """, rows=batch)


def _create_edges_batch(session, batch: list[dict]):
    session.run("""
        UNWIND $rows AS row
        MATCH (a:DocPage {path_key: row.src})
        MATCH (b:DocPage {path_key: row.dst})
        MERGE (a)-[:LINKS_TO]->(b)
    """, rows=batch)


# ── Main build ────────────────────────────────────────────────────────────────

def build(wipe: bool = False):
    print(f"Scanning {DOCS_DIR} ...")
    rst_files = sorted(DOCS_DIR.rglob("*.rst.txt"))
    print(f"Found {len(rst_files)} RST files")

    docs = {}
    anchor_map = {}

    for i, f in enumerate(rst_files):
        if i % 200 == 0:
            print(f"  Parsing {i}/{len(rst_files)} ...")
        path_key = str(f.relative_to(DOCS_DIR))[: -len(".rst.txt")]
        parsed = parse_rst(f)
        parsed["path_key"] = path_key
        docs[path_key] = parsed
        if parsed["anchor"]:
            anchor_map[parsed["anchor"]] = path_key

    driver = GraphDatabase.driver(NEO4J_URI, auth=(NEO4J_USER, NEO4J_PASSWORD))

    with driver.session() as session:
        if wipe:
            _wipe(session)
        _create_schema(session)

        # Phase 1: create nodes
        print("Writing DocPage nodes ...")
        node_batch = []
        for i, (path_key, doc) in enumerate(docs.items()):
            node_batch.append({
                "path_key": path_key,
                "title":    doc["title"],
                "anchor":   doc["anchor"],
                "text":     doc["text"],
            })
            if len(node_batch) >= BATCH_SIZE:
                _upsert_nodes_batch(session, node_batch)
                node_batch = []
                print(f"  {i+1}/{len(docs)} nodes written")
        if node_batch:
            _upsert_nodes_batch(session, node_batch)
        print(f"All {len(docs)} nodes written")

        # Phase 2: embed + store
        print(f"Loading embedding model {EMBED_MODEL} ...")
        model = SentenceTransformer(EMBED_MODEL)

        path_keys_list = list(docs.keys())
        snippets = [_embed_text(docs[k]) for k in path_keys_list]

        print(f"Embedding {len(snippets)} docs in batches of {BATCH_SIZE} ...")
        for batch_start in range(0, len(snippets), BATCH_SIZE):
            batch_end = min(batch_start + BATCH_SIZE, len(snippets))
            batch_snippets = snippets[batch_start:batch_end]
            embeddings = model.encode(batch_snippets, show_progress_bar=False).tolist()

            embed_batch = [
                {"path_key": path_keys_list[batch_start + j], "embedding": embeddings[j]}
                for j in range(len(embeddings))
            ]
            _set_embeddings_batch(session, embed_batch)

            if batch_start % (BATCH_SIZE * 5) == 0:
                print(f"  {batch_end}/{len(snippets)} embeddings stored")

        print("All embeddings stored")

        # Phase 3: edges
        print("Building LINKS_TO edges ...")
        edge_batch = []
        edge_count = 0
        skip_count = 0

        for path_key, doc in docs.items():
            parent_dir = Path(path_key).parent

            for anchor_target in doc["ref_targets"]:
                target = anchor_map.get(anchor_target)
                if target and target != path_key:
                    edge_batch.append({"src": path_key, "dst": target})
                    edge_count += 1

            for doc_target in doc["doc_targets"]:
                import os as _os
                normalized = _os.path.normpath(str(parent_dir / doc_target))
                if normalized in docs and normalized != path_key:
                    edge_batch.append({"src": path_key, "dst": normalized})
                    edge_count += 1
                else:
                    skip_count += 1

            if len(edge_batch) >= BATCH_SIZE * 4:
                _create_edges_batch(session, edge_batch)
                edge_batch = []

        if edge_batch:
            _create_edges_batch(session, edge_batch)

        print(f"Created {edge_count} edges ({skip_count} unresolved targets skipped)")

    driver.close()
    print("Done — Neo4j graph is ready.")
    print(f"  Nodes : {len(docs)}")
    print(f"  Edges : {edge_count}")
    print(f"  Index : doc_embeddings (cosine, {EMBED_DIMS}d)")


if __name__ == "__main__":
    import argparse
    ap = argparse.ArgumentParser(description="Build Godot docs graph in Neo4j")
    ap.add_argument("--wipe", action="store_true", help="Delete existing DocPage nodes before rebuilding")
    args = ap.parse_args()
    build(wipe=args.wipe)
