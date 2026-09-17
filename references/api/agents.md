<!-- GENERATED FROM openapi.json — DO NOT EDIT. Run `pnpm skill:contract:generate`. -->

# TeamYou API Reference: Agents

Base URL `https://www.teamyou.com/api/external/v1`. Every request except `GET /openapi.json` carries
`Authorization: Bearer ty_<key>`. Rate limits: reads 100/min, writes 60/min, search 30/min
(all 1000/hour); every response carries `X-RateLimit-Limit`, `X-RateLimit-Remaining` and
`X-RateLimit-Reset`. The full machine-readable contract is `GET /openapi.json`.

### Register / refresh agent identity

```http
POST /agents/register
```

Display-only identity. Caller-declared mode is keyed on (user, slug). Provisioned OpenClaw mode accepts openclawInstanceId, verifies the authenticated key belongs to that clawctl instance, derives the canonical slug server-side, and reconciles grandfathered identities. Returns 200 idempotently. Skill version comes from the X-TeamYou-Version header (the legacy X-TeamYou-Skill-Version is still accepted for back-compat); variant from X-TeamYou-Skill-Variant. Not gated by registration; subject to the min-skill-version floor.

**Skill CLI:** `teamyou.sh ty agent register [--slug <slug> | --openclaw-instance-id <instance-id>] [--kind claude|codex|perplexity|openclaw|other] [--name <display name>] [--model <model>]`

**Request body:**

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| `slug` | string | no | Required in caller-declared mode. Stable identity key (user, slug). Idempotent on re-register. — len 1..64, pattern |
| `kind` | `claude` \| `codex` \| `perplexity` \| `openclaw` \| `other` | no | Caller-declared mode only. |
| `displayName` | string | no | Caller-declared mode only. — len 1..120 |
| `openclawInstanceId` | string | no | Required in provisioned OpenClaw mode. The authenticated key must be recorded on this clawctl instance; slug, kind, and displayName are then derived or preserved server-side. — len 1..255 |
| `model` | string | no | len 1..120 |
| `mcpServers` | McpServerInfo[] | no | max 50 items |
| `declaredSkills` | DeclaredSkill[] | no | max 200 items |
| `a2aCard` | object | no |  |

**Responses:**

- `200` — Registered agent + workspace summary. Malformed optional manifest fields are dropped and reported in warnings.
- `400` — Validation error — invalid body, query, or path param (code: validation_error or invalid_json). `details` carries Zod field errors; PATCH /edges also adds `formErrors`.
- `401` — Missing, malformed, expired, or revoked API key (code: unauthorized).
- `403` — Forbidden. One of: api_key_user_not_found (key belongs to a user absent from this environment); skill_update_required (skill below TEAMYOU_GATE_MIN_SKILL_VERSION; carries required_version, install_url, docs_url, possibly Deprecation/Sunset headers); or instance_key_mismatch (openclawInstanceId does not own the authenticated key).
- `409` — Conflict — the authenticated provisioned key is linked to an agent identity that cannot be safely reconciled (code: agent_identity_conflict).
- `429` — Rate limit exceeded (code: rate_limit_exceeded). Includes Retry-After and X-RateLimit-* headers.
- `500` — Internal server error (code: internal_error).

### Get this key’s registered agent

```http
GET /agents/me
```

Returns { agent: null } if the key has no linked agent. Not gated.

**Skill CLI:** `teamyou.sh ty agent whoami`

**Responses:**

- `200` — Registered agent (or null).
- `401` — Missing, malformed, expired, or revoked API key (code: unauthorized).
- `429` — Rate limit exceeded (code: rate_limit_exceeded). Includes Retry-After and X-RateLimit-* headers.

### Acknowledge the version-update nudge (relent one call)

```http
GET /agents/ack
```

Consumes a one-time ACK token from a client_update_nudge (403) response: relents this single call for the calling key and records the ack (the human-visible receipt). The token must belong to this key and be unconsumed — a re-hit or foreign token returns 400 ack_invalid. Bare requireApiKey (not registration-gated). Always available — the nudge’s relent escape is never removed. The response carries the cost (nag_interval, nag_acks_so_far) so acking is never made to look free. Note that a plain retry of the original request usually succeeds on its own: acking is the way to release the call immediately, not the only way to make progress.

**Skill CLI:** `teamyou.sh ty agent ack <token>`

**Parameters:**

- `token` (query, required) — string — The one-time nak_* token from the nag response.
- `mode` (query) — `human` | `auto` — How this deferral was decided. Omitted or "human" means a person chose to postpone: it counts toward tier graduation and toward the owner-visible "this agent can acknowledge" signal. Use "auto" when an unattended client is relenting on its own — it releases the call identically but is recorded separately and escalates nothing, so a cron that defers to keep running cannot drive itself to a harsher reminder tier. Report it honestly; "auto" is not a way to silence the reminder, only to keep it from compounding.

**Responses:**

- `200` — Call relented.
- `400` — Bad request — ack_invalid (the ACK token is missing, malformed, already used, or was not issued to this key). Make a gated call to receive a fresh nag and token.
- `401` — Missing, malformed, expired, or revoked API key (code: unauthorized).
- `403` — Forbidden — api_key_user_not_found (the key belongs to a user absent from this environment).
- `429` — Rate limit exceeded (code: rate_limit_exceeded). Includes Retry-After and X-RateLimit-* headers.
