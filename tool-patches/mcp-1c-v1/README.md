# mcp-1c-v1 Local Patch

This backup intentionally does not include the full .tools directory.
To restore the local mcp-1c-v1 adjustments:
1. Clone https://github.com/FSerg/mcp-1c-v1.git into .tools/mcp-1c-v1.
2. Checkout the commit from BASE-COMMIT.txt.
3. Apply local-modifications.patch from the repository root.

Untracked qdrant_storage is not included; rebuild/reload the RAG index if needed.
