# Telnyx Memory Provider

> **Bridge skill.** This skill is a workaround for OpenClaw versions that don't have native Telnyx support. Once `provider: "telnyx"` ships in OpenClaw, this skill will be deprecated. Track the native provider PR: https://github.com/openclaw/openclaw/discussions (link TBD).

Configure OpenClaw's built-in `memory_search` to use Telnyx for embeddings instead of OpenAI, Gemini, or a local model.

## The Problem

OpenClaw's `memory_search` silently disables when no embedding provider is properly configured. The agent appears to "forget" things with no warning. Common causes:

- **OpenAI** requires a paid API key (Codex OAuth doesn't cover embeddings)
- **Gemini** has known batch-embedding bugs that prevent memory indexing
- **Local** requires a ~600MB model download with configuration compatibility issues

Telnyx's embedding API is OpenAI-compatible and already available to anyone with a `TELNYX_API_KEY`. This skill automates the full setup — config injection, API validation, and post-restart verification.

## Why Telnyx?

| | OpenAI | Gemini | Local | Telnyx |
|---|---|---|---|---|
| **Extra API key** | Yes (`OPENAI_API_KEY`) | Yes (`GOOGLE_API_KEY`) | No | No (uses `TELNYX_API_KEY`) |
| **Cost** | $0.02/1M tokens | Free tier (buggy) | Free | ~90% cheaper than OpenAI |
| **Setup friction** | Paid account required | Batch bugs | 600MB download | Already have the key |
| **Quality (MTEB avg)** | 62.3 | — | Varies | 63.1 (`gte-large`) |
| **Dimensions** | 1536 | 768 | Varies | 1024 |

## Installation

### Option A: Ask your bot

Copy the skill into your workspace and tell the bot to install it:

```bash
cp -r skills/telnyx-memory-provider ~/.openclaw/workspace/skills/
```

Then in your OpenClaw session:

> install the skill from ~/.openclaw/workspace/skills/telnyx-memory-provider

The bot reads `SKILL.md`, runs `setup.sh`, and handles the gateway restart and verification automatically.

### Option B: Manual setup

Requires `TELNYX_API_KEY` in your environment, plus `jq` and `curl`.

```bash
export TELNYX_API_KEY="KEYxxxxx"
~/.openclaw/workspace/skills/telnyx-memory-provider/setup.sh
openclaw gateway restart
```

After the restart, verify the reindex completed:

```bash
~/.openclaw/workspace/skills/telnyx-memory-provider/setup.sh --verify
~/.openclaw/workspace/skills/telnyx-memory-provider/setup.sh --cleanup
```

## How It Works

The setup has a lifecycle challenge: `openclaw gateway restart` applies the new config but also **kills the current agent session**. The memory reindex then runs asynchronously in the background with no session to monitor it. The script handles this in three phases:

1. **Before restart** — validates the API key against the Telnyx embedding endpoint, backs up `openclaw.json`, injects the `memorySearch` config block, and writes a verification checklist to `~/.openclaw/workspace/HEARTBEAT.md`
2. **Gateway restart** — the agent session dies, the gateway reloads config, and the reindex starts in the background
3. **After restart** — on the next heartbeat poll, the new agent session picks up the HEARTBEAT.md checklist, verifies the reindex completed (indexed file count, vector readiness, correct model), and removes the checklist on success

This bridges the session-death gap automatically. No manual intervention needed.

### What Gets Written to `openclaw.json`

The script injects this into `agents.defaults.memorySearch`:

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

Key settings:

- **`batch.enabled: false`** — OpenClaw can batch embedding requests into a single API call for efficiency. Telnyx's embedding endpoint doesn't support OpenAI's batch API format, so batching must be disabled. Without this, the indexer silently fails and the memory database ends up empty.
- **`chunking.tokens: 200`** — Memory files are split into chunks before embedding. The `gte-large` model has a 512-token context window — anything beyond that gets truncated and loses meaning. 200 tokens with 30-token overlap keeps each chunk well within limits while preserving context across chunk boundaries.
- **`fallback: "none"`** — By default, OpenClaw silently falls back to another embedding provider if the configured one fails. This masks configuration errors — you think Telnyx is working but it's actually using a fallback. Setting `"none"` surfaces errors immediately so misconfigurations are caught during setup, not discovered weeks later.

## Script Reference

### Modes

| Mode | Command | Description |
|------|---------|-------------|
| **Setup** (default) | `setup.sh` | Validate key, backup config, inject settings, schedule verification |
| **Verify** | `setup.sh --verify` | Check reindex status: indexed files, vector readiness, correct model, batch disabled |
| **Cleanup** | `setup.sh --cleanup` | Remove the verification checklist from HEARTBEAT.md |
| **Status** | `setup.sh --status` | Passthrough to `openclaw memory status` |

> **`Dirty: yes` in `openclaw memory status` is expected.** The CLI always reports `Dirty: yes` because it cannot see the running gateway's live index state. This is a reporting limitation, not an error — it does not affect memory search functionality.

### Setup Options

| Flag | Description |
|------|-------------|
| `--model, -m <name>` | Embedding model (default: `thenlper/gte-large`) |
| `--no-backup` | Skip creating a backup of the current config |
| `--no-test` | Skip API key validation |

### Verify Output

```
[PASS] Memory files are indexed
[PASS] Vector index is ready
[PASS] Batch mode is disabled (correct for Telnyx)
[PASS] Using correct embedding model (thenlper/gte-large)
[PASS] Verification PASSED — memory search is working correctly.
```

## Available Models

| Model | Dimensions | Language | Use Case |
|-------|------------|----------|----------|
| `thenlper/gte-large` | 1024 | English | Default. Best general-purpose quality. |
| `intfloat/multilingual-e5-large` | 1024 | 100 languages | Use for multilingual workspaces. |

```bash
setup.sh --model intfloat/multilingual-e5-large
```

## Reverting

Restore from the backup created during setup:

```bash
cp ~/.openclaw/openclaw.json.backup.<timestamp> ~/.openclaw/openclaw.json
openclaw gateway restart
```

Or remove the `memorySearch` key from `agents.defaults` in `openclaw.json` and restart.

## Related Skills

- **[telnyx-embeddings](../telnyx-embeddings/)** — CLI tools for direct text-to-vector, semantic search, and bucket indexing
- **[telnyx-rag](../telnyx-rag/)** — Full RAG pipeline with AI-powered Q&A and source citations
