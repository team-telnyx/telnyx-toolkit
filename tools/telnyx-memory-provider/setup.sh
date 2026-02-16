#!/usr/bin/env bash
set -euo pipefail

# Telnyx Memory Provider Setup Script
# Configures OpenClaw's memory_search to use Telnyx for embeddings
#
# Modes:
#   (default)   Configure memory search + schedule post-restart verification
#   --verify    Verify memory search is working (run after gateway restart)
#   --cleanup   Remove verification section from HEARTBEAT.md
#   --status    Show current memory search status

TELNYX_EMBEDDING_URL="https://api.telnyx.com/v2/ai/openai"
DEFAULT_MODEL="thenlper/gte-large"
HEARTBEAT_FILE="$HOME/.openclaw/workspace/HEARTBEAT.md"
HEARTBEAT_MARKER="## Verify Telnyx Memory Provider"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

print_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
}

# --- Dependency & Detection ---

check_dependencies() {
    local missing=()

    if ! command -v jq &> /dev/null; then
        missing+=("jq")
    fi

    if ! command -v curl &> /dev/null; then
        missing+=("curl")
    fi

    if [[ ${#missing[@]} -gt 0 ]]; then
        print_error "Missing required tools: ${missing[*]}"
        echo "Install with: brew install ${missing[*]} (macOS) or apt install ${missing[*]} (Linux)"
        exit 1
    fi
}

detect_config() {
    if [[ -n "${OPENCLAW_CONFIG:-}" ]] && [[ -f "$OPENCLAW_CONFIG" ]]; then
        echo "$OPENCLAW_CONFIG"
    elif [[ -n "${CLAWDBOT_CONFIG:-}" ]] && [[ -f "$CLAWDBOT_CONFIG" ]]; then
        echo "$CLAWDBOT_CONFIG"
    elif [[ -f "$HOME/.openclaw/openclaw.json" ]]; then
        echo "$HOME/.openclaw/openclaw.json"
    elif [[ -f "$HOME/.clawdbot/clawdbot.json" ]]; then
        echo "$HOME/.clawdbot/clawdbot.json"
    else
        echo ""
    fi
}

# --- API Key Validation ---

validate_key() {
    local api_key="$1"
    local model="$2"

    print_step "Validating API key against Telnyx embedding endpoint..."

    local http_code
    http_code=$(curl -s -o /dev/null -w "%{http_code}" \
        -H "Authorization: Bearer $api_key" \
        -H "Content-Type: application/json" \
        -d "{\"input\": \"test\", \"model\": \"$model\"}" \
        "${TELNYX_EMBEDDING_URL}/embeddings" 2>/dev/null || echo "000")

    if [[ "$http_code" == "200" ]]; then
        print_success "API key is valid."
        return 0
    elif [[ "$http_code" == "401" ]]; then
        print_fail "Authentication failed (401). TELNYX_API_KEY is invalid or malformed."
        return 1
    elif [[ "$http_code" == "403" ]]; then
        print_fail "Forbidden (403). Key lacks permissions. Check scopes at https://portal.telnyx.com/#/app/api-keys"
        return 1
    elif [[ "$http_code" == "422" ]]; then
        print_fail "Bad request (422). Check model name: $model"
        return 1
    elif [[ "$http_code" == "000" ]]; then
        print_fail "Connection failed. Could not reach ${TELNYX_EMBEDDING_URL}/embeddings"
        return 1
    else
        print_fail "Unexpected response: HTTP $http_code"
        return 1
    fi
}

# --- Preflight Check ---

# Check for orphaned state from interrupted reindex across all agent databases
preflight_check() {
    local memory_dir="$HOME/.openclaw/memory"

    if [[ ! -d "$memory_dir" ]]; then
        return 0
    fi

    local cleaned=false

    for db_file in "$memory_dir"/*.sqlite; do
        [[ -f "$db_file" ]] || continue
        local base_name="${db_file%.sqlite}"

        # Check for .tmp-* files alongside this database
        local has_tmp=false
        for f in "${base_name}".sqlite.tmp-*; do
            if [[ -f "$f" ]]; then
                has_tmp=true
                break
            fi
        done

        if [[ "$has_tmp" == true ]]; then
            local db_size
            db_size=$(stat -c%s "$db_file" 2>/dev/null || stat -f%z "$db_file" 2>/dev/null || echo "0")
            if [[ "$db_size" -le 70000 ]]; then
                local db_basename
                db_basename=$(basename "$base_name")
                print_warn "Detected orphaned reindex state (${db_basename}.sqlite <= 68KB with .tmp-* files)."
                rm -f "${base_name}".sqlite*
                cleaned=true
            fi
        fi
    done

    if [[ "$cleaned" == true ]]; then
        print_info "Orphaned reindex state cleaned up. Fresh reindex will run after restart."
    fi
}

# --- Config Operations ---

update_memory_config() {
    local config_file="$1"
    local api_key="$2"
    local model="$3"

    local current_config
    current_config=$(cat "$config_file")

    # Build the memorySearch JSON block using jq for safe value escaping
    local memory_config
    memory_config=$(jq -n \
        --arg model "$model" \
        --arg baseUrl "$TELNYX_EMBEDDING_URL" \
        --arg apiKey "$api_key" \
        '{
            "provider": "openai",
            "model": $model,
            "remote": {
                "baseUrl": $baseUrl,
                "apiKey": $apiKey,
                "batch": {
                    "enabled": false
                }
            },
            "fallback": "none",
            "chunking": {
                "tokens": 200,
                "overlap": 30
            }
        }')

    # Merge into config, creating agents.defaults path if needed
    local new_config
    new_config=$(echo "$current_config" | jq --argjson ms "$memory_config" '
        .agents //= {} |
        .agents.defaults //= {} |
        .agents.defaults.memorySearch = $ms
    ')

    # Write back with pretty-print
    echo "$new_config" | jq '.' > "$config_file"
    print_success "Updated memorySearch configuration in $config_file"
}

validate_config() {
    local config_file="$1"

    # Check JSON syntax
    if ! jq '.' "$config_file" > /dev/null 2>&1; then
        print_fail "Invalid JSON in config file."
        return 1
    fi

    # Check required fields exist with correct values
    local provider
    provider=$(jq -r '.agents.defaults.memorySearch.provider // empty' "$config_file")
    if [[ "$provider" != "openai" ]]; then
        print_fail "memorySearch.provider is not 'openai'."
        return 1
    fi

    local batch_enabled
    batch_enabled=$(jq '.agents.defaults.memorySearch.remote.batch.enabled' "$config_file")
    if [[ "$batch_enabled" != "false" ]]; then
        print_fail "memorySearch.remote.batch.enabled is not false."
        return 1
    fi

    local chunk_tokens
    chunk_tokens=$(jq -r '.agents.defaults.memorySearch.chunking.tokens // empty' "$config_file")
    if [[ "$chunk_tokens" != "200" ]]; then
        print_fail "memorySearch.chunking.tokens is not 200."
        return 1
    fi

    local fallback
    fallback=$(jq -r '.agents.defaults.memorySearch.fallback // empty' "$config_file")
    if [[ "$fallback" != "none" ]]; then
        print_fail "memorySearch.fallback is not 'none'."
        return 1
    fi

    print_success "Configuration validated successfully."
    return 0
}

show_config() {
    local config_file="$1"

    echo ""
    echo "Current memorySearch configuration:"
    echo "===================================="
    jq '.agents.defaults.memorySearch' "$config_file"
    echo ""
}

# --- HEARTBEAT.md Operations ---

schedule_verification() {
    if [[ ! -f "$HEARTBEAT_FILE" ]]; then
        print_warn "HEARTBEAT.md not found at $HEARTBEAT_FILE — skipping verification scheduling."
        echo "You will need to verify manually after restart: ./setup.sh --verify"
        return 0
    fi

    # Idempotent — skip if already scheduled
    if grep -q "$HEARTBEAT_MARKER" "$HEARTBEAT_FILE" 2>/dev/null; then
        print_info "Verification already scheduled in HEARTBEAT.md."
        return 0
    fi

    cat >> "$HEARTBEAT_FILE" <<'HEARTBEAT_EOF'

## Verify Telnyx Memory Provider
The memory provider was reconfigured to use Telnyx. Verify the reindex completed after gateway restart.

- [ ] Run `openclaw memory status` — confirm `Indexed: N/N files` with non-zero count and `Vector: ready`
- [ ] Run `openclaw memory search "test"` — confirm results with relevance scores are returned
- [ ] If both checks pass, remove the entire `## Verify Telnyx Memory Provider` section (heading and all items) from HEARTBEAT.md
- [ ] If checks fail, run `openclaw memory index`, wait 60 seconds, and recheck
- [ ] If still failing, run `tail -n 100 "$(ls -t /tmp/openclaw/openclaw-*.log | head -1)" | grep -E "(memory|embed|index)"` and report errors to the user
HEARTBEAT_EOF

    print_success "Verification checklist added to HEARTBEAT.md."
}

remove_verification() {
    if [[ ! -f "$HEARTBEAT_FILE" ]]; then
        print_info "HEARTBEAT.md not found — nothing to clean up."
        return 0
    fi

    if ! grep -q "$HEARTBEAT_MARKER" "$HEARTBEAT_FILE" 2>/dev/null; then
        print_info "No verification section found in HEARTBEAT.md."
        return 0
    fi

    local temp_file
    temp_file=$(mktemp)

    # Remove from marker heading to next ## heading (or EOF)
    awk -v marker="$HEARTBEAT_MARKER" '
        index($0, marker) == 1 { skip = 1; next }
        skip && /^## / { skip = 0 }
        !skip
    ' "$HEARTBEAT_FILE" > "$temp_file"

    mv "$temp_file" "$HEARTBEAT_FILE"
    print_success "Verification section removed from HEARTBEAT.md."
}

# --- Verification ---

verify_memory() {
    print_step "Verifying memory search configuration..."

    if ! command -v openclaw &> /dev/null; then
        print_fail "openclaw command not found."
        return 1
    fi

    local status_output
    status_output=$(openclaw memory status 2>&1 || true)

    echo ""
    echo "Memory status output:"
    echo "====================="
    echo "$status_output"
    echo ""

    local has_errors=false

    # Check indexed files
    if echo "$status_output" | grep -qE "Indexed: [1-9]"; then
        print_success "Memory files are indexed"
    else
        print_fail "No memory files indexed (or indexing in progress)"
        has_errors=true
    fi

    # Check vector status
    if echo "$status_output" | grep -q "Vector: ready"; then
        print_success "Vector index is ready"
    elif echo "$status_output" | grep -q "Vector:"; then
        print_fail "Vector index not ready"
        has_errors=true
    fi

    # Check batch disabled
    if echo "$status_output" | grep -q "Batch: disabled"; then
        print_success "Batch mode is disabled (correct for Telnyx)"
    elif echo "$status_output" | grep -q "Batch:"; then
        print_warn "Batch mode may not be disabled — check configuration"
    fi

    # Check model
    if echo "$status_output" | grep -q "$DEFAULT_MODEL"; then
        print_success "Using correct embedding model ($DEFAULT_MODEL)"
    elif echo "$status_output" | grep -q "Model:"; then
        print_fail "Not using expected model ($DEFAULT_MODEL)"
        has_errors=true
    fi

    echo ""

    if [[ "$has_errors" == true ]]; then
        print_fail "Verification FAILED"
        echo ""
        echo "Troubleshooting:"
        echo "  1. If reindex is still running, wait a few minutes and retry"
        echo "  2. Force reindex: openclaw memory index"
        echo "  3. Check logs: tail -n 100 \"\$(ls -t /tmp/openclaw/openclaw-*.log | head -1)\" | grep -E '(memory|embed|index)'"
        return 1
    else
        print_success "Verification PASSED — memory search is working correctly."
        return 0
    fi
}

# --- Main ---

main() {
    echo ""
    echo "╔═══════════════════════════════════════════╗"
    echo "║   Telnyx Memory Provider Setup            ║"
    echo "╚═══════════════════════════════════════════╝"
    echo ""

    check_dependencies

    # Parse arguments
    local mode="setup"
    local model="$DEFAULT_MODEL"
    local skip_backup=false
    local skip_test=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            --verify)
                mode="verify"
                shift
                ;;
            --cleanup)
                mode="cleanup"
                shift
                ;;
            --status)
                mode="status"
                shift
                ;;
            --model|-m)
                if [[ $# -lt 2 ]] || [[ "$2" == --* ]]; then
                    print_error "--model requires a value (e.g. --model thenlper/gte-large)"
                    exit 1
                fi
                model="$2"
                shift 2
                ;;
            --no-backup)
                skip_backup=true
                shift
                ;;
            --no-test)
                skip_test=true
                shift
                ;;
            --help|-h)
                echo "Usage: ./setup.sh [MODE] [OPTIONS]"
                echo ""
                echo "Modes:"
                echo "  (default)              Configure memory search + schedule verification"
                echo "  --verify               Verify memory search is working (run after restart)"
                echo "  --cleanup              Remove verification section from HEARTBEAT.md"
                echo "  --status               Show current memory search status"
                echo ""
                echo "Options (setup mode only):"
                echo "  --model, -m <name>     Embedding model (default: thenlper/gte-large)"
                echo "                         Other option: intfloat/multilingual-e5-large"
                echo "  --no-backup            Skip creating backup of current config"
                echo "  --no-test              Skip API key validation"
                echo "  --help, -h             Show this help message"
                echo ""
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done

    # Handle non-setup modes
    case "$mode" in
        verify)
            verify_memory
            exit $?
            ;;
        cleanup)
            remove_verification
            exit 0
            ;;
        status)
            exec openclaw memory status
            ;;
    esac

    # === SETUP MODE ===

    # Check TELNYX_API_KEY
    local api_key="${TELNYX_API_KEY:-}"
    if [[ -z "$api_key" ]]; then
        print_error "TELNYX_API_KEY is not set."
        echo ""
        echo "Set it with:"
        echo "  export TELNYX_API_KEY=\"your-api-key\""
        echo ""
        echo "Get your key from: https://portal.telnyx.com/#/app/api-keys"
        exit 1
    fi

    # Validate API key
    if [[ "$skip_test" != true ]]; then
        if ! validate_key "$api_key" "$model"; then
            print_error "API key validation failed. Fix the key before proceeding."
            exit 1
        fi
    fi

    # Detect config file
    print_step "Detecting config file..."
    local config_file
    config_file=$(detect_config)

    if [[ -z "$config_file" ]]; then
        print_error "No config file found."
        echo ""
        echo "Expected locations:"
        echo "  - ~/.openclaw/openclaw.json"
        echo "  - ~/.clawdbot/clawdbot.json"
        echo ""
        echo "Run 'openclaw onboard' to generate a config file."
        exit 1
    fi

    print_info "Found: $config_file"

    # Pre-flight: clean up orphaned reindex state
    preflight_check

    # Create backup
    local backup_file=""
    if [[ "$skip_backup" != true ]]; then
        backup_file="${config_file}.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$config_file" "$backup_file"
        print_info "Backup created: $backup_file"
    fi

    # Update config
    print_step "Updating memorySearch configuration (model: $model)..."
    update_memory_config "$config_file" "$api_key" "$model"

    # Validate — auto-restore from backup on failure
    print_step "Validating configuration..."
    if ! validate_config "$config_file"; then
        if [[ -n "$backup_file" ]] && [[ -f "$backup_file" ]]; then
            print_error "Validation failed. Restoring from backup..."
            cp "$backup_file" "$config_file"
            print_info "Restored: $backup_file"
        else
            print_error "Validation failed. No backup available — manual fix required."
        fi
        exit 1
    fi

    # Show result
    show_config "$config_file"

    # Schedule post-restart verification via HEARTBEAT.md
    schedule_verification

    echo ""
    print_success "Setup complete!"
    echo ""
    echo "Next steps:"
    echo "  1. Restart the gateway:  openclaw gateway restart"
    echo "  2. The reindex will run automatically (may take several minutes)"
    echo "  3. Verification runs automatically via HEARTBEAT.md"
    echo ""
    echo "After restart, you can also:"
    echo "  Verify manually:  ./setup.sh --verify"
    echo "  Check status:     ./setup.sh --status"
    echo "  Clean up:         ./setup.sh --cleanup"
    echo ""
    if [[ -n "$backup_file" ]]; then
        echo "Backup: $backup_file"
        echo ""
    fi
    print_warn "Do not kill the first session after restart — the reindex must complete."
    echo ""
}

main "$@"
