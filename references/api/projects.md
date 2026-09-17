<!-- GENERATED FROM openapi.json — DO NOT EDIT. Run `pnpm skill:contract:generate`. -->

# TeamYou API Reference: Projects

Base URL `https://www.teamyou.com/api/external/v1`. Every request except `GET /openapi.json` carries
`Authorization: Bearer ty_<key>`. Rate limits: reads 100/min, writes 60/min, search 30/min
(all 1000/hour); every response carries `X-RateLimit-Limit`, `X-RateLimit-Remaining` and
`X-RateLimit-Reset`. The full machine-readable contract is `GET /openapi.json`.

## Contents

- [List projects](#list-projects)
- [Create a project, optionally with its plan and references](#create-a-project-optionally-with-its-plan-and-references)
- [Get a project (one-call hydrate)](#get-a-project-one-call-hydrate)
- [Update a project](#update-a-project)
- [Delete a project](#delete-a-project)
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
- `401` — Missing, malformed, expired, or revoked API key (code: unauthorized).
- `403` — Forbidden. One of: api_key_user_not_found (key belongs to a user absent from this environment); client_identification_required (no recognized X-TeamYou-Client; carries skill_install_url, registerUrl, docs_url; only when TEAMYOU_GATE_REQUIRE_IDENTIFIED_CLIENT); agent_not_registered (registerUrl, skill_install_url, docs_url); skill_update_required (required_version, install_url, docs_url; possibly Deprecation/Sunset headers); client_update_nudge (a soft, relent-able staleness nudge for an agentic client below the latest release when TEAMYOU_GATE_NAG_ENABLED is on; carries verified_version, required_version, upgrade_url, ack_url, ack_token, nag_interval, nag_acks_so_far, docs_url — upgrade to end it, or fetch ack_url to relent one call at a rising cost); insufficient_scope (the API key lacks this operation’s x-teamyou-scope; carries required_scope, granted_scopes, docs_url — NOT retryable: scopes are fixed at key creation, so create a new key with the required scope instead of retrying); or an AI-preference denial AI_UPDATE_DISABLED / AI_DELETE_DISABLED (requiredPreference). Scopes and AI preferences compose as AND — passing one does not bypass the other. Gate codes only apply when the corresponding env flag is enabled.
- `429` — Rate limit exceeded (code: rate_limit_exceeded). Includes Retry-After and X-RateLimit-* headers.
- `500` — Internal server error (code: internal_error).

### Create a project, optionally with its plan and references

```http
POST /projects
```

Creates a project. Optional `todos` and `refs` arrays let one call stand up a whole body of work instead of 1+N+M round trips - the project, every todo and every reference are written in a SINGLE transaction, so a failure anywhere leaves nothing behind (no half-built project to clean up). Array order is the order in both arrays; there are no per-item positions. Create-only: no upsert, no dedupe, no idempotency key, no partial success. The response is always the hydrated project (plan + refs + progress), whether or not children were sent, so no follow-up read is needed.

**Skill CLI:** `teamyou.sh ty projects create <name> [--goal <text>] [--status active|waiting|done|archived] [--waiting-on <text>] [--notes <text>] [--due-date <YYYY-MM-DD>] [--todo <title>]... [--ref <type>:<value>]... [--from-json <file>]`

**Request body:**

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| `name` | string | yes | len 1..255 |
| `goal` | string \| null | no | len 0..5000 |
| `status` | `active` \| `waiting` \| `done` \| `archived` | no |  |
| `waitingOn` | string \| null | no | Who or what the work is blocked on — a short name or phrase ("Bill", "legal review"), not a status update. Both project surfaces render it in a narrow fixed-width slot and truncate what does not fit, so prose written here is stored but never read. Meaningful when status=waiting, though not enforced against it: a project can carry this while active. — len 0..1000 |
| `preset` | string \| null | no | Reserved; unused in v1. — len 0..255 |
| `notes` | string \| null | no | Narrative markdown body: what this project is, in prose. Stored verbatim. — len 0..50000 |
| `dueDate` | string \| null | no | Calendar day (YYYY-MM-DD) to aim at. A soft target only. Not a date-time instant, unlike a todo dueDate. — pattern |
| `todos` | InlineProjectTodo[] | no | Optional plan to create with the project. Array order IS the plan order. Written in the same transaction as the project: all-or-nothing, so a failure anywhere creates nothing. Create-only - there is no upsert or dedupe, so two identical calls create two projects. — max 200 items |
| `refs` | InlineProjectRef[] | no | Optional references to create with the project. Each entry is a FLAT target object (`{"targetType":"url","url":"https://example.com/spec","title":"Spec"}`), NOT the refs-add `{"target":{...}}` wrapper. Array order IS the order. Same transaction and all-or-nothing semantics as `todos`. Naming the same target twice in one array is a 400. Refs cannot target the todos created in the same call (those ids do not exist yet) - add them afterwards with refs-add. — max 100 items |

**Responses:**

- `201` — Created project, hydrated.
- `400` — Validation error — invalid body, query, or path param (code: validation_error or invalid_json). `details` carries Zod field errors; PATCH /edges also adds `formErrors`.
- `401` — Missing, malformed, expired, or revoked API key (code: unauthorized).
- `403` — Forbidden. One of: api_key_user_not_found (key belongs to a user absent from this environment); client_identification_required (no recognized X-TeamYou-Client; carries skill_install_url, registerUrl, docs_url; only when TEAMYOU_GATE_REQUIRE_IDENTIFIED_CLIENT); agent_not_registered (registerUrl, skill_install_url, docs_url); skill_update_required (required_version, install_url, docs_url; possibly Deprecation/Sunset headers); client_update_nudge (a soft, relent-able staleness nudge for an agentic client below the latest release when TEAMYOU_GATE_NAG_ENABLED is on; carries verified_version, required_version, upgrade_url, ack_url, ack_token, nag_interval, nag_acks_so_far, docs_url — upgrade to end it, or fetch ack_url to relent one call at a rising cost); insufficient_scope (the API key lacks this operation’s x-teamyou-scope; carries required_scope, granted_scopes, docs_url — NOT retryable: scopes are fixed at key creation, so create a new key with the required scope instead of retrying); or an AI-preference denial AI_UPDATE_DISABLED / AI_DELETE_DISABLED (requiredPreference). Scopes and AI preferences compose as AND — passing one does not bypass the other. Gate codes only apply when the corresponding env flag is enabled.
- `429` — Rate limit exceeded (code: rate_limit_exceeded). Includes Retry-After and X-RateLimit-* headers.
- `500` — Internal server error (code: internal_error).

### Get a project (one-call hydrate)

```http
GET /projects/{id}
```

Returns the project with its ordered todo plan, hydrated references, a progress rollup, and `nextAction` in a single request — the agent orientation read. `nextAction` is the first incomplete, non-archived todo by plan position (null when there is none); it is computed per read and never stored, so do not write it back. Dangling refs resolve defensively as { resolved: false, reason: "missing" } rather than failing.

**Skill CLI:** `teamyou.sh ty projects get <project_id>`

**Parameters:**

- `id` (path, required) — string — Project id

**Responses:**

- `200` — Project with plan, refs, and progress.
- `400` — Validation error — invalid body, query, or path param (code: validation_error or invalid_json). `details` carries Zod field errors; PATCH /edges also adds `formErrors`.
- `401` — Missing, malformed, expired, or revoked API key (code: unauthorized).
- `403` — Forbidden. One of: api_key_user_not_found (key belongs to a user absent from this environment); client_identification_required (no recognized X-TeamYou-Client; carries skill_install_url, registerUrl, docs_url; only when TEAMYOU_GATE_REQUIRE_IDENTIFIED_CLIENT); agent_not_registered (registerUrl, skill_install_url, docs_url); skill_update_required (required_version, install_url, docs_url; possibly Deprecation/Sunset headers); client_update_nudge (a soft, relent-able staleness nudge for an agentic client below the latest release when TEAMYOU_GATE_NAG_ENABLED is on; carries verified_version, required_version, upgrade_url, ack_url, ack_token, nag_interval, nag_acks_so_far, docs_url — upgrade to end it, or fetch ack_url to relent one call at a rising cost); insufficient_scope (the API key lacks this operation’s x-teamyou-scope; carries required_scope, granted_scopes, docs_url — NOT retryable: scopes are fixed at key creation, so create a new key with the required scope instead of retrying); or an AI-preference denial AI_UPDATE_DISABLED / AI_DELETE_DISABLED (requiredPreference). Scopes and AI preferences compose as AND — passing one does not bypass the other. Gate codes only apply when the corresponding env flag is enabled.
- `404` — Resource not found (code: not_found).
- `429` — Rate limit exceeded (code: rate_limit_exceeded). Includes Retry-After and X-RateLimit-* headers.
- `500` — Internal server error (code: internal_error).

### Update a project

```http
PUT /projects/{id}
```

**Skill CLI:** `teamyou.sh ty projects update <project_id> [--name <text>] [--goal <text>] [--status active|waiting|done|archived] [--waiting-on <text>] [--notes <text>] [--due-date <YYYY-MM-DD>] [--no-goal] [--no-waiting-on] [--no-notes] [--no-due-date]`

**Parameters:**

- `id` (path, required) — string — Project id

**Request body:**

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| `name` | string | no | len 1..255 |
| `goal` | string \| null | no | len 0..5000 |
| `status` | `active` \| `waiting` \| `done` \| `archived` | no |  |
| `waitingOn` | string \| null | no | Who or what the work is blocked on — a short name or phrase ("Bill", "legal review"), not a status update. Both project surfaces render it in a narrow fixed-width slot and truncate what does not fit, so prose written here is stored but never read. Meaningful when status=waiting, though not enforced against it: a project can carry this while active. — len 0..1000 |
| `preset` | string \| null | no | len 0..255 |
| `notes` | string \| null | no | Narrative markdown body: what this project is, in prose. Stored verbatim. — len 0..50000 |
| `dueDate` | string \| null | no | Calendar day (YYYY-MM-DD) to aim at. A soft target only. Not a date-time instant, unlike a todo dueDate. — pattern |

**Responses:**

- `200` — Updated project.
- `400` — Validation error — invalid body, query, or path param (code: validation_error or invalid_json). `details` carries Zod field errors; PATCH /edges also adds `formErrors`.
- `401` — Missing, malformed, expired, or revoked API key (code: unauthorized).
- `403` — Forbidden. One of: api_key_user_not_found (key belongs to a user absent from this environment); client_identification_required (no recognized X-TeamYou-Client; carries skill_install_url, registerUrl, docs_url; only when TEAMYOU_GATE_REQUIRE_IDENTIFIED_CLIENT); agent_not_registered (registerUrl, skill_install_url, docs_url); skill_update_required (required_version, install_url, docs_url; possibly Deprecation/Sunset headers); client_update_nudge (a soft, relent-able staleness nudge for an agentic client below the latest release when TEAMYOU_GATE_NAG_ENABLED is on; carries verified_version, required_version, upgrade_url, ack_url, ack_token, nag_interval, nag_acks_so_far, docs_url — upgrade to end it, or fetch ack_url to relent one call at a rising cost); insufficient_scope (the API key lacks this operation’s x-teamyou-scope; carries required_scope, granted_scopes, docs_url — NOT retryable: scopes are fixed at key creation, so create a new key with the required scope instead of retrying); or an AI-preference denial AI_UPDATE_DISABLED / AI_DELETE_DISABLED (requiredPreference). Scopes and AI preferences compose as AND — passing one does not bypass the other. Gate codes only apply when the corresponding env flag is enabled.
- `404` — Resource not found (code: not_found).
- `429` — Rate limit exceeded (code: rate_limit_exceeded). Includes Retry-After and X-RateLimit-* headers.
- `500` — Internal server error (code: internal_error).

### Delete a project

```http
DELETE /projects/{id}
```

Orphans the project's todos (nulls their projectId + plan position) and cascades its references. The todos themselves are not deleted.

**Skill CLI:** `teamyou.sh ty projects delete <project_id>`

**Parameters:**

- `id` (path, required) — string — Project id

**Responses:**

- `200` — Deleted.
- `400` — Validation error — invalid body, query, or path param (code: validation_error or invalid_json). `details` carries Zod field errors; PATCH /edges also adds `formErrors`.
- `401` — Missing, malformed, expired, or revoked API key (code: unauthorized).
- `403` — Forbidden. One of: api_key_user_not_found (key belongs to a user absent from this environment); client_identification_required (no recognized X-TeamYou-Client; carries skill_install_url, registerUrl, docs_url; only when TEAMYOU_GATE_REQUIRE_IDENTIFIED_CLIENT); agent_not_registered (registerUrl, skill_install_url, docs_url); skill_update_required (required_version, install_url, docs_url; possibly Deprecation/Sunset headers); client_update_nudge (a soft, relent-able staleness nudge for an agentic client below the latest release when TEAMYOU_GATE_NAG_ENABLED is on; carries verified_version, required_version, upgrade_url, ack_url, ack_token, nag_interval, nag_acks_so_far, docs_url — upgrade to end it, or fetch ack_url to relent one call at a rising cost); insufficient_scope (the API key lacks this operation’s x-teamyou-scope; carries required_scope, granted_scopes, docs_url — NOT retryable: scopes are fixed at key creation, so create a new key with the required scope instead of retrying); or an AI-preference denial AI_UPDATE_DISABLED / AI_DELETE_DISABLED (requiredPreference). Scopes and AI preferences compose as AND — passing one does not bypass the other. Gate codes only apply when the corresponding env flag is enabled.
- `404` — Resource not found (code: not_found).
- `429` — Rate limit exceeded (code: rate_limit_exceeded). Includes Retry-After and X-RateLimit-* headers.
- `500` — Internal server error (code: internal_error).

### Add a reference to a project

```http
POST /projects/{id}/refs
```

Links a project to a topic/todo/project/doc/url. Re-adding an existing target returns 409. `area`/`entity` targets are rejected (D5).

**Skill CLI:** `teamyou.sh ty projects refs-add <project_id> --target-type topic|todo|project|doc|url [--target-id <id>] [--url <url>] [--title <text>] [--after <ref_id>] [--before <ref_id>]`

**Parameters:**

- `id` (path, required) — string — Project id

**Request body:**

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| `target` | object \| object | yes | The reference target. `url` targets carry a url; all others carry a targetId. Accepted targetType: topic\|todo\|project\|doc\|url — `area` and `entity` are rejected by the projects API. |
| `position` | RefPosition | no | Where in the ref list to place it; omit to append. |

**Responses:**

- `201` — Created reference (hydrated — carries the target's resolved display name).
- `400` — Validation error — invalid body, query, or path param (code: validation_error or invalid_json). `details` carries Zod field errors; PATCH /edges also adds `formErrors`.
- `401` — Missing, malformed, expired, or revoked API key (code: unauthorized).
- `403` — Forbidden. One of: api_key_user_not_found (key belongs to a user absent from this environment); client_identification_required (no recognized X-TeamYou-Client; carries skill_install_url, registerUrl, docs_url; only when TEAMYOU_GATE_REQUIRE_IDENTIFIED_CLIENT); agent_not_registered (registerUrl, skill_install_url, docs_url); skill_update_required (required_version, install_url, docs_url; possibly Deprecation/Sunset headers); client_update_nudge (a soft, relent-able staleness nudge for an agentic client below the latest release when TEAMYOU_GATE_NAG_ENABLED is on; carries verified_version, required_version, upgrade_url, ack_url, ack_token, nag_interval, nag_acks_so_far, docs_url — upgrade to end it, or fetch ack_url to relent one call at a rising cost); insufficient_scope (the API key lacks this operation’s x-teamyou-scope; carries required_scope, granted_scopes, docs_url — NOT retryable: scopes are fixed at key creation, so create a new key with the required scope instead of retrying); or an AI-preference denial AI_UPDATE_DISABLED / AI_DELETE_DISABLED (requiredPreference). Scopes and AI preferences compose as AND — passing one does not bypass the other. Gate codes only apply when the corresponding env flag is enabled.
- `404` — Resource not found (code: not_found).
- `409` — Conflict — e.g. duplicate edge (same direction + label) or the scheduled-action slot limit reached (code: conflict).
- `429` — Rate limit exceeded (code: rate_limit_exceeded). Includes Retry-After and X-RateLimit-* headers.
- `500` — Internal server error (code: internal_error).

### Write a document and link it to a project

```http
POST /projects/{id}/documents
```

Writes a markdown document to Agent Drive and links it to the project as a `doc` reference in one call. Requires BOTH `agent-drive:write` (the document) and `work:write` (the reference) — it is the one operation that composes two writes, and a key missing either gets a 403 before anything is written. Builds on the Agent Drive upsert, and document paths are GLOBAL per user rather than scoped to a project: re-posting the same path replaces that one document everywhere it is referenced, so namespace the path (e.g. `projects/<project-id>/<file>`) when two projects push files with the same local name. Idempotent — 201 when the reference is created, 200 when the document was already linked (never 409). Reads always resolve the reference display name from the live document title, so the reference is indistinguishable from one added with refs-add. Returns document metadata only (no content echo). Deleting the document later leaves the reference dangling and reads report it unresolved.

**Skill CLI:** `teamyou.sh ty projects doc-push <project_id> <file> [--path <path>] [--title <text>] [--ref-title <text>] [--after <ref_id>] [--before <ref_id>]`

**Parameters:**

- `id` (path, required) — string — Project id

**Request body:**

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| `document` | WriteDocumentRequest | yes | The markdown document to write (upsert-by-path), identical to the POST /agent-drive body. |
| `title` | string \| null | no | Optional label stored on the REFERENCE (not the document) and echoed back as `ref.title`. It does NOT change the hydrated `display`, which always resolves from the live document title (falling back to its path). Defaults to null. — len 0..1000 |
| `position` | RefPosition | no | Where in the project's ref list to place it; omit to append. |

**Responses:**

- `200` — Document written; it was already linked to this project, so the existing reference is returned unchanged.
- `201` — Document written and linked (hydrated reference).
- `400` — Validation error — invalid body, query, or path param (code: validation_error or invalid_json). `details` carries Zod field errors; PATCH /edges also adds `formErrors`.
- `401` — Missing, malformed, expired, or revoked API key (code: unauthorized).
- `403` — Forbidden. One of: api_key_user_not_found (key belongs to a user absent from this environment); client_identification_required (no recognized X-TeamYou-Client; carries skill_install_url, registerUrl, docs_url; only when TEAMYOU_GATE_REQUIRE_IDENTIFIED_CLIENT); agent_not_registered (registerUrl, skill_install_url, docs_url); skill_update_required (required_version, install_url, docs_url; possibly Deprecation/Sunset headers); client_update_nudge (a soft, relent-able staleness nudge for an agentic client below the latest release when TEAMYOU_GATE_NAG_ENABLED is on; carries verified_version, required_version, upgrade_url, ack_url, ack_token, nag_interval, nag_acks_so_far, docs_url — upgrade to end it, or fetch ack_url to relent one call at a rising cost); insufficient_scope (the API key lacks this operation’s x-teamyou-scope; carries required_scope, granted_scopes, docs_url — NOT retryable: scopes are fixed at key creation, so create a new key with the required scope instead of retrying); or an AI-preference denial AI_UPDATE_DISABLED / AI_DELETE_DISABLED (requiredPreference). Scopes and AI preferences compose as AND — passing one does not bypass the other. Gate codes only apply when the corresponding env flag is enabled.
- `404` — Resource not found (code: not_found).
- `429` — Rate limit exceeded (code: rate_limit_exceeded). Includes Retry-After and X-RateLimit-* headers.
- `500` — Internal server error (code: internal_error).

### Reorder a project reference

```http
PATCH /projects/{id}/refs/{refId}
```

**Skill CLI:** `teamyou.sh ty projects refs-reorder <project_id> <ref_id> [--after <ref_id>] [--before <ref_id>]`

**Parameters:**

- `id` (path, required) — string — Project id
- `refId` (path, required) — string — Reference id

**Request body:**

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| `after` | string | no | Place after this ref. — len 1..∞ |
| `before` | string | no | Place before this ref. — len 1..∞ |

**Responses:**

- `200` — Reordered reference.
- `400` — Validation error — invalid body, query, or path param (code: validation_error or invalid_json). `details` carries Zod field errors; PATCH /edges also adds `formErrors`.
- `401` — Missing, malformed, expired, or revoked API key (code: unauthorized).
- `403` — Forbidden. One of: api_key_user_not_found (key belongs to a user absent from this environment); client_identification_required (no recognized X-TeamYou-Client; carries skill_install_url, registerUrl, docs_url; only when TEAMYOU_GATE_REQUIRE_IDENTIFIED_CLIENT); agent_not_registered (registerUrl, skill_install_url, docs_url); skill_update_required (required_version, install_url, docs_url; possibly Deprecation/Sunset headers); client_update_nudge (a soft, relent-able staleness nudge for an agentic client below the latest release when TEAMYOU_GATE_NAG_ENABLED is on; carries verified_version, required_version, upgrade_url, ack_url, ack_token, nag_interval, nag_acks_so_far, docs_url — upgrade to end it, or fetch ack_url to relent one call at a rising cost); insufficient_scope (the API key lacks this operation’s x-teamyou-scope; carries required_scope, granted_scopes, docs_url — NOT retryable: scopes are fixed at key creation, so create a new key with the required scope instead of retrying); or an AI-preference denial AI_UPDATE_DISABLED / AI_DELETE_DISABLED (requiredPreference). Scopes and AI preferences compose as AND — passing one does not bypass the other. Gate codes only apply when the corresponding env flag is enabled.
- `404` — Resource not found (code: not_found).
- `429` — Rate limit exceeded (code: rate_limit_exceeded). Includes Retry-After and X-RateLimit-* headers.
- `500` — Internal server error (code: internal_error).

### Remove a project reference

```http
DELETE /projects/{id}/refs/{refId}
```

**Skill CLI:** `teamyou.sh ty projects refs-remove <project_id> <ref_id>`

**Parameters:**

- `id` (path, required) — string — Project id
- `refId` (path, required) — string — Reference id

**Responses:**

- `200` — Deleted.
- `400` — Validation error — invalid body, query, or path param (code: validation_error or invalid_json). `details` carries Zod field errors; PATCH /edges also adds `formErrors`.
- `401` — Missing, malformed, expired, or revoked API key (code: unauthorized).
- `403` — Forbidden. One of: api_key_user_not_found (key belongs to a user absent from this environment); client_identification_required (no recognized X-TeamYou-Client; carries skill_install_url, registerUrl, docs_url; only when TEAMYOU_GATE_REQUIRE_IDENTIFIED_CLIENT); agent_not_registered (registerUrl, skill_install_url, docs_url); skill_update_required (required_version, install_url, docs_url; possibly Deprecation/Sunset headers); client_update_nudge (a soft, relent-able staleness nudge for an agentic client below the latest release when TEAMYOU_GATE_NAG_ENABLED is on; carries verified_version, required_version, upgrade_url, ack_url, ack_token, nag_interval, nag_acks_so_far, docs_url — upgrade to end it, or fetch ack_url to relent one call at a rising cost); insufficient_scope (the API key lacks this operation’s x-teamyou-scope; carries required_scope, granted_scopes, docs_url — NOT retryable: scopes are fixed at key creation, so create a new key with the required scope instead of retrying); or an AI-preference denial AI_UPDATE_DISABLED / AI_DELETE_DISABLED (requiredPreference). Scopes and AI preferences compose as AND — passing one does not bypass the other. Gate codes only apply when the corresponding env flag is enabled.
- `404` — Resource not found (code: not_found).
- `429` — Rate limit exceeded (code: rate_limit_exceeded). Includes Retry-After and X-RateLimit-* headers.
- `500` — Internal server error (code: internal_error).
