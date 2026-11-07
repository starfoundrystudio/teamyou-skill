<!-- GENERATED FROM openapi.json — DO NOT EDIT. Run `pnpm skill:contract:generate`. -->

# TeamYou API Reference: Proposals

Your first-pass proposal for your person to review in TeamYou, made during onboarding. Only your person approves it, on the TeamYou review page; no API call can.

Base URL `https://www.teamyou.com/api/external/v1`. Every request except `GET /openapi.json` carries
`Authorization: Bearer ty_<key>`. Rate limits: reads 100/min, writes 120/min, search 30/min
(all 2000/hour); every response carries `X-RateLimit-Limit`, `X-RateLimit-Remaining` and
`X-RateLimit-Reset`. The full machine-readable contract is `GET /openapi.json`.

### Submit a proposal for your person to review

```http
POST /proposals
```

Submits your first-pass proposal for your person to review in TeamYou. Nothing is saved to their workspace yet: give them `reviewUrl`, where they untick what they don't want, choose for any likely duplicate, and click Add to TeamYou, which saves it all at once. Only your person approves a proposal, on its TeamYou review page (`reviewUrl`): no API call can. When they say they are done, read it back with `proposals get`.

**Skill CLI:** `teamyou.sh ty proposals create <file>`

**Request body:**

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| `kind` | `onboarding` | no |  |
| `playback` | string \| null | no | What you heard, in your own words, shown on the review page. — len 0..4000 |
| `items` | ProposalItem[] | yes | Areas, topics (`person: true` for a person, shown under People and saved as an ordinary topic), details on a topic, projects with tasks, and links. Each item has a `ref`, a slug unique in the proposal that other items point at (`areaRef`, `topicRef`, `fromRef`, `toRef`), and a `source`: `conversation` (your person said it) or `agent_memory` (you already knew it). A link joins two topics, or puts one end on a project; file into an area with `areaRef`, and nest an area with `parentRef` (the ref of another area, or the id `area_…` of an area your person has). Every task names its owner in `assigneeAgentId`: an agent id or slug (yours for your own steps), or null for your person; never put the owner in the title. An unknown or retired agent is a 400. Topic names must differ. A bad or wrong-kind ref, or a link to itself, is a 400 naming the field. Never send what you leave out (`leftOut`): say it in the chat; it is refused and never stored. — max 100 items |

**Responses:**

- `201` — The proposal, in review.
- `400` — Validation error — invalid body, query, or path param (code: validation_error or invalid_json). `details` carries Zod field errors; PATCH /edges also adds `formErrors`.
- `401` — Missing, malformed, expired, or revoked API key (code: unauthorized). A revoked key whose agent has been retired answers 403 agent_retired instead.
- `403` — Forbidden. One of: api_key_user_not_found (key belongs to a user absent from this environment); client_identification_required (no recognized X-TeamYou-Client; carries skill_install_url, registerUrl, docs_url; only when TEAMYOU_GATE_REQUIRE_IDENTIFIED_CLIENT); agent_not_registered (registerUrl, skill_install_url, docs_url); skill_update_required (required_version, install_url, docs_url; possibly Deprecation/Sunset headers); client_update_nudge (a soft, relent-able staleness nudge for an agentic client below the latest release when TEAMYOU_GATE_NAG_ENABLED is on; carries verified_version, required_version, upgrade_url, ack_url, ack_token, nag_interval, nag_acks_so_far, docs_url — upgrade to end it, or fetch ack_url to relent one call at a rising cost); insufficient_scope (the API key lacks this operation’s x-teamyou-scope; carries required_scope, granted_scopes, docs_url — NOT retryable: scopes are fixed at key creation, so create a new key with the required scope instead of retrying); agent_retired (this key was revoked and its agent has been retired; carries agent {id, slug}, retiredAt, harness and remove {schedule, keyFile} — switch to a new key for this account if you were given one, otherwise stop checking in to this account; NOT retryable with this key); or an AI-preference denial AI_UPDATE_DISABLED / AI_DELETE_DISABLED / AI_SHARE_DISABLED (an account-wide block in Settings > Agent permissions is on; carries requiredPreference, blockedPreferences (every preference in the way; a sharing call can be blocked by two), fix (one line to relay to your person as-is: which switch or switches to turn off, and where) and settingsUrl (the link to those switches) - NOT retryable until the person turns the block off). Scopes and AI preferences compose as AND — passing one does not bypass the other. Gate codes only apply when the corresponding env flag is enabled.
- `404` — Resource not found (code: not_found).
- `422` — Unprocessable, and nothing was written. secret_refused: the body contains what looks like a password, a key or token, a national ID number (such as a Social Security number) or a payment card number, which TeamYou never keeps for any agent. Carries field (where it was, such as `description` or `tasks[1].title`; null for the whole body) and kind (`api_key`, `private_key`, `password`, `card_number` or `id_number`), never the value. Take the secret out and send the write again; you can say where it is kept instead. NOT retryable unchanged.
- `429` — Rate limit exceeded (code: rate_limit_exceeded). Includes Retry-After and X-RateLimit-* headers.
- `500` — Internal server error (code: internal_error).
- `503` — The limit check itself failed, so the request was not run (code: rate_limit_unavailable). The caller did not go over a limit. Includes Retry-After.

### Get a proposal

```http
GET /proposals/{id}
```

Returns the proposal, its duplicate flags and your person's choices; once they have clicked Add to TeamYou (status `applied`), `result` holds the id each ref became, what was created, reused and skipped, and a titled link for each created area, topic and project. Adding it ticks the steps the person's review closes; read the project for the next open step. Only your person approves a proposal, on its TeamYou review page (`reviewUrl`): no API call can. Another account's proposal is a 404, as a missing one is.

**Skill CLI:** `teamyou.sh ty proposals get <proposal_id>`

**Parameters:**

- `id` (path, required) — string — Proposal id

**Responses:**

- `200` — The proposal.
- `401` — Missing, malformed, expired, or revoked API key (code: unauthorized). A revoked key whose agent has been retired answers 403 agent_retired instead.
- `403` — Forbidden. One of: api_key_user_not_found (key belongs to a user absent from this environment); client_identification_required (no recognized X-TeamYou-Client; carries skill_install_url, registerUrl, docs_url; only when TEAMYOU_GATE_REQUIRE_IDENTIFIED_CLIENT); agent_not_registered (registerUrl, skill_install_url, docs_url); skill_update_required (required_version, install_url, docs_url; possibly Deprecation/Sunset headers); client_update_nudge (a soft, relent-able staleness nudge for an agentic client below the latest release when TEAMYOU_GATE_NAG_ENABLED is on; carries verified_version, required_version, upgrade_url, ack_url, ack_token, nag_interval, nag_acks_so_far, docs_url — upgrade to end it, or fetch ack_url to relent one call at a rising cost); insufficient_scope (the API key lacks this operation’s x-teamyou-scope; carries required_scope, granted_scopes, docs_url — NOT retryable: scopes are fixed at key creation, so create a new key with the required scope instead of retrying); agent_retired (this key was revoked and its agent has been retired; carries agent {id, slug}, retiredAt, harness and remove {schedule, keyFile} — switch to a new key for this account if you were given one, otherwise stop checking in to this account; NOT retryable with this key); or an AI-preference denial AI_UPDATE_DISABLED / AI_DELETE_DISABLED / AI_SHARE_DISABLED (an account-wide block in Settings > Agent permissions is on; carries requiredPreference, blockedPreferences (every preference in the way; a sharing call can be blocked by two), fix (one line to relay to your person as-is: which switch or switches to turn off, and where) and settingsUrl (the link to those switches) - NOT retryable until the person turns the block off). Scopes and AI preferences compose as AND — passing one does not bypass the other. Gate codes only apply when the corresponding env flag is enabled.
- `404` — Resource not found (code: not_found).
- `429` — Rate limit exceeded (code: rate_limit_exceeded). Includes Retry-After and X-RateLimit-* headers.
- `500` — Internal server error (code: internal_error).
- `503` — The limit check itself failed, so the request was not run (code: rate_limit_unavailable). The caller did not go over a limit. Includes Retry-After.

### Revise a proposal in review

```http
PUT /proposals/{id}
```

Replaces the proposal's `playback`, `items`, or both while it is in review; new items recompute the duplicate flags; on the review page your person's choices on unchanged items (same ref, same content) are kept and new or changed ones are marked, and the review link stays the same. Applied, rejected or expired is a 409. Only your person approves a proposal, on its TeamYou review page (`reviewUrl`): no API call can.

**Skill CLI:** `teamyou.sh ty proposals update <proposal_id> <file>`

**Parameters:**

- `id` (path, required) — string — Proposal id

**Request body:**

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| `playback` | string \| null | no | len 0..4000 |
| `items` | ProposalItem[] | no | Replaces every item, as on create. Keep each unchanged item's ref: on the review page your person's choices on unchanged items are kept, and new or changed items are marked. — max 100 items |

**Responses:**

- `200` — The revised proposal.
- `400` — Validation error — invalid body, query, or path param (code: validation_error or invalid_json). `details` carries Zod field errors; PATCH /edges also adds `formErrors`.
- `401` — Missing, malformed, expired, or revoked API key (code: unauthorized). A revoked key whose agent has been retired answers 403 agent_retired instead.
- `403` — Forbidden. One of: api_key_user_not_found (key belongs to a user absent from this environment); client_identification_required (no recognized X-TeamYou-Client; carries skill_install_url, registerUrl, docs_url; only when TEAMYOU_GATE_REQUIRE_IDENTIFIED_CLIENT); agent_not_registered (registerUrl, skill_install_url, docs_url); skill_update_required (required_version, install_url, docs_url; possibly Deprecation/Sunset headers); client_update_nudge (a soft, relent-able staleness nudge for an agentic client below the latest release when TEAMYOU_GATE_NAG_ENABLED is on; carries verified_version, required_version, upgrade_url, ack_url, ack_token, nag_interval, nag_acks_so_far, docs_url — upgrade to end it, or fetch ack_url to relent one call at a rising cost); insufficient_scope (the API key lacks this operation’s x-teamyou-scope; carries required_scope, granted_scopes, docs_url — NOT retryable: scopes are fixed at key creation, so create a new key with the required scope instead of retrying); agent_retired (this key was revoked and its agent has been retired; carries agent {id, slug}, retiredAt, harness and remove {schedule, keyFile} — switch to a new key for this account if you were given one, otherwise stop checking in to this account; NOT retryable with this key); or an AI-preference denial AI_UPDATE_DISABLED / AI_DELETE_DISABLED / AI_SHARE_DISABLED (an account-wide block in Settings > Agent permissions is on; carries requiredPreference, blockedPreferences (every preference in the way; a sharing call can be blocked by two), fix (one line to relay to your person as-is: which switch or switches to turn off, and where) and settingsUrl (the link to those switches) - NOT retryable until the person turns the block off). Scopes and AI preferences compose as AND — passing one does not bypass the other. Gate codes only apply when the corresponding env flag is enabled.
- `404` — Resource not found (code: not_found).
- `409` — Conflict — e.g. duplicate edge (same direction + label) or the scheduled-action slot limit reached (code: conflict).
- `422` — Unprocessable, and nothing was written. secret_refused: the body contains what looks like a password, a key or token, a national ID number (such as a Social Security number) or a payment card number, which TeamYou never keeps for any agent. Carries field (where it was, such as `description` or `tasks[1].title`; null for the whole body) and kind (`api_key`, `private_key`, `password`, `card_number` or `id_number`), never the value. Take the secret out and send the write again; you can say where it is kept instead. NOT retryable unchanged.
- `429` — Rate limit exceeded (code: rate_limit_exceeded). Includes Retry-After and X-RateLimit-* headers.
- `500` — Internal server error (code: internal_error).
- `503` — The limit check itself failed, so the request was not run (code: rate_limit_unavailable). The caller did not go over a limit. Includes Retry-After.
