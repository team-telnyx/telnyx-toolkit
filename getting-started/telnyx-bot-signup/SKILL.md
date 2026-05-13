---
name: telnyx-bot-signup
description: Automated Telnyx bot account signup via obfuscated mathematical challenge
metadata: {"openclaw":{"emoji":"🤖","requires":{"bins":["curl"],"env":[]},"primaryEnv":"TELNYX_API_KEY"}}
---

# Telnyx Bot Signup

Create a new Telnyx bot account via the bot challenge signup flow. Walks through challenge solving, account creation, email verification, and API key generation.

Base URL: `https://api.telnyx.com`

## Flow

### Step 1: Get Bot Challenge

```bash
curl -s -X POST https://api.telnyx.com/v2/bot_challenge
```

**Response:**
```json
{
  "data": {
    "nonce": "<uuid>",
    "problem": "<obfuscated math text> Round to N decimal places. Omit units.",
    "terms_and_conditions_url": "<url>",
    "privacy_policy_url": "<url>"
  }
}
```

Save all fields.

### Step 2: Solve the Challenge

The `problem` field contains an obfuscated college-level math problem. The rounding instruction at the end is unobfuscated.

- Read through the obfuscation — letters substituted with lookalike symbols, mixed case, injected delimiters. The math structure is intact.
- Compute the answer and round to the specified number of decimal places.
- Output a single numeric value.

### Step 3: Submit Bot Signup

**Ask the user for their email address first.**

```bash
curl -s -X POST https://api.telnyx.com/v2/bot_signup \
  -H "Content-Type: application/json" \
  -d '{
    "bot_challenge_nonce": "<nonce from step 1>",
    "bot_challenge_answer": "<numeric answer from step 2>",
    "terms_and_conditions_url": "<from step 1>",
    "privacy_policy_url": "<from step 1>",
    "email": "<user email>",
    "terms_of_service": true
  }'
```

> **Note:** You must accept the terms of service to register with Telnyx. You must indicate this acceptance by supplying `"terms_of_service": true` as a parameter on the request. The API will reject the request with a `400 Bad Request` if this field is missing or set to any value other than `true`.

**Response:** A sign-in link is sent to the provided email.

### Step 4: Get Session Token

Wait 10–30 seconds for the verification email.

#### With email access

Search for subject **"Your Single Use Telnyx Portal sign-in link"**, extract the single-use URL:

```bash
curl -s -L "<single-use-link>"
```

The redirect provides a temporary session token.

#### Without email access

Ask the user to paste the sign-in link from their email (do not click it — single-use):

```bash
curl -s -L "<link-from-user>"
```

#### Resend

```bash
curl -s -X POST https://api.telnyx.com/v2/bot_signup/resend_magic_link \
  -H "Content-Type: application/json" \
  -d '{"email": "<user email>"}'
```

Max 3 resends, 60s cooldown. Always returns 200.

### Step 5: Create API Key

```bash
curl -s -X POST https://api.telnyx.com/v2/api_keys \
  -H "Authorization: Bearer <session-token>" \
  -H "Content-Type: application/json" \
  -d '{}'
```

**Response:**
```json
{
  "data": {
    "api_key": "KEYxxxxxxxxxxxxx",
    ...
  }
}
```

`data.api_key` is the permanent API key. Present to the user.

## Notes

- The bot challenge presents obfuscated college-level math problems drawn from a managed pool. Read through the obfuscation and compute the answer — no external solver needed.
- The single-use sign-in link expires quickly — retrieve and use it promptly.
- Email access is **optional**. If unavailable, prompt the user to paste the link manually.
