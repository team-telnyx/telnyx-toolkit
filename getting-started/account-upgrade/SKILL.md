---
name: account-upgrade
description: Upgrade Telnyx account from freemium to professional tier via GitHub or LinkedIn identity verification. Triggered by freemium-blocked API errors.
metadata: {"openclaw":{"emoji":"⬆️","requires":{"bins":["python3","gh"],"env":["TELNYX_API_KEY"]},"primaryEnv":"TELNYX_API_KEY"}}
---

# Account Upgrade

Upgrade a Telnyx account from freemium to professional tier via GitHub or LinkedIn identity verification. Typically triggered when the bot encounters a freemium-blocked operation.

## Quick Start

```bash
# GitHub (automated, no browser)
python3 {baseDir}/scripts/evaluate-upgrade.py \
  --github-token "$(bash {baseDir}/scripts/get-gh-token.sh)" \
  --api-key "$TELNYX_API_KEY"

# LinkedIn (requires browser for OAuth consent)
python3 {baseDir}/scripts/evaluate-upgrade.py \
  --linkedin --api-key "$TELNYX_API_KEY"
```

---

## Trigger Detection

Activate when ANY of these conditions occur:

### API Error Codes

| Error Code | Context | Meaning |
|------------|---------|---------|
| `10039` | SMS send | Destination not verified (freemium restriction) |
| `D60` | Voice call | Destination not verified (freemium restriction) |
| `10038` | Various | Feature not available on current plan (porting, short codes, number lookup, SIM, managed accounts, etc.) |

### Heuristic Triggers

- Phone number order fails after the first purchase (1 number limit)
- Balance/credit check returns low available credit ($10 ceiling)
- Inability to add funds / top up balance — freemium accounts cannot add balance or payment methods
- Account shows as "inactive" or "deactivated" due to $0 balance on freemium tier

### Explicit Triggers

- User requests an upgrade: "upgrade my account", "I need professional tier"
- Bot needs a non-freemium feature: "send SMS to unverified number", "port a number"
- User or bot tries to add balance/payment and is blocked by freemium restrictions

---

## Verification Methods

Two verification methods are available. Each can only be used once per account.

| Method | Flag | Browser? | Best for |
|--------|------|----------|----------|
| **GitHub** | `--github-token <TOKEN>` | No (automated) | Users with `gh` CLI installed |
| **LinkedIn** | `--linkedin` | Yes (OAuth consent) | Users without GitHub, or after GitHub rejection |

### Decision Tree

```
Which method to try?
├── Check ~/.telnyx/upgrade.json cache
│   ├── decision: APPROVED → Already upgraded, skip
│   ├── decision: PASS_TO_HUMAN → Under review, don't retry
│   └── decision: REJECTED or no cache → Continue
│
├── Check used_methods in cache or status endpoint
│   ├── github_oauth NOT used → Try GitHub first (automated, no browser)
│   ├── github_oauth used, linkedin_oauth NOT used → Try LinkedIn
│   └── Both used → Both methods exhausted, contact support
│
└── No preference → Try GitHub first (faster, no browser needed)
```

---

## GitHub Flow

### 1. Check Authentication

```bash
bash {baseDir}/scripts/check-gh-auth.sh
```

Returns JSON with `token_type`, `compatible`, `degraded`, and `missing_scopes`.

**Handle by token type:**
- `gho_` / `ghp_` (OAuth / Classic PAT) — check scopes, proceed
- `github_pat_` (Fine-grained PAT) — warn about degraded data, proceed anyway
- `ghs_` (App Installation) — ABORT, cannot verify human identity. User must run `gh auth login --web`

### 2. Refresh Scopes (if needed)

If `missing_scopes` is non-empty:

```bash
bash {baseDir}/scripts/refresh-gh-scopes.sh
```

- `success: true` — scopes refreshed without browser. Continue.
- `requires_browser: true` — deliver `device_code` and `verification_uri` to user:

**Telegram:**
```
🔑 Telnyx Account Upgrade

I need to verify your GitHub identity to upgrade your Telnyx account from freemium to professional tier. This is a one-time step.

👉 Visit: https://github.com/login/device
📝 Enter code: <DEVICE_CODE>
⏰ Expires in 15 minutes
```

**Slack:**
```
:key: *Telnyx Account Upgrade*

I need to verify your GitHub identity to upgrade your Telnyx account. This is a one-time step.

:point_right: <https://github.com/login/device|Open GitHub Device Authorization>
:pencil: Enter code: `<DEVICE_CODE>`
:timer_clock: Expires in 15 minutes
```

### 3. Wait for Authorization

```bash
bash {baseDir}/scripts/wait-for-auth.sh [--pid <PID>]
```

### 4. Get Token and Submit

```bash
python3 {baseDir}/scripts/evaluate-upgrade.py \
  --github-token "$(bash {baseDir}/scripts/get-gh-token.sh)" \
  --api-key "$TELNYX_API_KEY"
```

---

## LinkedIn Flow

### 1. Start OAuth

```bash
python3 {baseDir}/scripts/evaluate-upgrade.py --linkedin --api-key "$TELNYX_API_KEY"
```

Returns `{ action: "open_url", url: "<linkedin_oauth_url>" }` on stderr.

### 2. Present URL to User

**Telegram:**
```
🔗 Telnyx Account Upgrade — LinkedIn Verification

I need to verify your identity via LinkedIn to upgrade your Telnyx account. This is a one-time step.

👉 Open: <URL>
⏰ Link expires in 10 minutes

Sign in with your LinkedIn account when prompted. After authorizing, you can close the tab.
```

**Slack:**
```
:link: *Telnyx Account Upgrade — LinkedIn Verification*

I need to verify your identity via LinkedIn to upgrade your Telnyx account. This is a one-time step.

:point_right: <URL|Open LinkedIn Verification>
:timer_clock: Link expires in 10 minutes

Sign in with your LinkedIn account when prompted. After authorizing, you can close the tab.
```

### 3. Poll for Result

The script polls automatically. When the evaluation completes, it outputs the result JSON (same format as GitHub).

---

## Outcome Handling

### APPROVED

> Your Telnyx account has been upgraded to the professional tier! Retrying your request...

Retry the original blocked operation. If it still fails, refresh the API key via `account-signup` (same email, sign-in flow).

### REJECTED

Check `used_methods` and `next_steps` in output:
- **GitHub only used** — offer LinkedIn
- **LinkedIn only used** — offer GitHub
- **Both used** — direct to https://support.telnyx.com

### PASS_TO_HUMAN

> Your upgrade application is under manual review by the Telnyx team.

Set up periodic polling with `--poll-only`:

```bash
python3 {baseDir}/scripts/evaluate-upgrade.py \
  --poll-only --evaluation-id <ID> --api-key "$TELNYX_API_KEY"
```

---

## Scripts Reference

| Script | Purpose | Output |
|--------|---------|--------|
| `evaluate-upgrade.py` | Submit evaluation + poll for result | JSON (stdout) |
| `check-gh-auth.sh` | Check gh auth status, token type, scopes | JSON (stdout) |
| `refresh-gh-scopes.sh` | Refresh gh scopes via device code flow | JSON (stdout) |
| `wait-for-auth.sh` | Block until gh auth refresh completes | JSON (stdout) |
| `get-gh-token.sh` | Extract raw GitHub token | Token string (stdout) |

---

## Local State

Evaluation results are cached at `~/.telnyx/upgrade.json`:

```json
{
  "evaluation_id": "<uuid>",
  "status": "completed",
  "decision": "APPROVED",
  "used_methods": ["github_oauth"],
  "timestamp": "2025-01-15T10:30:00Z"
}
```

Always check this cache before submitting a new evaluation.

---

## API Key Resolution

The Telnyx API key is resolved in this order:

1. `--api-key` CLI argument
2. `TELNYX_API_KEY` environment variable
3. `~/.config/telnyx/config.json` (written by `telnyx auth setup`)

---

## Troubleshooting

| Issue | Solution |
|-------|---------|
| `gh` not installed | Install: https://cli.github.com or offer LinkedIn method |
| `ghs_` token (CI/CD) | Must `gh auth login --web` with personal account |
| Missing scopes | Run `refresh-gh-scopes.sh` to add `user,read:org` |
| API key invalid (401) | Check `TELNYX_API_KEY` or re-run account-signup |
| Already attempted (429) | Check `used_methods`, try the other method |
| Evaluation in progress (409) | Resume polling with `--poll-only` |
| Device code expired | Re-run `refresh-gh-scopes.sh` for a new code (max 3 retries) |
| Network errors | Script retries 3x with exponential backoff automatically |
