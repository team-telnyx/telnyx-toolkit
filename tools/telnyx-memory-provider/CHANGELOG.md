# Changelog

## [2.0.0] - 2026-02-13

### Added
- Automated setup script (`setup.sh`) following litellm-setup pattern
- Config injection via `jq --arg` for safe value escaping
- Timestamped config backup with auto-restore on validation failure
- Preflight cleanup of orphaned reindex state across all agent databases
- Post-restart verification scheduling via HEARTBEAT.md
- `--verify` mode for programmatic memory search verification (checks indexed files, vector readiness, batch mode, model)
- `--cleanup` mode for HEARTBEAT.md section removal
- `--status` mode for quick memory search status check
- Support for both OpenClaw and Clawdbot config paths
- README.md with comparison table, examples, and mode reference
