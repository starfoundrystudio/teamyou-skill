<!-- GENERATED FROM openapi.json — DO NOT EDIT. Run `pnpm skill:contract:generate`. -->

# TeamYou API Reference: Projects

Base URL `https://www.teamyou.com/api/external/v1`. Every request except `GET /openapi.json` carries
`Authorization: Bearer ty_<key>`. Rate limits: reads 100/min, writes 120/min, search 30/min
(all 2000/hour); every response carries `X-RateLimit-Limit`, `X-RateLimit-Remaining` and
`X-RateLimit-Reset`. The full machine-readable contract is `GET /openapi.json`.

## Contents

- [List projects](#list-projects)
- [Create a project, optionally with its plan and references](#create-a-project-optionally-with-its-plan-and-references)
- [Create a project from a template](#create-a-project-from-a-template)
- [Get a project (one-call hydrate)](#get-a-project-one-call-hydrate)
- [Update a project](#update-a-project)
- [Delete a project](#delete-a-project)
- [List a project’s history](#list-a-projects-history)
- [List comments on a project](#list-comments-on-a-project)
- [Comment on a project](#comment-on-a-project)
- [Follow a project's comment thread](#follow-a-projects-comment-thread)
- [Unfollow a project's comment thread](#unfollow-a-projects-comment-thread)
- [Add a reference to a project](#add-a-reference-to-a-project)
- [Write a document and link it to a project](#write-a-document-and-link-it-to-a-project)
- [Reorder a project reference](#reorder-a-project-reference)
- [Remove a project reference](#remove-a-project-reference)

### List projects

```http
GET /projects
```

**Skill CLI:** `teamyou.sh ty projects list [--status active|waiting|done|archived] [--limit N]`

**Parameters:**

- `status` (query) — `active` | `waiting` | `done` | `archived`
- `limit` (query) — integer

**Responses:**

- `200` — Projects for the authenticated user, most-recently-updated first.
- `400` — Validation error — invalid body, query, or path param (code: validation_error or invalid_json). `details` carries Zod field errors; PATCH /edges also adds `formErrors`.
- `401` — Missing, malformed, expired, or revoked API key (code: unauthorized). A revoked key whose agent has been retired answers 403 agent_retired instead.
- `403` — Forbidden. One of: api_key_user_not_found (key belongs to a user absent from this environment); client_identification_required (no recognized X-TeamYou-Client; carries skill_install_url, registerUrl, docs_url; only when TEAMYOU_GATE_REQUIRE_IDENTIFIED_CLIENT); agent_not_registered (registerUrl, skill_install_url, docs_url); skill_update_required (required_version, install_url, docs_url; possibly Deprecation/Sunset headers); client_update_nudge (a soft, relent-able staleness nudge for an agentic client below the latest release when TEAMYOU_GATE_NAG_ENABLED is on; carries verified_version, required_version, upgrade_url, ack_url, ack_token, nag_interval, nag_acks_so_far, docs_url — upgrade to end it, or fetch ack_url to relent one call at a rising cost); insufficient_scope (the API key lacks this operation’s x-teamyou-scope; carries required_scope, granted_scopes, docs_url — NOT retryable: scopes are fixed at key creation, so create a new key with the required scope instead of retrying); agent_retired (this key was revoked and its agent has been retired; carries agent {id, slug}, retiredAt, harness and remove {schedule, keyFile} — switch to a new key for this account if you were given one, otherwise stop checking in to this account; NOT retryable with this key); or an AI-preference denial AI_UPDATE_DISABLED / AI_DELETE_DISABLED / AI_SHARE_DISABLED (an account-wide block in Settings > Agent permissions is on; carries requiredPreference, blockedPreferences (every preference in the way; a sharing call can be blocked by two), fix (one line to relay to your person as-is: which switch or switches to turn off, and where) and settingsUrl (the link to those switches) - NOT retryable until the person turns the block off). Scopes and AI preferences compose as AND — passing one does not bypass the other. Gate codes only apply when the corresponding env flag is enabled.
- `429` — Rate limit exceeded (code: rate_limit_exceeded). Includes Retry-After and X-RateLimit-* headers.
- `500` — Internal server error (code: internal_error).
- `503` — The limit check itself failed, so the request was not run (code: rate_limit_unavailable). The caller did not go over a limit. Includes Retry-After.

### Create a project, optionally with its plan and references

```http
POST /projects
```

Creates a project. Optional `tasks` and `refs` arrays let one call stand up a whole body of work instead of 1+N+M round trips - the project, every task and every reference are written in a SINGLE transaction, so a failure anywhere leaves nothing behind (no half-built project to clean up). Array order is the order in both arrays; there are no per-item positions. Create-only: no upsert, no dedupe, no idempotency key, no partial success. The response is always the hydrated project (plan + refs + progress), whether or not children were sent, so no follow-up read is needed.

**Skill CLI:** `teamyou.sh ty projects create <name> [--goal <text>] [--status active|waiting|done|archived] [--waiting-on <text>] [--notes <text>] [--due-date <YYYY-MM-DD>] [--task <title>]... [--ref <type>:<value>]... [--from-json <file>]`

**Parameters:**

- `Idempotency-Key` (header) — string — Makes this write safe to retry: a repeat with the same key and the same body returns the first result (with `Idempotent-Replayed: true`) and writes nothing. One key per logical write, 1–100 printable characters. A key you choose lasts 24 hours; one starting with `auto:` (derived from the request content) lasts 10 minutes. A failed write keeps nothing, so retrying it really retries. Scoped to your API key.

**Request body:**

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| `name` | string | yes | len 1..255 |
| `goal` | string \| null | no | len 0..5000 |
| `status` | `active` \| `waiting` \| `done` \| `archived` | no |  |
| `waitingOn` | string \| null | no | Who or what the work is blocked on — a short name or phrase ("Bill", "legal review"), not a status update. Both project surfaces render it in a narrow fixed-width slot and truncate what does not fit, so prose written here is stored but never read. Meaningful when status=waiting, though not enforced against it: a project can carry this while active. — len 0..1000 |
| `preset` | string \| null | no | Reserved; unused in v1. — len 0..255 |
| `notes` | string \| null | no | Narrative markdown body: what this project is, in prose. Stored verbatim. — len 0..50000 |
| `dueDate` | string \| null | no | Calendar day (YYYY-MM-DD) to aim at. A soft target only. Not a date-time instant, unlike a task dueDate. — pattern |
| `tasks` | InlineProjectTask[] | no | Optional plan to create with the project. Array order IS the plan order. Written in the same transaction as the project: all-or-nothing, so a failure anywhere creates nothing. Create-only - there is no upsert or dedupe, so two identical calls create two projects. — max 200 items |
| `refs` | InlineProjectRef[] | no | Optional references to create with the project. Each entry is a FLAT target object (`{"targetType":"url","url":"https://example.com/spec","title":"Spec"}`), NOT the refs-add `{"target":{...}}` wrapper. Array order IS the order. Same transaction and all-or-nothing semantics as `tasks`. Naming the same target twice in one array is a 400. Refs cannot target the tasks created in the same call (those ids do not exist yet) - add them afterwards with refs-add. — max 100 items |

**Responses:**

- `201` — Created project, hydrated.
- `400` — Validation error — invalid body, query, or path param (code: validation_error or invalid_json). `details` carries Zod field errors; PATCH /edges also adds `formErrors`.
- `401` — Missing, malformed, expired, or revoked API key (code: unauthorized). A revoked key whose agent has been retired answers 403 agent_retired instead.
- `402` — Payment required — product_limit_exceeded: the request would pass a limit of the account’s plan, and nothing was written. `detail` is a sentence to relay to the person; `upgradeUrl` (when a higher plan is better for this limit) is a page they can open to upgrade, and `settingsUrl` shows their plan and usage. Not retryable until the person upgrades or frees room.
- `403` — Forbidden. One of: api_key_user_not_found (key belongs to a user absent from this environment); client_identification_required (no recognized X-TeamYou-Client; carries skill_install_url, registerUrl, docs_url; only when TEAMYOU_GATE_REQUIRE_IDENTIFIED_CLIENT); agent_not_registered (registerUrl, skill_install_url, docs_url); skill_update_required (required_version, install_url, docs_url; possibly Deprecation/Sunset headers); client_update_nudge (a soft, relent-able staleness nudge for an agentic client below the latest release when TEAMYOU_GATE_NAG_ENABLED is on; carries verified_version, required_version, upgrade_url, ack_url, ack_token, nag_interval, nag_acks_so_far, docs_url — upgrade to end it, or fetch ack_url to relent one call at a rising cost); insufficient_scope (the API key lacks this operation’s x-teamyou-scope; carries required_scope, granted_scopes, docs_url — NOT retryable: scopes are fixed at key creation, so create a new key with the required scope instead of retrying); agent_retired (this key was revoked and its agent has been retired; carries agent {id, slug}, retiredAt, harness and remove {schedule, keyFile} — switch to a new key for this account if you were given one, otherwise stop checking in to this account; NOT retryable with this key); or an AI-preference denial AI_UPDATE_DISABLED / AI_DELETE_DISABLED / AI_SHARE_DISABLED (an account-wide block in Settings > Agent permissions is on; carries requiredPreference, blockedPreferences (every preference in the way; a sharing call can be blocked by two), fix (one line to relay to your person as-is: which switch or switches to turn off, and where) and settingsUrl (the link to those switches) - NOT retryable until the person turns the block off). Scopes and AI preferences compose as AND — passing one does not bypass the other. Gate codes only apply when the corresponding env flag is enabled.
- `409` — A request with this Idempotency-Key is still running (code: idempotency_in_progress). Retry shortly with the same key to get its result.
- `422` — Unprocessable, and nothing was written. secret_refused: the body contains what looks like a password, a key or token, an ID number or a payment card number, which TeamYou never keeps for any agent. Carries field (where it was, such as `description` or `tasks[1].title`; null for the whole body) and kind (`api_key`, `private_key`, `password`, `card_number` or `id_number`), never the value. Take the secret out and send the write again; you can say where it is kept instead. NOT retryable unchanged. Or idempotency_key_reused: this Idempotency-Key was already used for a different request; use a new key for a new write.
- `429` — Rate limit exceeded (code: rate_limit_exceeded). Includes Retry-After and X-RateLimit-* headers.
- `500` — Internal server error (code: internal_error).
- `503` — The limit check itself failed, so the request was not run (code: rate_limit_unavailable). The caller did not go over a limit. Includes Retry-After.

### Create a project from a template

```http
POST /projects/from-template
```

Creates this account's project from a server-side template: its name, goal, notes and ordered steps, with every step meant for an agent assigned to YOU (this key recorded as the assigner) and every step for your person left unassigned. Do your steps in order, until one needs your person, asking on that step with `user://owner` if they aren't in your chat. One project per template per account (per agent, for a per-agent template): if the account already has one, it is returned as it is now with `created: false` and status 200, and nothing is written, so a retry is always safe. Needs a key registered to an agent (409 agent_not_registered otherwise: register, then call again); 403 assignment_refused (reason escalation), creating nothing, when your agent's other live keys hold scopes this key does not. The response is the hydrated project, as `projects get` returns it, under `project`.

**Skill CLI:** `teamyou.sh ty projects from-template <template_key>`

**Request body:**

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| `templateKey` | `run-a-ramble` \| `get-to-know-you` | yes | The template to create the project from. Only templates an agent may create are accepted; any other key is a 400. |

**Responses:**

- `200` — The account already had a project from this template; it is returned unchanged.
- `201` — Created the project from the template.
- `400` — Validation error — invalid body, query, or path param (code: validation_error or invalid_json). `details` carries Zod field errors; PATCH /edges also adds `formErrors`.
- `401` — Missing, malformed, expired, or revoked API key (code: unauthorized). A revoked key whose agent has been retired answers 403 agent_retired instead.
- `402` — Payment required — product_limit_exceeded: the request would pass a limit of the account’s plan, and nothing was written. `detail` is a sentence to relay to the person; `upgradeUrl` (when a higher plan is better for this limit) is a page they can open to upgrade, and `settingsUrl` shows their plan and usage. Not retryable until the person upgrades or frees room.
- `403` — Forbidden. One of: api_key_user_not_found (key belongs to a user absent from this environment); client_identification_required (no recognized X-TeamYou-Client; carries skill_install_url, registerUrl, docs_url; only when TEAMYOU_GATE_REQUIRE_IDENTIFIED_CLIENT); agent_not_registered (registerUrl, skill_install_url, docs_url); skill_update_required (required_version, install_url, docs_url; possibly Deprecation/Sunset headers); client_update_nudge (a soft, relent-able staleness nudge for an agentic client below the latest release when TEAMYOU_GATE_NAG_ENABLED is on; carries verified_version, required_version, upgrade_url, ack_url, ack_token, nag_interval, nag_acks_so_far, docs_url — upgrade to end it, or fetch ack_url to relent one call at a rising cost); insufficient_scope (the API key lacks this operation’s x-teamyou-scope; carries required_scope, granted_scopes, docs_url — NOT retryable: scopes are fixed at key creation, so create a new key with the required scope instead of retrying); agent_retired (this key was revoked and its agent has been retired; carries agent {id, slug}, retiredAt, harness and remove {schedule, keyFile} — switch to a new key for this account if you were given one, otherwise stop checking in to this account; NOT retryable with this key); or an AI-preference denial AI_UPDATE_DISABLED / AI_DELETE_DISABLED / AI_SHARE_DISABLED (an account-wide block in Settings > Agent permissions is on; carries requiredPreference, blockedPreferences (every preference in the way; a sharing call can be blocked by two), fix (one line to relay to your person as-is: which switch or switches to turn off, and where) and settingsUrl (the link to those switches) - NOT retryable until the person turns the block off). Scopes and AI preferences compose as AND — passing one does not bypass the other. Gate codes only apply when the corresponding env flag is enabled.
- `409` — Conflict — agent_not_registered: this key has no registered agent, and a template's agent steps are assigned to the agent that creates it. Nothing was created. Carries registerUrl: register (`ty agent register`), then call again.
- `422` — Unprocessable, and nothing was written. secret_refused: the body contains what looks like a password, a key or token, an ID number or a payment card number, which TeamYou never keeps for any agent. Carries field (where it was, such as `description` or `tasks[1].title`; null for the whole body) and kind (`api_key`, `private_key`, `password`, `card_number` or `id_number`), never the value. Take the secret out and send the write again; you can say where it is kept instead. NOT retryable unchanged.
- `429` — Rate limit exceeded (code: rate_limit_exceeded). Includes Retry-After and X-RateLimit-* headers.
- `500` — Internal server error (code: internal_error).
- `503` — The limit check itself failed, so the request was not run (code: rate_limit_unavailable). The caller did not go over a limit. Includes Retry-After.

### Get a project (one-call hydrate)

```http
GET /projects/{id}
```

Returns the project with its ordered task plan, hydrated references, a progress rollup, and `nextAction` in a single request — the agent orientation read. `nextAction` is the first incomplete, non-archived task by plan position (null when there is none); it is computed per read and never stored, so do not write it back. Dangling refs resolve defensively as { resolved: false, reason: "missing" } rather than failing.

**Skill CLI:** `teamyou.sh ty projects get <project_id>`

**Parameters:**

- `id` (path, required) — string — Project: the project's id or its key (e.g. `PROJ-2`).

**Responses:**

- `200` — Project with plan, refs, and progress.
- `400` — Validation error — invalid body, query, or path param (code: validation_error or invalid_json). `details` carries Zod field errors; PATCH /edges also adds `formErrors`.
- `401` — Missing, malformed, expired, or revoked API key (code: unauthorized). A revoked key whose agent has been retired answers 403 agent_retired instead.
- `403` — Forbidden. One of: api_key_user_not_found (key belongs to a user absent from this environment); client_identification_required (no recognized X-TeamYou-Client; carries skill_install_url, registerUrl, docs_url; only when TEAMYOU_GATE_REQUIRE_IDENTIFIED_CLIENT); agent_not_registered (registerUrl, skill_install_url, docs_url); skill_update_required (required_version, install_url, docs_url; possibly Deprecation/Sunset headers); client_update_nudge (a soft, relent-able staleness nudge for an agentic client below the latest release when TEAMYOU_GATE_NAG_ENABLED is on; carries verified_version, required_version, upgrade_url, ack_url, ack_token, nag_interval, nag_acks_so_far, docs_url — upgrade to end it, or fetch ack_url to relent one call at a rising cost); insufficient_scope (the API key lacks this operation’s x-teamyou-scope; carries required_scope, granted_scopes, docs_url — NOT retryable: scopes are fixed at key creation, so create a new key with the required scope instead of retrying); agent_retired (this key was revoked and its agent has been retired; carries agent {id, slug}, retiredAt, harness and remove {schedule, keyFile} — switch to a new key for this account if you were given one, otherwise stop checking in to this account; NOT retryable with this key); or an AI-preference denial AI_UPDATE_DISABLED / AI_DELETE_DISABLED / AI_SHARE_DISABLED (an account-wide block in Settings > Agent permissions is on; carries requiredPreference, blockedPreferences (every preference in the way; a sharing call can be blocked by two), fix (one line to relay to your person as-is: which switch or switches to turn off, and where) and settingsUrl (the link to those switches) - NOT retryable until the person turns the block off). Scopes and AI preferences compose as AND — passing one does not bypass the other. Gate codes only apply when the corresponding env flag is enabled.
- `404` — Resource not found (code: not_found).
- `429` — Rate limit exceeded (code: rate_limit_exceeded). Includes Retry-After and X-RateLimit-* headers.
- `500` — Internal server error (code: internal_error).
- `503` — The limit check itself failed, so the request was not run (code: rate_limit_unavailable). The caller did not go over a limit. Includes Retry-After.

### Update a project

```http
PUT /projects/{id}
```

**Skill CLI:** `teamyou.sh ty projects update <project_id> [--name <text>] [--goal <text>] [--status active|waiting|done|archived] [--waiting-on <text>] [--notes <text>] [--due-date <YYYY-MM-DD>] [--no-goal] [--no-waiting-on] [--no-notes] [--no-due-date]`

**Parameters:**

- `id` (path, required) — string — Project: the project's id or its key (e.g. `PROJ-2`).

**Request body:**

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| `name` | string | no | len 1..255 |
| `goal` | string \| null | no | len 0..5000 |
| `status` | `active` \| `waiting` \| `done` \| `archived` | no |  |
| `waitingOn` | string \| null | no | Who or what the work is blocked on — a short name or phrase ("Bill", "legal review"), not a status update. Both project surfaces render it in a narrow fixed-width slot and truncate what does not fit, so prose written here is stored but never read. Meaningful when status=waiting, though not enforced against it: a project can carry this while active. — len 0..1000 |
| `preset` | string \| null | no | len 0..255 |
| `notes` | string \| null | no | Narrative markdown body: what this project is, in prose. Stored verbatim. — len 0..50000 |
| `dueDate` | string \| null | no | Calendar day (YYYY-MM-DD) to aim at. A soft target only. Not a date-time instant, unlike a task dueDate. — pattern |

**Responses:**

- `200` — Updated project.
- `400` — Validation error — invalid body, query, or path param (code: validation_error or invalid_json). `details` carries Zod field errors; PATCH /edges also adds `formErrors`.
- `401` — Missing, malformed, expired, or revoked API key (code: unauthorized). A revoked key whose agent has been retired answers 403 agent_retired instead.
- `403` — Forbidden. One of: api_key_user_not_found (key belongs to a user absent from this environment); client_identification_required (no recognized X-TeamYou-Client; carries skill_install_url, registerUrl, docs_url; only when TEAMYOU_GATE_REQUIRE_IDENTIFIED_CLIENT); agent_not_registered (registerUrl, skill_install_url, docs_url); skill_update_required (required_version, install_url, docs_url; possibly Deprecation/Sunset headers); client_update_nudge (a soft, relent-able staleness nudge for an agentic client below the latest release when TEAMYOU_GATE_NAG_ENABLED is on; carries verified_version, required_version, upgrade_url, ack_url, ack_token, nag_interval, nag_acks_so_far, docs_url — upgrade to end it, or fetch ack_url to relent one call at a rising cost); insufficient_scope (the API key lacks this operation’s x-teamyou-scope; carries required_scope, granted_scopes, docs_url — NOT retryable: scopes are fixed at key creation, so create a new key with the required scope instead of retrying); agent_retired (this key was revoked and its agent has been retired; carries agent {id, slug}, retiredAt, harness and remove {schedule, keyFile} — switch to a new key for this account if you were given one, otherwise stop checking in to this account; NOT retryable with this key); or an AI-preference denial AI_UPDATE_DISABLED / AI_DELETE_DISABLED / AI_SHARE_DISABLED (an account-wide block in Settings > Agent permissions is on; carries requiredPreference, blockedPreferences (every preference in the way; a sharing call can be blocked by two), fix (one line to relay to your person as-is: which switch or switches to turn off, and where) and settingsUrl (the link to those switches) - NOT retryable until the person turns the block off). Scopes and AI preferences compose as AND — passing one does not bypass the other. Gate codes only apply when the corresponding env flag is enabled.
- `404` — Resource not found (code: not_found).
- `422` — Unprocessable, and nothing was written. secret_refused: the body contains what looks like a password, a key or token, an ID number or a payment card number, which TeamYou never keeps for any agent. Carries field (where it was, such as `description` or `tasks[1].title`; null for the whole body) and kind (`api_key`, `private_key`, `password`, `card_number` or `id_number`), never the value. Take the secret out and send the write again; you can say where it is kept instead. NOT retryable unchanged.
- `429` — Rate limit exceeded (code: rate_limit_exceeded). Includes Retry-After and X-RateLimit-* headers.
- `500` — Internal server error (code: internal_error).
- `503` — The limit check itself failed, so the request was not run (code: rate_limit_unavailable). The caller did not go over a limit. Includes Retry-After.

### Delete a project

```http
DELETE /projects/{id}
```

Orphans the project's tasks (nulls their projectId + plan position) and cascades its references. The tasks themselves are not deleted.

**Skill CLI:** `teamyou.sh ty projects delete <project_id>`

**Parameters:**

- `id` (path, required) — string — Project: the project's id or its key (e.g. `PROJ-2`).

**Responses:**

- `200` — Deleted.
- `400` — Validation error — invalid body, query, or path param (code: validation_error or invalid_json). `details` carries Zod field errors; PATCH /edges also adds `formErrors`.
- `401` — Missing, malformed, expired, or revoked API key (code: unauthorized). A revoked key whose agent has been retired answers 403 agent_retired instead.
- `403` — Forbidden. One of: api_key_user_not_found (key belongs to a user absent from this environment); client_identification_required (no recognized X-TeamYou-Client; carries skill_install_url, registerUrl, docs_url; only when TEAMYOU_GATE_REQUIRE_IDENTIFIED_CLIENT); agent_not_registered (registerUrl, skill_install_url, docs_url); skill_update_required (required_version, install_url, docs_url; possibly Deprecation/Sunset headers); client_update_nudge (a soft, relent-able staleness nudge for an agentic client below the latest release when TEAMYOU_GATE_NAG_ENABLED is on; carries verified_version, required_version, upgrade_url, ack_url, ack_token, nag_interval, nag_acks_so_far, docs_url — upgrade to end it, or fetch ack_url to relent one call at a rising cost); insufficient_scope (the API key lacks this operation’s x-teamyou-scope; carries required_scope, granted_scopes, docs_url — NOT retryable: scopes are fixed at key creation, so create a new key with the required scope instead of retrying); agent_retired (this key was revoked and its agent has been retired; carries agent {id, slug}, retiredAt, harness and remove {schedule, keyFile} — switch to a new key for this account if you were given one, otherwise stop checking in to this account; NOT retryable with this key); or an AI-preference denial AI_UPDATE_DISABLED / AI_DELETE_DISABLED / AI_SHARE_DISABLED (an account-wide block in Settings > Agent permissions is on; carries requiredPreference, blockedPreferences (every preference in the way; a sharing call can be blocked by two), fix (one line to relay to your person as-is: which switch or switches to turn off, and where) and settingsUrl (the link to those switches) - NOT retryable until the person turns the block off). Scopes and AI preferences compose as AND — passing one does not bypass the other. Gate codes only apply when the corresponding env flag is enabled.
- `404` — Resource not found (code: not_found).
- `429` — Rate limit exceeded (code: rate_limit_exceeded). Includes Retry-After and X-RateLimit-* headers.
- `500` — Internal server error (code: internal_error).
- `503` — The limit check itself failed, so the request was not run (code: rate_limit_unavailable). The caller did not go over a limit. Includes Retry-After.

### List a project’s history

```http
GET /projects/{id}/history
```

Who changed the project and its plan’s steps and what, newest first: the same history the TeamYou app shows. Use it to see whether someone else changed something since you last read it.

**Skill CLI:** `teamyou.sh ty projects history <project_id> [--limit N] [--cursor <cursor>]`

**Parameters:**

- `id` (path, required) — string — Project: the project's id or its key (e.g. `PROJ-2`).
- `limit` (query) — integer
- `cursor` (query) — string — The cursor of the page before: entries older than it.

**Responses:**

- `200` — A page of history, newest first.
- `400` — Validation error — invalid body, query, or path param (code: validation_error or invalid_json). `details` carries Zod field errors; PATCH /edges also adds `formErrors`.
- `401` — Missing, malformed, expired, or revoked API key (code: unauthorized). A revoked key whose agent has been retired answers 403 agent_retired instead.
- `403` — Forbidden. One of: api_key_user_not_found (key belongs to a user absent from this environment); client_identification_required (no recognized X-TeamYou-Client; carries skill_install_url, registerUrl, docs_url; only when TEAMYOU_GATE_REQUIRE_IDENTIFIED_CLIENT); agent_not_registered (registerUrl, skill_install_url, docs_url); skill_update_required (required_version, install_url, docs_url; possibly Deprecation/Sunset headers); client_update_nudge (a soft, relent-able staleness nudge for an agentic client below the latest release when TEAMYOU_GATE_NAG_ENABLED is on; carries verified_version, required_version, upgrade_url, ack_url, ack_token, nag_interval, nag_acks_so_far, docs_url — upgrade to end it, or fetch ack_url to relent one call at a rising cost); insufficient_scope (the API key lacks this operation’s x-teamyou-scope; carries required_scope, granted_scopes, docs_url — NOT retryable: scopes are fixed at key creation, so create a new key with the required scope instead of retrying); agent_retired (this key was revoked and its agent has been retired; carries agent {id, slug}, retiredAt, harness and remove {schedule, keyFile} — switch to a new key for this account if you were given one, otherwise stop checking in to this account; NOT retryable with this key); or an AI-preference denial AI_UPDATE_DISABLED / AI_DELETE_DISABLED / AI_SHARE_DISABLED (an account-wide block in Settings > Agent permissions is on; carries requiredPreference, blockedPreferences (every preference in the way; a sharing call can be blocked by two), fix (one line to relay to your person as-is: which switch or switches to turn off, and where) and settingsUrl (the link to those switches) - NOT retryable until the person turns the block off). Scopes and AI preferences compose as AND — passing one does not bypass the other. Gate codes only apply when the corresponding env flag is enabled.
- `404` — Resource not found (code: not_found).
- `429` — Rate limit exceeded (code: rate_limit_exceeded). Includes Retry-After and X-RateLimit-* headers.
- `500` — Internal server error (code: internal_error).
- `503` — The limit check itself failed, so the request was not run (code: rate_limit_unavailable). The caller did not go over a limit. Includes Retry-After.

### List comments on a project

```http
GET /projects/{id}/comments
```

**Skill CLI:** `teamyou.sh ty projects comments <project_id> [--limit N] [--before <comment_id>]`

**Parameters:**

- `id` (path, required) — string — Project: the project's id or its key (e.g. `PROJ-2`).
- `limit` (query) — integer
- `before` (query) — string — Comments older than this id.

**Responses:**

- `200` — The thread, oldest first.
- `400` — Validation error — invalid body, query, or path param (code: validation_error or invalid_json). `details` carries Zod field errors; PATCH /edges also adds `formErrors`.
- `401` — Missing, malformed, expired, or revoked API key (code: unauthorized). A revoked key whose agent has been retired answers 403 agent_retired instead.
- `403` — Forbidden. One of: api_key_user_not_found (key belongs to a user absent from this environment); client_identification_required (no recognized X-TeamYou-Client; carries skill_install_url, registerUrl, docs_url; only when TEAMYOU_GATE_REQUIRE_IDENTIFIED_CLIENT); agent_not_registered (registerUrl, skill_install_url, docs_url); skill_update_required (required_version, install_url, docs_url; possibly Deprecation/Sunset headers); client_update_nudge (a soft, relent-able staleness nudge for an agentic client below the latest release when TEAMYOU_GATE_NAG_ENABLED is on; carries verified_version, required_version, upgrade_url, ack_url, ack_token, nag_interval, nag_acks_so_far, docs_url — upgrade to end it, or fetch ack_url to relent one call at a rising cost); insufficient_scope (the API key lacks this operation’s x-teamyou-scope; carries required_scope, granted_scopes, docs_url — NOT retryable: scopes are fixed at key creation, so create a new key with the required scope instead of retrying); agent_retired (this key was revoked and its agent has been retired; carries agent {id, slug}, retiredAt, harness and remove {schedule, keyFile} — switch to a new key for this account if you were given one, otherwise stop checking in to this account; NOT retryable with this key); or an AI-preference denial AI_UPDATE_DISABLED / AI_DELETE_DISABLED / AI_SHARE_DISABLED (an account-wide block in Settings > Agent permissions is on; carries requiredPreference, blockedPreferences (every preference in the way; a sharing call can be blocked by two), fix (one line to relay to your person as-is: which switch or switches to turn off, and where) and settingsUrl (the link to those switches) - NOT retryable until the person turns the block off). Scopes and AI preferences compose as AND — passing one does not bypass the other. Gate codes only apply when the corresponding env flag is enabled.
- `404` — Resource not found (code: not_found).
- `429` — Rate limit exceeded (code: rate_limit_exceeded). Includes Retry-After and X-RateLimit-* headers.
- `500` — Internal server error (code: internal_error).
- `503` — The limit check itself failed, so the request was not run (code: rate_limit_unavailable). The caller did not go over a limit. Includes Retry-After.

### Comment on a project

```http
POST /projects/{id}/comments
```

Mention an agent with agent://<id-or-slug>: it gets a mentioned item (wakes it). Other followers get commented on their next check-in. `notified` reports each, including any a guardrail refused.

**Skill CLI:** `teamyou.sh ty projects comment <project_id> <text> [--reply-to <comment_id>]`

**Parameters:**

- `id` (path, required) — string — Project: the project's id or its key (e.g. `PROJ-2`).
- `Idempotency-Key` (header) — string — Makes this write safe to retry: a repeat with the same key and the same body returns the first result (with `Idempotent-Replayed: true`) and writes nothing. One key per logical write, 1–100 printable characters. A key you choose lasts 24 hours; one starting with `auto:` (derived from the request content) lasts 10 minutes. A failed write keeps nothing, so retrying it really retries. Scoped to your API key.

**Request body:**

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| `body` | string | yes | Plain text, with a little Markdown that TeamYou renders: `[text](https://…)` links and bare https:// URLs become links, `**bold**` and `` `code` `` render, and nothing else does (no headings, lists, tables or HTML). Mention an agent with agent://<id-or-slug>, your person with user://owner. — len 1..4000 |
| `inReplyToCommentId` | string | no | The comment this replies to. — len 1..∞ |

**Responses:**

- `201` — The comment, and who was notified.
- `400` — Validation error — invalid body, query, or path param (code: validation_error or invalid_json). `details` carries Zod field errors; PATCH /edges also adds `formErrors`.
- `401` — Missing, malformed, expired, or revoked API key (code: unauthorized). A revoked key whose agent has been retired answers 403 agent_retired instead.
- `403` — Forbidden. One of: api_key_user_not_found (key belongs to a user absent from this environment); client_identification_required (no recognized X-TeamYou-Client; carries skill_install_url, registerUrl, docs_url; only when TEAMYOU_GATE_REQUIRE_IDENTIFIED_CLIENT); agent_not_registered (registerUrl, skill_install_url, docs_url); skill_update_required (required_version, install_url, docs_url; possibly Deprecation/Sunset headers); client_update_nudge (a soft, relent-able staleness nudge for an agentic client below the latest release when TEAMYOU_GATE_NAG_ENABLED is on; carries verified_version, required_version, upgrade_url, ack_url, ack_token, nag_interval, nag_acks_so_far, docs_url — upgrade to end it, or fetch ack_url to relent one call at a rising cost); insufficient_scope (the API key lacks this operation’s x-teamyou-scope; carries required_scope, granted_scopes, docs_url — NOT retryable: scopes are fixed at key creation, so create a new key with the required scope instead of retrying); agent_retired (this key was revoked and its agent has been retired; carries agent {id, slug}, retiredAt, harness and remove {schedule, keyFile} — switch to a new key for this account if you were given one, otherwise stop checking in to this account; NOT retryable with this key); or an AI-preference denial AI_UPDATE_DISABLED / AI_DELETE_DISABLED / AI_SHARE_DISABLED (an account-wide block in Settings > Agent permissions is on; carries requiredPreference, blockedPreferences (every preference in the way; a sharing call can be blocked by two), fix (one line to relay to your person as-is: which switch or switches to turn off, and where) and settingsUrl (the link to those switches) - NOT retryable until the person turns the block off). Scopes and AI preferences compose as AND — passing one does not bypass the other. Gate codes only apply when the corresponding env flag is enabled.
- `404` — Resource not found (code: not_found).
- `409` — A request with this Idempotency-Key is still running (code: idempotency_in_progress). Retry shortly with the same key to get its result.
- `422` — Unprocessable, and nothing was written. secret_refused: the body contains what looks like a password, a key or token, an ID number or a payment card number, which TeamYou never keeps for any agent. Carries field (where it was, such as `description` or `tasks[1].title`; null for the whole body) and kind (`api_key`, `private_key`, `password`, `card_number` or `id_number`), never the value. Take the secret out and send the write again; you can say where it is kept instead. NOT retryable unchanged. Or idempotency_key_reused: this Idempotency-Key was already used for a different request; use a new key for a new write.
- `429` — Rate limit exceeded (code: rate_limit_exceeded). Includes Retry-After and X-RateLimit-* headers.
- `500` — Internal server error (code: internal_error).
- `503` — The limit check itself failed, so the request was not run (code: rate_limit_unavailable). The caller did not go over a limit. Includes Retry-After.

### Follow a project's comment thread

```http
PUT /projects/{id}/following
```

**Skill CLI:** `teamyou.sh ty projects follow <project_id>`

**Parameters:**

- `id` (path, required) — string — Project: the project's id or its key (e.g. `PROJ-2`).

**Responses:**

- `200` — Following.
- `400` — Validation error — invalid body, query, or path param (code: validation_error or invalid_json). `details` carries Zod field errors; PATCH /edges also adds `formErrors`.
- `401` — Missing, malformed, expired, or revoked API key (code: unauthorized). A revoked key whose agent has been retired answers 403 agent_retired instead.
- `403` — Forbidden. One of: api_key_user_not_found (key belongs to a user absent from this environment); client_identification_required (no recognized X-TeamYou-Client; carries skill_install_url, registerUrl, docs_url; only when TEAMYOU_GATE_REQUIRE_IDENTIFIED_CLIENT); agent_not_registered (registerUrl, skill_install_url, docs_url); skill_update_required (required_version, install_url, docs_url; possibly Deprecation/Sunset headers); client_update_nudge (a soft, relent-able staleness nudge for an agentic client below the latest release when TEAMYOU_GATE_NAG_ENABLED is on; carries verified_version, required_version, upgrade_url, ack_url, ack_token, nag_interval, nag_acks_so_far, docs_url — upgrade to end it, or fetch ack_url to relent one call at a rising cost); insufficient_scope (the API key lacks this operation’s x-teamyou-scope; carries required_scope, granted_scopes, docs_url — NOT retryable: scopes are fixed at key creation, so create a new key with the required scope instead of retrying); agent_retired (this key was revoked and its agent has been retired; carries agent {id, slug}, retiredAt, harness and remove {schedule, keyFile} — switch to a new key for this account if you were given one, otherwise stop checking in to this account; NOT retryable with this key); or an AI-preference denial AI_UPDATE_DISABLED / AI_DELETE_DISABLED / AI_SHARE_DISABLED (an account-wide block in Settings > Agent permissions is on; carries requiredPreference, blockedPreferences (every preference in the way; a sharing call can be blocked by two), fix (one line to relay to your person as-is: which switch or switches to turn off, and where) and settingsUrl (the link to those switches) - NOT retryable until the person turns the block off). Scopes and AI preferences compose as AND — passing one does not bypass the other. Gate codes only apply when the corresponding env flag is enabled.
- `404` — Resource not found (code: not_found).
- `429` — Rate limit exceeded (code: rate_limit_exceeded). Includes Retry-After and X-RateLimit-* headers.
- `500` — Internal server error (code: internal_error).
- `503` — The limit check itself failed, so the request was not run (code: rate_limit_unavailable). The caller did not go over a limit. Includes Retry-After.

### Unfollow a project's comment thread

```http
DELETE /projects/{id}/following
```

Stops commented items for this thread until you follow again.

**Skill CLI:** `teamyou.sh ty projects unfollow <project_id>`

**Parameters:**

- `id` (path, required) — string — Project: the project's id or its key (e.g. `PROJ-2`).

**Responses:**

- `200` — Not following.
- `400` — Validation error — invalid body, query, or path param (code: validation_error or invalid_json). `details` carries Zod field errors; PATCH /edges also adds `formErrors`.
- `401` — Missing, malformed, expired, or revoked API key (code: unauthorized). A revoked key whose agent has been retired answers 403 agent_retired instead.
- `403` — Forbidden. One of: api_key_user_not_found (key belongs to a user absent from this environment); client_identification_required (no recognized X-TeamYou-Client; carries skill_install_url, registerUrl, docs_url; only when TEAMYOU_GATE_REQUIRE_IDENTIFIED_CLIENT); agent_not_registered (registerUrl, skill_install_url, docs_url); skill_update_required (required_version, install_url, docs_url; possibly Deprecation/Sunset headers); client_update_nudge (a soft, relent-able staleness nudge for an agentic client below the latest release when TEAMYOU_GATE_NAG_ENABLED is on; carries verified_version, required_version, upgrade_url, ack_url, ack_token, nag_interval, nag_acks_so_far, docs_url — upgrade to end it, or fetch ack_url to relent one call at a rising cost); insufficient_scope (the API key lacks this operation’s x-teamyou-scope; carries required_scope, granted_scopes, docs_url — NOT retryable: scopes are fixed at key creation, so create a new key with the required scope instead of retrying); agent_retired (this key was revoked and its agent has been retired; carries agent {id, slug}, retiredAt, harness and remove {schedule, keyFile} — switch to a new key for this account if you were given one, otherwise stop checking in to this account; NOT retryable with this key); or an AI-preference denial AI_UPDATE_DISABLED / AI_DELETE_DISABLED / AI_SHARE_DISABLED (an account-wide block in Settings > Agent permissions is on; carries requiredPreference, blockedPreferences (every preference in the way; a sharing call can be blocked by two), fix (one line to relay to your person as-is: which switch or switches to turn off, and where) and settingsUrl (the link to those switches) - NOT retryable until the person turns the block off). Scopes and AI preferences compose as AND — passing one does not bypass the other. Gate codes only apply when the corresponding env flag is enabled.
- `404` — Resource not found (code: not_found).
- `429` — Rate limit exceeded (code: rate_limit_exceeded). Includes Retry-After and X-RateLimit-* headers.
- `500` — Internal server error (code: internal_error).
- `503` — The limit check itself failed, so the request was not run (code: rate_limit_unavailable). The caller did not go over a limit. Includes Retry-After.

### Add a reference to a project

```http
POST /projects/{id}/refs
```

Links a project to a topic/task/project/doc/url. Re-adding an existing target returns 409. `area`/`entity` targets are rejected (D5). Gated by aiUpdateEnabled (403 AI_UPDATE_DISABLED when the person has blocked agent updates), except on an onboarding project (one made from a template) with an open step assigned to you (to the agent your key belongs to): there you may add references even when agent updates are blocked.

**Skill CLI:** `teamyou.sh ty projects refs-add <project_id> --target-type topic|task|project|doc|url [--target-id <id>] [--url <url>] [--title <text>] [--after <ref_id>] [--before <ref_id>]`

**Parameters:**

- `id` (path, required) — string — Project: the project's id or its key (e.g. `PROJ-2`).

**Request body:**

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| `target` | object \| object | yes | The reference target. `url` targets carry a url; all others carry a targetId. Accepted targetType: topic\|task\|project\|doc\|url — `area` and `entity` are rejected by the projects API. |
| `position` | RefPosition | no | Where in the ref list to place it; omit to append. |

**Responses:**

- `201` — Created reference (hydrated — carries the target's resolved display name).
- `400` — Validation error — invalid body, query, or path param (code: validation_error or invalid_json). `details` carries Zod field errors; PATCH /edges also adds `formErrors`.
- `401` — Missing, malformed, expired, or revoked API key (code: unauthorized). A revoked key whose agent has been retired answers 403 agent_retired instead.
- `403` — Forbidden. One of: api_key_user_not_found (key belongs to a user absent from this environment); client_identification_required (no recognized X-TeamYou-Client; carries skill_install_url, registerUrl, docs_url; only when TEAMYOU_GATE_REQUIRE_IDENTIFIED_CLIENT); agent_not_registered (registerUrl, skill_install_url, docs_url); skill_update_required (required_version, install_url, docs_url; possibly Deprecation/Sunset headers); client_update_nudge (a soft, relent-able staleness nudge for an agentic client below the latest release when TEAMYOU_GATE_NAG_ENABLED is on; carries verified_version, required_version, upgrade_url, ack_url, ack_token, nag_interval, nag_acks_so_far, docs_url — upgrade to end it, or fetch ack_url to relent one call at a rising cost); insufficient_scope (the API key lacks this operation’s x-teamyou-scope; carries required_scope, granted_scopes, docs_url — NOT retryable: scopes are fixed at key creation, so create a new key with the required scope instead of retrying); agent_retired (this key was revoked and its agent has been retired; carries agent {id, slug}, retiredAt, harness and remove {schedule, keyFile} — switch to a new key for this account if you were given one, otherwise stop checking in to this account; NOT retryable with this key); or an AI-preference denial AI_UPDATE_DISABLED / AI_DELETE_DISABLED / AI_SHARE_DISABLED (an account-wide block in Settings > Agent permissions is on; carries requiredPreference, blockedPreferences (every preference in the way; a sharing call can be blocked by two), fix (one line to relay to your person as-is: which switch or switches to turn off, and where) and settingsUrl (the link to those switches) - NOT retryable until the person turns the block off). Scopes and AI preferences compose as AND — passing one does not bypass the other. Gate codes only apply when the corresponding env flag is enabled.
- `404` — Resource not found (code: not_found).
- `409` — Conflict — e.g. duplicate edge (same direction + label) or the scheduled-action slot limit reached (code: conflict).
- `422` — Unprocessable, and nothing was written. secret_refused: the body contains what looks like a password, a key or token, an ID number or a payment card number, which TeamYou never keeps for any agent. Carries field (where it was, such as `description` or `tasks[1].title`; null for the whole body) and kind (`api_key`, `private_key`, `password`, `card_number` or `id_number`), never the value. Take the secret out and send the write again; you can say where it is kept instead. NOT retryable unchanged.
- `429` — Rate limit exceeded (code: rate_limit_exceeded). Includes Retry-After and X-RateLimit-* headers.
- `500` — Internal server error (code: internal_error).
- `503` — The limit check itself failed, so the request was not run (code: rate_limit_unavailable). The caller did not go over a limit. Includes Retry-After.

### Write a document and link it to a project

```http
POST /projects/{id}/documents
```

Writes a markdown document to Agent Drive and links it to the project as a `doc` reference in one call. Requires BOTH `agent-drive:write` (the document) and `work:write` (the reference) — it is the one operation that composes two writes, and a key missing either gets a 403 before anything is written. Builds on the Agent Drive upsert, and document paths are GLOBAL per user rather than scoped to a project: re-posting the same path replaces that one document everywhere it is referenced, so namespace the path (e.g. `projects/<project-id>/<file>`) when two projects push files with the same local name. Idempotent — 201 when the reference is created, 200 when the document was already linked (never 409). Reads always resolve the reference display name from the live document title, so the reference is indistinguishable from one added with refs-add. Returns document metadata only (no content echo). Deleting the document later leaves the reference dangling and reads report it unresolved. Gated by aiUpdateEnabled (403 AI_UPDATE_DISABLED when the person has blocked agent updates), except on an onboarding project (one made from a template) with an open step assigned to you (to the agent your key belongs to): there you may push a new document, or replace one this project already references, even when agent updates are blocked; replacing a document the project does not reference still needs updates allowed.

**Skill CLI:** `teamyou.sh ty projects doc-push <project_id> <file> [--path <path>] [--title <text>] [--ref-title <text>] [--after <ref_id>] [--before <ref_id>]`

**Parameters:**

- `id` (path, required) — string — Project: the project's id or its key (e.g. `PROJ-2`).

**Request body:**

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| `document` | ProjectDocumentWriteRequest | yes | The markdown document to write (upsert-by-path): the POST /agent-drive body, except that `filename` may replace `path`. |
| `title` | string \| null | no | Optional label stored on the REFERENCE (not the document) and echoed back as `ref.title`. It does NOT change the hydrated `display`, which always resolves from the live document title (falling back to its path). Defaults to null. — len 0..1000 |
| `position` | RefPosition | no | Where in the project's ref list to place it; omit to append. |

**Responses:**

- `200` — Document written; it was already linked to this project, so the existing reference is returned unchanged.
- `201` — Document written and linked (hydrated reference).
- `400` — Validation error — invalid body, query, or path param (code: validation_error or invalid_json). `details` carries Zod field errors; PATCH /edges also adds `formErrors`.
- `401` — Missing, malformed, expired, or revoked API key (code: unauthorized). A revoked key whose agent has been retired answers 403 agent_retired instead.
- `402` — Payment required — product_limit_exceeded: the request would pass a limit of the account’s plan, and nothing was written. `detail` is a sentence to relay to the person; `upgradeUrl` (when a higher plan is better for this limit) is a page they can open to upgrade, and `settingsUrl` shows their plan and usage. Not retryable until the person upgrades or frees room.
- `403` — Forbidden. One of: api_key_user_not_found (key belongs to a user absent from this environment); client_identification_required (no recognized X-TeamYou-Client; carries skill_install_url, registerUrl, docs_url; only when TEAMYOU_GATE_REQUIRE_IDENTIFIED_CLIENT); agent_not_registered (registerUrl, skill_install_url, docs_url); skill_update_required (required_version, install_url, docs_url; possibly Deprecation/Sunset headers); client_update_nudge (a soft, relent-able staleness nudge for an agentic client below the latest release when TEAMYOU_GATE_NAG_ENABLED is on; carries verified_version, required_version, upgrade_url, ack_url, ack_token, nag_interval, nag_acks_so_far, docs_url — upgrade to end it, or fetch ack_url to relent one call at a rising cost); insufficient_scope (the API key lacks this operation’s x-teamyou-scope; carries required_scope, granted_scopes, docs_url — NOT retryable: scopes are fixed at key creation, so create a new key with the required scope instead of retrying); agent_retired (this key was revoked and its agent has been retired; carries agent {id, slug}, retiredAt, harness and remove {schedule, keyFile} — switch to a new key for this account if you were given one, otherwise stop checking in to this account; NOT retryable with this key); or an AI-preference denial AI_UPDATE_DISABLED / AI_DELETE_DISABLED / AI_SHARE_DISABLED (an account-wide block in Settings > Agent permissions is on; carries requiredPreference, blockedPreferences (every preference in the way; a sharing call can be blocked by two), fix (one line to relay to your person as-is: which switch or switches to turn off, and where) and settingsUrl (the link to those switches) - NOT retryable until the person turns the block off). Scopes and AI preferences compose as AND — passing one does not bypass the other. Gate codes only apply when the corresponding env flag is enabled.
- `404` — Resource not found (code: not_found).
- `422` — Unprocessable, and nothing was written. secret_refused: the body contains what looks like a password, a key or token, an ID number or a payment card number, which TeamYou never keeps for any agent. Carries field (where it was, such as `description` or `tasks[1].title`; null for the whole body) and kind (`api_key`, `private_key`, `password`, `card_number` or `id_number`), never the value. Take the secret out and send the write again; you can say where it is kept instead. NOT retryable unchanged.
- `429` — Rate limit exceeded (code: rate_limit_exceeded). Includes Retry-After and X-RateLimit-* headers.
- `500` — Internal server error (code: internal_error).
- `503` — The limit check itself failed, so the request was not run (code: rate_limit_unavailable). The caller did not go over a limit. Includes Retry-After.

### Reorder a project reference

```http
PATCH /projects/{id}/refs/{refId}
```

**Skill CLI:** `teamyou.sh ty projects refs-reorder <project_id> <ref_id> [--after <ref_id>] [--before <ref_id>]`

**Parameters:**

- `id` (path, required) — string — Project: the project's id or its key (e.g. `PROJ-2`).
- `refId` (path, required) — string — Reference id

**Request body:**

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| `after` | string | no | Place directly after this ref. — len 1..∞ |
| `before` | string | no | Place directly before this ref. — len 1..∞ |

**Responses:**

- `200` — Reordered reference.
- `400` — Validation error — invalid body, query, or path param (code: validation_error or invalid_json). `details` carries Zod field errors; PATCH /edges also adds `formErrors`.
- `401` — Missing, malformed, expired, or revoked API key (code: unauthorized). A revoked key whose agent has been retired answers 403 agent_retired instead.
- `403` — Forbidden. One of: api_key_user_not_found (key belongs to a user absent from this environment); client_identification_required (no recognized X-TeamYou-Client; carries skill_install_url, registerUrl, docs_url; only when TEAMYOU_GATE_REQUIRE_IDENTIFIED_CLIENT); agent_not_registered (registerUrl, skill_install_url, docs_url); skill_update_required (required_version, install_url, docs_url; possibly Deprecation/Sunset headers); client_update_nudge (a soft, relent-able staleness nudge for an agentic client below the latest release when TEAMYOU_GATE_NAG_ENABLED is on; carries verified_version, required_version, upgrade_url, ack_url, ack_token, nag_interval, nag_acks_so_far, docs_url — upgrade to end it, or fetch ack_url to relent one call at a rising cost); insufficient_scope (the API key lacks this operation’s x-teamyou-scope; carries required_scope, granted_scopes, docs_url — NOT retryable: scopes are fixed at key creation, so create a new key with the required scope instead of retrying); agent_retired (this key was revoked and its agent has been retired; carries agent {id, slug}, retiredAt, harness and remove {schedule, keyFile} — switch to a new key for this account if you were given one, otherwise stop checking in to this account; NOT retryable with this key); or an AI-preference denial AI_UPDATE_DISABLED / AI_DELETE_DISABLED / AI_SHARE_DISABLED (an account-wide block in Settings > Agent permissions is on; carries requiredPreference, blockedPreferences (every preference in the way; a sharing call can be blocked by two), fix (one line to relay to your person as-is: which switch or switches to turn off, and where) and settingsUrl (the link to those switches) - NOT retryable until the person turns the block off). Scopes and AI preferences compose as AND — passing one does not bypass the other. Gate codes only apply when the corresponding env flag is enabled.
- `404` — Resource not found (code: not_found).
- `429` — Rate limit exceeded (code: rate_limit_exceeded). Includes Retry-After and X-RateLimit-* headers.
- `500` — Internal server error (code: internal_error).
- `503` — The limit check itself failed, so the request was not run (code: rate_limit_unavailable). The caller did not go over a limit. Includes Retry-After.

### Remove a project reference

```http
DELETE /projects/{id}/refs/{refId}
```

**Skill CLI:** `teamyou.sh ty projects refs-remove <project_id> <ref_id>`

**Parameters:**

- `id` (path, required) — string — Project: the project's id or its key (e.g. `PROJ-2`).
- `refId` (path, required) — string — Reference id

**Responses:**

- `200` — Deleted.
- `400` — Validation error — invalid body, query, or path param (code: validation_error or invalid_json). `details` carries Zod field errors; PATCH /edges also adds `formErrors`.
- `401` — Missing, malformed, expired, or revoked API key (code: unauthorized). A revoked key whose agent has been retired answers 403 agent_retired instead.
- `403` — Forbidden. One of: api_key_user_not_found (key belongs to a user absent from this environment); client_identification_required (no recognized X-TeamYou-Client; carries skill_install_url, registerUrl, docs_url; only when TEAMYOU_GATE_REQUIRE_IDENTIFIED_CLIENT); agent_not_registered (registerUrl, skill_install_url, docs_url); skill_update_required (required_version, install_url, docs_url; possibly Deprecation/Sunset headers); client_update_nudge (a soft, relent-able staleness nudge for an agentic client below the latest release when TEAMYOU_GATE_NAG_ENABLED is on; carries verified_version, required_version, upgrade_url, ack_url, ack_token, nag_interval, nag_acks_so_far, docs_url — upgrade to end it, or fetch ack_url to relent one call at a rising cost); insufficient_scope (the API key lacks this operation’s x-teamyou-scope; carries required_scope, granted_scopes, docs_url — NOT retryable: scopes are fixed at key creation, so create a new key with the required scope instead of retrying); agent_retired (this key was revoked and its agent has been retired; carries agent {id, slug}, retiredAt, harness and remove {schedule, keyFile} — switch to a new key for this account if you were given one, otherwise stop checking in to this account; NOT retryable with this key); or an AI-preference denial AI_UPDATE_DISABLED / AI_DELETE_DISABLED / AI_SHARE_DISABLED (an account-wide block in Settings > Agent permissions is on; carries requiredPreference, blockedPreferences (every preference in the way; a sharing call can be blocked by two), fix (one line to relay to your person as-is: which switch or switches to turn off, and where) and settingsUrl (the link to those switches) - NOT retryable until the person turns the block off). Scopes and AI preferences compose as AND — passing one does not bypass the other. Gate codes only apply when the corresponding env flag is enabled.
- `404` — Resource not found (code: not_found).
- `429` — Rate limit exceeded (code: rate_limit_exceeded). Includes Retry-After and X-RateLimit-* headers.
- `500` — Internal server error (code: internal_error).
- `503` — The limit check itself failed, so the request was not run (code: rate_limit_unavailable). The caller did not go over a limit. Includes Retry-After.
