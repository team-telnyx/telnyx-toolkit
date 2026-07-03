---
name: telnyx-memory-provider
description: Configure OpenClaw's built-in memory_search to use Telnyx as its embedding provider. Drop-in replacement for OpenAI/Gemini — no extra API keys, automatic reindex.
author: aisling404
version: 2.0.0
metadata:
  clawdbot:
    emoji: "🧲"
    requires:
      anyBins: ["openclaw", "clawdbot"]
      env: ["TELNYX_API_KEY"]
---

# Telnyx Memory Provider

Configure OpenClaw's `memory_search` to use Telnyx for embedding. Drop-in replacement for OpenAI/Gemini — only `TELNYX_API_KEY` is required.

---

## Setup

### Run the Setup Script

```bash
./setup.sh
```

This will:
1. Validate `TELNYX_API_KEY` against the Telnyx embedding endpoint
2. Detect the config file (`~/.openclaw/openclaw.json` or `~/.clawdbot/clawdbot.json`)
3. Clean up orphaned reindex state if present
4. Back up the current config
5. Inject the `memorySearch` block into `agents.defaults`
6. Validate the resulting JSON (auto-restores from backup on failure)
7. Schedule post-restart verification in `~/.openclaw/workspace/HEARTBEAT.md`

**Options:**

| Flag | Description |
|------|-------------|
| `--model, -m <name>` | Embedding model (default: `thenlper/gte-large`). Use `intfloat/multilingual-e5-large` for multilingual workspaces. |
| `--no-backup` | Skip creating a backup of the current config |
| `--no-test` | Skip API key validation |
| `--verify` | Verify memory search is working (run after gateway restart) |
| `--cleanup` | Remove verification section from HEARTBEAT.md |
| `--status` | Show current memory search status |

### Restart the Gateway

**This step ends the current session.** The gateway restart terminates all active agent sessions, including this one. Complete the setup script before running this command.

```bash
openclaw gateway restart
```

The restart triggers a full reindex of stored memory. The first session after restart will be slower than usual. **Do not kill the first session** — an interrupted reindex leaves the database empty.

Verification runs automatically after restart via HEARTBEAT.md (scheduled by the setup script).

---

## Configuration Reference

The setup script writes this block into `agents.defaults.memorySearch`:

```json
{
    "provider": "openai",
    "model": "thenlper/gte-large",
    "remote": {
        "baseUrl": "https://api.telnyx.com/v2/ai/openai",
        "apiKey": "<TELNYX_API_KEY>",
        "batch": {
            "enabled": false
        }
    },
    "fallback": "none",
    "chunking": {
        "tokens": 200,
        "overlap": 30
    }
}
```

**These values are required — do not change them:**

| Setting | Value | Reason |
|---------|-------|--------|
| `provider` | `"openai"` | Telnyx is not a native OpenClaw provider; uses OpenAI-compatible API |
| `batch.enabled` | `false` | Telnyx does not implement the OpenAI `/v1/batches` API |
| `chunking.tokens` | `200` | Telnyx models have a 512-token limit; default 400 causes HTTP 500 errors |
| `chunking.overlap` | `30` | Maintains context between chunks at the reduced token size |
| `fallback` | `"none"` | Prevents silent fallback to other providers, surfaces errors immediately |

---

## Embedding Models

| Model | Language | When to Use |
|-------|----------|-------------|
| `thenlper/gte-large` | English | **Default.** Best general-purpose quality. |
| `intfloat/multilingual-e5-large` | 100 languages | Non-English or multilingual workspaces. |

---

## Reverting

Remove the `memorySearch` key from `agents.defaults` in the config file, then restart the gateway:

```bash
openclaw gateway restart
```

Or restore from the backup created by `setup.sh`:

```bash
cp ~/.openclaw/openclaw.json.backup.<timestamp> ~/.openclaw/openclaw.json
openclaw gateway restart
```

---

## Troubleshooting

### "HTTP 401" or "HTTP 403" from memory_search

API key is invalid or expired. Generate a new key at [portal.telnyx.com](https://portal.telnyx.com/#/app/api-keys), update the shell profile, reload, and re-run `./setup.sh`.

### memory_search returns no results

- Confirm the gateway was restarted after running setup (`openclaw gateway restart`).
- If there is no prior conversation history, there is nothing to recall yet.
- The first reindex can take several minutes for agents with extensive history. Let it complete.

### Interrupted reindex (empty database)

If a session was killed during the reindex, run `./setup.sh` again — it detects and cleans up orphaned state automatically. After the gateway restarts, verify with `./setup.sh --verify`.

---

## Related Skills

- **telnyx-embeddings** — CLI tools for direct text-to-vector embedding, semantic search, and bucket indexing.
- **telnyx-rag** — Full RAG pipeline with AI-powered Q&A, reranking, and source citations.
