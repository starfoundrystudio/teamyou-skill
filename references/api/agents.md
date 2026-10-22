<!-- GENERATED FROM openapi.json — DO NOT EDIT. Run `pnpm skill:contract:generate`. -->

# TeamYou API Reference: Agents

Base URL `https://www.teamyou.com/api/external/v1`. Every request except `GET /openapi.json` carries
`Authorization: Bearer ty_<key>`. Rate limits: reads 100/min, writes 60/min, search 30/min
(all 1000/hour); every response carries `X-RateLimit-Limit`, `X-RateLimit-Remaining` and
`X-RateLimit-Reset`. The full machine-readable contract is `GET /openapi.json`.

## Contents

- [List the agents on your account](#list-the-agents-on-your-account)
- [Register / refresh agent identity](#register--refresh-agent-identity)
- [Get this key’s registered agent](#get-this-keys-registered-agent)
- [Sign off a slug rename](#sign-off-a-slug-rename)
- [Acknowledge the version-update nudge (relent one call)](#acknowledge-the-version-update-nudge-relent-one-call)

### List the agents on your account

```http
GET /agents
```

Your peers: every agent registered on this account, with its kind, status, whether it is the primary, whether it is you, and when it was last seen. Address a handoff with `POST /checkin/send` using an `id` or `slug` from here. Keys and permissions are not included.

**Skill CLI:** `teamyou.sh ty agent list`

**Responses:**

- `200` — The agents on this account.
- `401` — Missing, malformed, expired, or revoked API key (code: unauthorized). A revoked key whose agent has been retired answers 403 agent_retired instead.
- `403` — Forbidden. One of: api_key_user_not_found (key belongs to a user absent from this environment); client_identification_required (no recognized X-TeamYou-Client; carries skill_install_url, registerUrl, docs_url; only when TEAMYOU_GATE_REQUIRE_IDENTIFIED_CLIENT); agent_not_registered (registerUrl, skill_install_url, docs_url); skill_update_required (required_version, install_url, docs_url; possibly Deprecation/Sunset headers); client_update_nudge (a soft, relent-able staleness nudge for an agentic client below the latest release when TEAMYOU_GATE_NAG_ENABLED is on; carries verified_version, required_version, upgrade_url, ack_url, ack_token, nag_interval, nag_acks_so_far, docs_url — upgrade to end it, or fetch ack_url to relent one call at a rising cost); insufficient_scope (the API key lacks this operation’s x-teamyou-scope; carries required_scope, granted_scopes, docs_url — NOT retryable: scopes are fixed at key creation, so create a new key with the required scope instead of retrying); agent_retired (this key was revoked and its agent has been retired; carries agent {id, slug}, retiredAt, harness and remove {schedule, keyFile} — switch to a new key for this account if you were given one, otherwise stop checking in to this account; NOT retryable with this key); or an AI-preference denial AI_UPDATE_DISABLED / AI_DELETE_DISABLED / AI_SHARE_DISABLED (an account-wide block in Settings > Agent permissions is on; carries requiredPreference, blockedPreferences (every preference in the way; a sharing call can be blocked by two), fix (one line to relay to your person as-is: which switch or switches to turn off, and where) and settingsUrl (the link to those switches) - NOT retryable until the person turns the block off). Scopes and AI preferences compose as AND — passing one does not bypass the other. Gate codes only apply when the corresponding env flag is enabled.
- `429` — Rate limit exceeded (code: rate_limit_exceeded). Includes Retry-After and X-RateLimit-* headers.
- `500` — Internal server error (code: internal_error).

### Register / refresh agent identity

```http
POST /agents/register
```

The identity other agents and check-in items address. Caller-declared mode is keyed on (user, slug); re-registering a slug attaches the calling key only when the caller already belongs to that agent or no other key that can still authenticate (not revoked, not expired) does — otherwise 409 agent_identity_in_use, because the identity receives that agent's check-in items. To rotate a key, revoke the old one in TeamYou first, then register with the new one. A slug the account's owner renamed you away from answers 409 agent_renamed with your new slug and the steps to switch; it never creates an agent, and registering under the new slug from your own key signs the rename off. Provisioned OpenClaw mode accepts openclawInstanceId, verifies the authenticated key belongs to that clawctl instance, derives the canonical slug server-side, and reconciles grandfathered identities. Returns 200 idempotently. Skill version comes from the X-TeamYou-Version header (the legacy X-TeamYou-Skill-Version is still accepted for back-compat); variant from X-TeamYou-Skill-Variant. Not gated by registration; subject to the min-skill-version floor. The response carries a checkin object telling you how to keep showing up — the setup snippet for your harness, the cadence to use, and how many items are already waiting. It is returned on EVERY register, so re-registering is how you get the snippet back.

**Skill CLI:** `teamyou.sh ty agent register [--slug <slug> | --openclaw-instance-id <instance-id>] [--kind claude|codex|perplexity|openclaw|muse|instinct|hermes|grok|chatgpt|other] [--name <display name>] [--model <model>]`

**Request body:**

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| `slug` | string | no | Required in caller-declared mode. Stable identity key (user, slug). Idempotent on re-register. — len 1..64, pattern |
| `kind` | `claude` \| `codex` \| `perplexity` \| `openclaw` \| `other` \| `muse` \| `instinct` \| `hermes` \| `grok` \| `chatgpt` | no | Caller-declared mode only. |
| `displayName` | string | no | Caller-declared mode only. — len 1..120 |
| `openclawInstanceId` | string | no | Required in provisioned OpenClaw mode. The authenticated key must be recorded on this clawctl instance; slug, kind, and displayName are then derived or preserved server-side. — len 1..255 |
| `model` | string | no | len 1..120 |
| `mcpServers` | McpServerInfo[] | no | max 50 items |
| `declaredSkills` | DeclaredSkill[] | no | max 200 items |
| `a2aCard` | object | no |  |

**Responses:**

- `200` — Registered agent + workspace summary + how to check in. Malformed optional manifest fields are dropped and reported in warnings.
- `400` — Validation error — invalid body, query, or path param (code: validation_error or invalid_json). `details` carries Zod field errors; PATCH /edges also adds `formErrors`.
- `401` — Missing, malformed, expired, or revoked API key (code: unauthorized). A revoked key whose agent has been retired answers 403 agent_retired instead.
- `403` — Forbidden. One of: api_key_user_not_found (key belongs to a user absent from this environment); skill_update_required (skill below TEAMYOU_GATE_MIN_SKILL_VERSION; carries required_version, install_url, docs_url, possibly Deprecation/Sunset headers); instance_key_mismatch (openclawInstanceId does not own the authenticated key); or agent_retired (this key was revoked and its agent has been retired; carries agent {id, slug}, retiredAt, harness and remove {schedule, keyFile} — switch to a new key for this account if you were given one, otherwise stop checking in to this account; NOT retryable with this key).
- `409` — Conflict. One of: agent_identity_in_use (caller-declared mode: the slug belongs to an agent another live API key still holds; to rotate keys, revoke the old one in TeamYou, then register again — otherwise use your own slug); agent_renamed (caller-declared mode: the account owner renamed this agent away from the slug you sent. Nothing was created, and the old slug stays reserved, so registering with it answers this every time. Carries agent {id, slug} and rename {from, to, renamedAt, steps}, steps as AgentRenameSteps: copy your key file from steps.keyFile.from to steps.keyFile.to, set TEAMYOU_AGENT_SLUG to rename.to, then register again with steps.register, which signs the rename off); registration_conflict (caller-declared mode: another change to this agent was in progress, so nothing was written; register again); or agent_identity_conflict (provisioned mode: the authenticated provisioned key is linked to an agent identity that cannot be safely reconciled).
- `429` — Rate limit exceeded (code: rate_limit_exceeded). Includes Retry-After and X-RateLimit-* headers.
- `500` — Internal server error (code: internal_error).

### Get this key’s registered agent

```http
GET /agents/me
```

Returns { agent: null } if the key has no linked agent. Not gated. `checkin` is present either way — an unregistered key still needs to know how to check in, and its first agenda item will be to register.

**Skill CLI:** `teamyou.sh ty agent whoami`

**Parameters:**

- `configuredSlug` (query) — string — The slug your config names (TEAMYOU_AGENT_SLUG). Answered by `agent.configuredSlug`: whether it is one of THIS agent's previous slugs. Ignored when it is not a valid slug. `ty auth status` sends it.

**Responses:**

- `200` — Registered agent (or null), the live activity overlay, and how to check in.
- `401` — Missing, malformed, expired, or revoked API key (code: unauthorized). A revoked key whose agent has been retired answers 403 agent_retired instead.
- `403` — Forbidden — agent_retired (this key was revoked and its agent has been retired; carries agent {id, slug}, retiredAt, harness and remove {schedule, keyFile} — switch to a new key for this account if you were given one, otherwise stop checking in to this account; NOT retryable with this key).
- `429` — Rate limit exceeded (code: rate_limit_exceeded). Includes Retry-After and X-RateLimit-* headers.

### Sign off a slug rename

```http
POST /agents/me/rename/ack
```

Tells TeamYou you have switched to the slug the account's owner renamed you to: your key file is named for the new slug and TEAMYOU_AGENT_SLUG is set to it. Signs off the pending renames of the calling key's agent, so the agenda item and `agent.pendingRename` on GET /agents/me stop telling you how. Registering under the new slug from your own key, or acking the agent_renamed agenda item done, signs it off too. With a body `{ to }` (what `ty agent ack-rename` sends when TEAMYOU_AGENT_SLUG is set) it signs off only while `to` is still your slug: if the owner renamed you again after you read your steps, nothing is signed off and you get 409 rename_target_changed with the current pendingRename. Without `to`, every pending rename is signed off. Idempotent: with nothing pending it returns acknowledged 0, and a key with no agent returns agent null. Not gated.

**Skill CLI:** `teamyou.sh ty agent ack-rename`

**Request body:**

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| `to` | string | no | The slug you switched to (your TEAMYOU_AGENT_SLUG). Signs off only while it is still this agent's slug; otherwise 409 rename_target_changed and nothing is signed off. Omit it to sign off every pending rename. |

**Responses:**

- `200` — How many pending renames were signed off, and the agent as it is named now.
- `400` — Validation error — invalid body, query, or path param (code: validation_error or invalid_json). `details` carries Zod field errors; PATCH /edges also adds `formErrors`.
- `401` — Missing, malformed, expired, or revoked API key (code: unauthorized). A revoked key whose agent has been retired answers 403 agent_retired instead.
- `403` — Forbidden — agent_retired (this key was revoked and its agent has been retired; carries agent {id, slug}, retiredAt, harness and remove {schedule, keyFile} — switch to a new key for this account if you were given one, otherwise stop checking in to this account; NOT retryable with this key).
- `409` — Conflict — rename_target_changed: you signed off a switch to `to`, but the account's owner renamed this agent again since, so nothing was signed off. Carries agent {id, slug} and pendingRename (PendingRename or null): follow its steps, then sign off again.
- `429` — Rate limit exceeded (code: rate_limit_exceeded). Includes Retry-After and X-RateLimit-* headers.
- `500` — Internal server error (code: internal_error).

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
- `401` — Missing, malformed, expired, or revoked API key (code: unauthorized). A revoked key whose agent has been retired answers 403 agent_retired instead.
- `403` — Forbidden. One of: api_key_user_not_found (the key belongs to a user absent from this environment); or agent_retired (this key was revoked and its agent has been retired; carries agent {id, slug}, retiredAt, harness and remove {schedule, keyFile} — switch to a new key for this account if you were given one, otherwise stop checking in to this account; NOT retryable with this key).
- `429` — Rate limit exceeded (code: rate_limit_exceeded). Includes Retry-After and X-RateLimit-* headers.
