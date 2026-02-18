---
name: telnyx-toolkit
description: Complete Telnyx toolkit — ready-to-use tools (STT, TTS, RAG, Networking, 10DLC) plus SDK documentation for JavaScript, Python, Go, Java, and Ruby.
metadata: {"openclaw":{"emoji":"📞","requires":{"env":["TELNYX_API_KEY"]},"primaryEnv":"TELNYX_API_KEY"}}
---

# Telnyx Toolkit

The complete toolkit for building with Telnyx. Includes **ready-to-use tools** and **SDK documentation** for all Telnyx APIs.

## Quick Start

```bash
export TELNYX_API_KEY="your_key_here"
```

---

## 🚀 Getting Started

Two companion skills handle account lifecycle. They are included with the toolkit and can also be installed independently via ClawHub.

| Skill | Purpose | Path | Install standalone |
|-------|---------|------|--------------------|
| **Account Signup** | Create a new account or sign into an existing one (PoW challenge → email → API key) | `{baseDir}/getting-started/account-signup/` | `clawhub install account-signup` |
| **Account Upgrade** | Upgrade freemium → professional via GitHub or LinkedIn identity verification | `{baseDir}/getting-started/account-upgrade/` | `clawhub install account-upgrade` |

### When to Use Account Signup

Hand off to **account-signup** when ANY of these are true:

- No API key exists (`TELNYX_API_KEY` not set, `~/.config/telnyx/config.json` missing)
- API key is invalid/expired (401 errors from Telnyx API)
- User wants to create a new Telnyx account
- API key needs to be refreshed after an upgrade (same email, new key)

> **Note:** The `bot_signup` endpoint handles both new and existing accounts transparently — just provide the user's email.

### When to Use Account Upgrade

Hand off to **account-upgrade** when ANY of these are true:

| Trigger | Detection |
|---------|-----------|
| Error `10039` | SMS send fails: "destination not verified" |
| Error `D60` | Voice call fails: "destination not verified" |
| Error `10038` | Feature blocked: "not available on current plan" |
| Number limit hit | Second phone number purchase fails |
| Cannot add funds | Balance top-up or payment method rejected |
| Explicit request | User says "upgrade my account" |

Before handing off, check `~/.telnyx/upgrade.json` — if `decision` is `APPROVED`, the account is already upgraded (retry the operation instead). If `PASS_TO_HUMAN`, it's under review (don't retry). See the account-upgrade SKILL.md for full decision tree.

Each skill has its own `SKILL.md` with complete instructions. Read the skill's SKILL.md before executing its workflow.

---

## 🔧 Tools (Ready-to-Use)

These are standalone utilities with scripts you can run directly:

| Tool | Description | Path |
|------|-------------|------|
| **Missions** | AI agent task tracking, voice/SMS assistants, scheduled calls | `{baseDir}/tools/missions/` |
| **STT** | Speech-to-text transcription (Whisper) | `{baseDir}/tools/stt/` |
| **TTS** | Text-to-speech synthesis | `{baseDir}/tools/tts/` |
| **CLI** | Telnyx CLI wrapper and helpers | `{baseDir}/tools/cli/` |
| **Network** | WireGuard mesh networking, public IP exposure | `{baseDir}/tools/network/` |
| **RAG** | Semantic search with Telnyx Storage + embeddings | `{baseDir}/tools/rag/` |
| **10DLC Registration** | Interactive wizard for A2P messaging registration | `{baseDir}/tools/10dlc-registration/` |
| **Storage Backup** | Backup/restore workspace to Telnyx Storage | `{baseDir}/tools/storage-backup/` |
| **Voice SIP** | SIP-based voice call control | `{baseDir}/tools/voice-sip/` |
| **Embeddings** | Semantic search & text embeddings (Telnyx-native) | `{baseDir}/tools/embeddings/` |

### Tool Usage Examples

```bash
# Create a mission and schedule calls
python3 {baseDir}/tools/missions/scripts/telnyx_api.py init "Find contractors" "Call contractors and get quotes" "User request" '[{"step_id": "calls", "description": "Make calls", "sequence": 1}]'

# Transcribe audio
python3 {baseDir}/tools/stt/scripts/telnyx-stt.py /path/to/audio.mp3

# Generate speech  
python3 {baseDir}/tools/tts/scripts/telnyx-tts.py "Hello world" -o output.mp3

# Join mesh network
{baseDir}/tools/network/join.sh

# Index files for RAG
python3 {baseDir}/tools/rag/sync.py

# 10DLC registration wizard
{baseDir}/tools/10dlc-registration/setup.sh

# Semantic search
python3 {baseDir}/tools/embeddings/search.py "your query" --bucket your-bucket

# Index a file for search
python3 {baseDir}/tools/embeddings/index.py upload /path/to/file.md

```

Each tool has its own `SKILL.md` with detailed usage instructions.

---

## 📚 API Documentation (SDK Reference)

SDK documentation for all Telnyx APIs, organized by language:

| Language | Path | Skills |
|----------|------|--------|
| **JavaScript** | `{baseDir}/api/javascript/` | 35 |
| **Python** | `{baseDir}/api/python/` | 35 |
| **Go** | `{baseDir}/api/go/` | 35 |
| **Java** | `{baseDir}/api/java/` | 35 |
| **Ruby** | `{baseDir}/api/ruby/` | 35 |

### API Categories

Each language includes documentation for:

- **Voice** — Calls, call control, conferencing, streaming, gather
- **Messaging** — SMS, MMS, profiles, hosted messaging
- **Numbers** — Search, purchase, configure, compliance
- **AI** — Inference, assistants, embeddings
- **Storage** — Object storage (S3-compatible)
- **SIP** — Trunking, connections, integrations
- **Video** — Video rooms and conferencing
- **Fax** — Programmable fax
- **IoT** — SIM management, wireless
- **Verify** — Phone verification, 2FA
- **Account** — Management, billing, reports
- **Porting** — Port numbers in/out
- **10DLC** — A2P messaging registration
- **TeXML** — TeXML applications
- **Networking** — Private networks, SETI
- **WebRTC** — Server-side WebRTC

### Finding API Docs

```
{baseDir}/api/{language}/telnyx-{capability}-{language}/SKILL.md
```

Example: `{baseDir}/api/python/telnyx-voice-python/SKILL.md`

---

## 📱 WebRTC Client SDKs

Guides for building real-time voice apps on mobile and web:

| Platform | Path |
|----------|------|
| **iOS** | `{baseDir}/webrtc-clients/ios/` |
| **Android** | `{baseDir}/webrtc-clients/android/` |
| **Flutter** | `{baseDir}/webrtc-clients/flutter/` |
| **JavaScript (Web)** | `{baseDir}/webrtc-clients/javascript/` |
| **React Native** | `{baseDir}/webrtc-clients/react-native/` |

---

## Structure

```
telnyx-toolkit/
├── SKILL.md              # This file (index)
├── getting-started/      # Account creation & upgrade
│   ├── account-signup/
│   └── account-upgrade/
├── tools/                # Ready-to-use utilities
│   ├── missions/         # AI agent task tracking
│   ├── stt/
│   ├── tts/
│   ├── cli/
│   ├── network/
│   ├── rag/
│   ├── 10dlc-registration/
│   ├── storage-backup/
│   ├── voice-sip/
│   └── embeddings/
├── api/                  # SDK documentation
│   ├── javascript/       # 35 skills
│   ├── python/           # 35 skills
│   ├── go/               # 35 skills
│   ├── java/             # 35 skills
│   └── ruby/             # 35 skills
└── webrtc-clients/       # Mobile/Web SDK guides
    ├── ios/
    ├── android/
    ├── flutter/
    ├── javascript/
    └── react-native/
```

## Resources

- [Telnyx API Docs](https://developers.telnyx.com)
- [Telnyx Portal](https://portal.telnyx.com)
- [API Reference](https://developers.telnyx.com/api/v2/overview)
