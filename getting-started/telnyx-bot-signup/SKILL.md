---
name: telnyx-bot-signup
description: Automated Telnyx bot account signup via challenge-response
metadata: {"openclaw":{"emoji":"🤖","requires":{"bins":["curl"],"env":[]},"primaryEnv":"TELNYX_API_KEY"}}
---

# Telnyx Bot Signup

Create a new Telnyx bot account via the challenge-response signup flow. Walks through challenge solving, account creation, email verification, and API key generation.

Base URL: `https://api.telnyx.com`

## Overview

The bot challenge (sometimes called "reverse-CAPTCHA") presents a problem that only an LLM can reliably solve. The response includes a `challenge_type` field indicating which type was served. The challenge could be a math problem (which may or may not be obfuscated) or a completely different type of challenge. Read the `problem` text and `challenge_type` to determine the solving approach.

## Flow

### Step 1: Get Bot Challenge

```bash
curl -s -X POST https://api.telnyx.com/v2/bot_challenge
```

**Optional model metadata:**

You may self-report your model's metadata by sending a JSON body with any or all of these fields:

```bash
curl -s -X POST https://api.telnyx.com/v2/bot_challenge \
  -H "Content-Type: application/json" \
  -d '{
    "llm_model_name": "<your model name>",
    "llm_parameter_count": "<parameter count>",
    "llm_quantization": "<quantization format>"
  }'
```

These fields are **optional** and purely for analytics. Only include them if:
1. You know the values for certain (don't guess or hallucinate)
2. You believe the person you are operating on behalf of would be okay sharing this information

If you'd prefer not to share, simply omit them — the request works without a body.

**Response (math challenge):**
```json
{
  "data": {
    "nonce": "<uuid>",
    "problem": "<may be obfuscated math text> Round to N decimal places. Omit units.",
    "challenge_type": "math",
    "terms_and_conditions_url": "<url>",
    "privacy_policy_url": "<url>"
  }
}
```

**Response (non-math challenge):**
```json
{
  "data": {
    "nonce": "<uuid>",
    "problem": "<problem text — no rounding instruction>",
    "challenge_type": "<challenge_type>",
    "terms_and_conditions_url": "<url>",
    "privacy_policy_url": "<url>"
  }
}
```

Save all fields. The `nonce` ties your answer to this specific challenge instance.

### Step 2: Solve the Challenge

Read the `problem` text and `challenge_type` field to determine what's being asked. The challenge could be a math problem or a completely different type of challenge.

**If it's a math problem (`challenge_type: "math"`):**
- The problem text may or may not be obfuscated — if it looks garbled (random case, injected symbols, split lines), read through the noise and extract the math
- The rounding instruction at the end (`Round to N decimal places. Omit units.`) is always unobfuscated
- Produce a single numeric answer rounded to the specified precision

**For other challenge types:**
- Read the problem text carefully — it will describe exactly what to do
- Produce the answer the problem asks for

No external solver is needed — the LLM agent does this step with reasoning alone.

### Step 3: Submit Bot Signup

**Ask the user for their email address first.**

```bash
curl -s -X POST https://api.telnyx.com/v2/bot_signup \
  -H "Content-Type: application/json" \
  -d '{
    "bot_challenge_nonce": "<nonce from step 1>",
    "bot_challenge_answer": "<answer from step 2>",
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

- The bot challenge could be a math problem or a completely different type of challenge. Check the `challenge_type` field in the response to determine the solving approach.
- Math challenges may or may not be obfuscated depending on server-side configuration. If the text looks clean, obfuscation is simply disabled.
- Non-math challenges are never obfuscated.
- Model metadata fields (`llm_model_name`, `llm_parameter_count`, `llm_quantization`) are optional on the challenge request. Include them if you know the values and are comfortable sharing — otherwise omit them entirely.
- The single-use sign-in link expires quickly — retrieve and use it promptly.
- Email access is **optional**. If unavailable, prompt the user to paste the link manually.
