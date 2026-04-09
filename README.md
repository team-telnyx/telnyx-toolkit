# Telnyx Toolkit

The complete toolkit for building with Telnyx. Includes **ready-to-use tools** and **SDK documentation** for all Telnyx APIs.

[![ClawHub](https://img.shields.io/badge/ClawHub-telnyx--toolkit-blue)](https://clawhub.ai/skills/telnyx-toolkit)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## Quick Start

```bash
export TELNYX_API_KEY="your_key_here"
```

### Install via ClawHub

```bash
clawhub install telnyx-toolkit
```

---

## 🚀 Getting Started

Two companion skills handle account lifecycle. Included with the toolkit, also installable standalone.

| Skill | Purpose | Install standalone |
|-------|---------|-------------------|
| **[Account Signup](getting-started/telnyx-bot-signup)** | Create a new account or sign into an existing one (PoW challenge → email → API key). Includes Python and C PoW solvers; C solver is 10–50x faster (optional, compile with `make`). | `clawhub install telnyx-bot-signup` |
| **[Account Upgrade](getting-started/telnyx-freemium-upgrade)** | Upgrade freemium → professional via GitHub or LinkedIn identity verification | `clawhub install telnyx-freemium-upgrade` |

- **Telnyx Bot Signup** — Use when no API key exists, the key is invalid/expired, or the user needs a new account. Works for both new and existing accounts.
- **Telnyx Freemium Upgrade** — Use when the account hits a freemium restriction (error codes `10039`, `D60`, `10038`, number limits, or inability to add funds).

See each skill's `SKILL.md` for complete instructions.

---

## 🔧 Tools (Ready-to-Use)

Standalone utilities with scripts you can run directly:

| Tool | Description |
|------|-------------|
| **[STT](tools/stt)** | Speech-to-text transcription (Whisper) |
| **[TTS](tools/tts)** | Text-to-speech synthesis |
| **[CLI](tools/cli)** | Telnyx CLI wrapper and helpers |
| **[Network](tools/network)** | WireGuard mesh networking, public IP exposure |
| **[RAG](tools/rag)** | Semantic search with Telnyx Storage + embeddings |
| **[10DLC Registration](tools/10dlc-registration)** | Interactive wizard for A2P messaging registration |
| **[Storage Backup](tools/storage-backup)** | Backup/restore workspace to Telnyx Storage |
| **[Voice SIP](tools/voice-sip)** | SIP-based voice call control |
| **[Embeddings](tools/embeddings)** | Semantic search & text embeddings (Telnyx-native) |

### Examples

```bash
# Transcribe audio
python3 tools/stt/scripts/telnyx-stt.py /path/to/audio.mp3

# Generate speech  
python3 tools/tts/scripts/telnyx-tts.py "Hello world" -o output.mp3

# Join mesh network
./tools/network/join.sh

# Index files for RAG
python3 tools/rag/sync.py

# Semantic search
python3 tools/embeddings/search.py "your query" --bucket your-bucket

# Index a file for search
python3 tools/embeddings/index.py upload /path/to/file.md

```

---

## 📚 API Documentation

SDK documentation for all Telnyx APIs, organized by language:

| Language | Path | Skills |
|----------|------|--------|
| **JavaScript** | [api/javascript](api/javascript) | 35 |
| **Python** | [api/python](api/python) | 35 |
| **Go** | [api/go](api/go) | 35 |
| **Java** | [api/java](api/java) | 35 |
| **Ruby** | [api/ruby](api/ruby) | 35 |

### API Categories

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

---

## 📱 WebRTC Client SDKs

Guides for building real-time voice apps on mobile and web:

| Platform | Path |
|----------|------|
| **iOS** | [webrtc-clients/ios](webrtc-clients/ios) |
| **Android** | [webrtc-clients/android](webrtc-clients/android) |
| **Flutter** | [webrtc-clients/flutter](webrtc-clients/flutter) |
| **JavaScript (Web)** | [webrtc-clients/javascript](webrtc-clients/javascript) |
| **React Native** | [webrtc-clients/react-native](webrtc-clients/react-native) |

---

## Structure

```
telnyx-toolkit/
├── SKILL.md              # ClawHub skill definition
├── getting-started/      # Account creation & upgrade
│   ├── telnyx-bot-signup/
│   └── telnyx-freemium-upgrade/
├── tools/                # Ready-to-use utilities
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
│   ├── javascript/
│   ├── python/
│   ├── go/
│   ├── java/
│   └── ruby/
└── webrtc-clients/       # Mobile/Web SDK guides
    ├── ios/
    ├── android/
    ├── flutter/
    ├── javascript/
    └── react-native/
```

---

## Resources

- [Telnyx API Docs](https://developers.telnyx.com)
- [Telnyx Portal](https://portal.telnyx.com)
- [API Reference](https://developers.telnyx.com/api/v2/overview)
- [ClawHub](https://clawhub.ai)

## License

MIT
