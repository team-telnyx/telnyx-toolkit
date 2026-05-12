# AGENTS.md

Operating instructions for AI coding agents working **on** this repo, and for runtime agents **consuming** the toolkit's tools and skills.

This file is a complement to `README.md` (human-facing) and `SKILL.md` (ClawHub skill manifest). When in doubt, prefer the commands here.

## What this repo is

The complete Telnyx toolkit: ready-to-use tools (STT, TTS, RAG, networking, 10DLC, embeddings, storage backup, voice/SIP, push-notification testing) plus SDK documentation for JavaScript, Python, Go, Java, and Ruby.

Two companion onboarding skills (`getting-started/telnyx-bot-signup`, `getting-started/telnyx-freemium-upgrade`) handle account lifecycle: proof-of-work signup → email confirm → API key issuance → freemium-to-professional upgrade. Both are installable standalone via ClawHub.

## When to use this repo

- An agent or developer needs ready-to-run Telnyx primitives — call control, SMS, STT/TTS, RAG-over-Telnyx-docs, 10DLC registration, eSIM/IoT networking — without writing the boilerplate from scratch.
- An agent needs to **create a Telnyx account programmatically** via proof-of-work signup (no human interaction required). See `getting-started/telnyx-bot-signup`.
- An agent needs an installable skill bundle for [ClawHub](https://clawhub.ai/skills/telnyx-toolkit).

## When NOT to use this repo

- Agent-rules configs for Cursor / Claude Code / Windsurf / Gemini Code Assist live in [`team-telnyx/ai`](https://github.com/team-telnyx/ai), not here. That repo carries `AGENTS.md` (the canonical one), `.cursorrules`, `.cursor/`, `.claude/`, `.windsurf/`, `gemini-extension.json`, plus 235+ Agent Skills.
- The OpenAPI spec lives in [`team-telnyx/openapi`](https://github.com/team-telnyx/openapi). Don't hand-edit a copy here.
- Generated SDK client code lives in `telnyx-node` / `telnyx-python` / `telnyx-go` / `telnyx-cli` (all Stainless-auto-generated — don't hand-edit there either).

## Working on this repo

### Layout

| Path | What it contains |
|---|---|
| `getting-started/telnyx-bot-signup/` | Proof-of-work signup challenge solver (Python + optional C solver, 10–50× faster). Account creation primitive. |
| `getting-started/telnyx-freemium-upgrade/` | GitHub / LinkedIn identity verification flow for freemium → professional upgrade. |
| `tools/cli/` | `telnyx` CLI wrapper. |
| `tools/stt/` | Speech-to-text helpers. |
| `tools/tts/` | Text-to-speech helpers. |
| `tools/rag/` | Retrieval-augmented generation over Telnyx docs. |
| `tools/10dlc-registration/` | A2P 10DLC brand + campaign provisioning. |
| `tools/network/` | eSIM / IoT cellular networking primitives. |
| `tools/voice-sip/` | Voice call control + SIP trunking primitives. |
| `tools/embeddings/` | Embedding-generation utilities against Telnyx Inference. |
| `tools/storage-backup/` | Object-storage backup tooling. |
| `tools/push-notification-tester/` | APNs / FCM push test harness for Telnyx WebRTC clients. |
| `tools/missions/` | Multi-step agent mission templates. |
| `api/` | API documentation snippets (per-language). |
| `webrtc-clients/` | WebRTC client reference snippets. |
| `SKILL.md` | ClawHub skill manifest (don't hand-edit; regenerated). |

### Safe commands

This repo is a collection of small per-tool packages — there's no monorepo-level build. Operate inside the relevant tool directory:

```bash
# Install a tool via ClawHub
clawhub install telnyx-toolkit
clawhub install telnyx-bot-signup
clawhub install telnyx-freemium-upgrade

# Run the bot-signup Python solver
cd getting-started/telnyx-bot-signup
python signup.py

# Run the bot-signup C solver (optional, 10-50x faster)
cd getting-started/telnyx-bot-signup
make
./solver
```

### Required environment

```bash
export TELNYX_API_KEY="your_key_here"
```

Issued post-signup. The bot-signup flow returns this in plain text.

## Authentication

- **API key (primary):** Bearer in the `Authorization` header against `https://api.telnyx.com/v2`. Same key works for the REST API and the live MCP server at `https://api.telnyx.com/v2/mcp`.
- **No-signup path (inference only):** POST to `https://x402.telnyx.com/v1/chat/completions`, receive HTTP 402 with an EIP-3009 USDC payment quote on Base mainnet, sign it, retry. See `https://telnyx.com/.well-known/x402`.

## Error handling

- API errors return a top-level `errors[]` array — each entry has `code`, `title`, `detail`, and (where available) `meta.url` linking to error docs.
- Retry on HTTP 429 (respect `Retry-After`) and on documented transient 5xx (502, 503, 504). Do not retry other 4xx responses.
- Inbound webhook delivery has built-in retries with exponential backoff.

## Agent fast path

- Agent entry point: https://telnyx.com/agents/start
- Site-wide index: https://telnyx.com/llms.txt
- Getting-started runbook: https://telnyx.com/getting-started.md
- Agent signup runbook: https://telnyx.com/agent-signup.md
- OpenAPI spec: https://telnyx.com/openapi.json
- MCP server card: https://telnyx.com/.well-known/mcp/server-card.json
- Agent skills index: https://telnyx.com/.well-known/agent-skills/index.json
- Pricing markdown: https://telnyx.com/pricing.md
- Canonical agent-config repo: https://github.com/team-telnyx/ai

## Win the Bot

This repository participates in Telnyx's agent-readiness initiative. See [ora.run/score/telnyx.com](https://ora.run/score/telnyx.com) for the live agent-readiness scorecard.
