<!-- GENERATED FROM openapi.json — DO NOT EDIT. Run `pnpm skill:contract:generate`. -->

# TeamYou API Reference: Tasks (deprecated paths)

Base URL `https://www.teamyou.com/api/external/v1`. Every request except `GET /openapi.json` carries
`Authorization: Bearer ty_<key>`. Rate limits: reads 100/min, writes 60/min, search 30/min
(all 1000/hour); every response carries `X-RateLimit-Limit`, `X-RateLimit-Remaining` and
`X-RateLimit-Reset`. The full machine-readable contract is `GET /openapi.json`.

## Contents

- [List tasks (deprecated path)](#list-tasks-deprecated-path)
- [Create a task (deprecated path)](#create-a-task-deprecated-path)
- [Get a task (deprecated path)](#get-a-task-deprecated-path)
- [Update a task (deprecated path)](#update-a-task-deprecated-path)
- [Delete a task (deprecated path)](#delete-a-task-deprecated-path)
- [Mark a task done (deprecated path)](#mark-a-task-done-deprecated-path)

### List tasks (deprecated path)

```http
GET /todos
```

DEPRECATED PATH — use `GET /tasks` instead. Identical behaviour, identical request and response: this is the same handler, reached through an alias route file rather than a redirect, so a request body survives the call. Responses from this path carry `Deprecation: true` and a `Link: <…>; rel="successor-version"` header naming the live path. No removal date is scheduled; those headers are where that will change first.

**Parameters:**

- `status` (query) — `todo` | `done`
- `priority` (query) — `high` | `medium` | `low` | `none`
- `archived` (query) — `true` | `false`
- `orderBy` (query) — `createdAt` | `updatedAt` | `dueDate` | `priority`
- `orderDirection` (query) — `asc` | `desc`
- `limit` (query) — integer

**Responses:**

- `200` — Tasks for the authenticated user.
- `400` — Validation error — invalid body, query, or path param (code: validation_error or invalid_json). `details` carries Zod field errors; PATCH /edges also adds `formErrors`.
- `401` — Missing, malformed, expired, or revoked API key (code: unauthorized).
- `403` — Forbidden. One of: api_key_user_not_found (key belongs to a user absent from this environment); client_identification_required (no recognized X-TeamYou-Client; carries skill_install_url, registerUrl, docs_url; only when TEAMYOU_GATE_REQUIRE_IDENTIFIED_CLIENT); agent_not_registered (registerUrl, skill_install_url, docs_url); skill_update_required (required_version, install_url, docs_url; possibly Deprecation/Sunset headers); client_update_nudge (a soft, relent-able staleness nudge for an agentic client below the latest release when TEAMYOU_GATE_NAG_ENABLED is on; carries verified_version, required_version, upgrade_url, ack_url, ack_token, nag_interval, nag_acks_so_far, docs_url — upgrade to end it, or fetch ack_url to relent one call at a rising cost); insufficient_scope (the API key lacks this operation’s x-teamyou-scope; carries required_scope, granted_scopes, docs_url — NOT retryable: scopes are fixed at key creation, so create a new key with the required scope instead of retrying); or an AI-preference denial AI_UPDATE_DISABLED / AI_DELETE_DISABLED (requiredPreference). Scopes and AI preferences compose as AND — passing one does not bypass the other. Gate codes only apply when the corresponding env flag is enabled.
- `429` — Rate limit exceeded (code: rate_limit_exceeded). Includes Retry-After and X-RateLimit-* headers.
- `500` — Internal server error (code: internal_error).

### Create a task (deprecated path)

```http
POST /todos
```

DEPRECATED PATH — use `POST /tasks` instead. Identical behaviour, identical request and response: this is the same handler, reached through an alias route file rather than a redirect, so a request body survives the call. Responses from this path carry `Deprecation: true` and a `Link: <…>; rel="successor-version"` header naming the live path. No removal date is scheduled; those headers are where that will change first.

**Request body:**

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| `title` | string | yes | len 1..500 |
| `status` | `todo` \| `done` | no |  |
| `priority` | `high` \| `medium` \| `low` \| `none` | no |  |
| `dueDate` | string (date-time) | no |  |
| `topicId` | string | no | len 1..∞ |
| `projectId` | string | no | File the new task into this project's plan. — len 1..∞ |
| `position` | PlanPosition | no | Where in the plan to place it (requires projectId); omit to append. |

**Responses:**

- `201` — Created task.
- `400` — Validation error — invalid body, query, or path param (code: validation_error or invalid_json). `details` carries Zod field errors; PATCH /edges also adds `formErrors`.
- `401` — Missing, malformed, expired, or revoked API key (code: unauthorized).
- `403` — Forbidden. One of: api_key_user_not_found (key belongs to a user absent from this environment); client_identification_required (no recognized X-TeamYou-Client; carries skill_install_url, registerUrl, docs_url; only when TEAMYOU_GATE_REQUIRE_IDENTIFIED_CLIENT); agent_not_registered (registerUrl, skill_install_url, docs_url); skill_update_required (required_version, install_url, docs_url; possibly Deprecation/Sunset headers); client_update_nudge (a soft, relent-able staleness nudge for an agentic client below the latest release when TEAMYOU_GATE_NAG_ENABLED is on; carries verified_version, required_version, upgrade_url, ack_url, ack_token, nag_interval, nag_acks_so_far, docs_url — upgrade to end it, or fetch ack_url to relent one call at a rising cost); insufficient_scope (the API key lacks this operation’s x-teamyou-scope; carries required_scope, granted_scopes, docs_url — NOT retryable: scopes are fixed at key creation, so create a new key with the required scope instead of retrying); or an AI-preference denial AI_UPDATE_DISABLED / AI_DELETE_DISABLED (requiredPreference). Scopes and AI preferences compose as AND — passing one does not bypass the other. Gate codes only apply when the corresponding env flag is enabled.
- `429` — Rate limit exceeded (code: rate_limit_exceeded). Includes Retry-After and X-RateLimit-* headers.
- `500` — Internal server error (code: internal_error).

### Get a task (deprecated path)

```http
GET /todos/{id}
```

DEPRECATED PATH — use `GET /tasks/{id}` instead. Identical behaviour, identical request and response: this is the same handler, reached through an alias route file rather than a redirect, so a request body survives the call. Responses from this path carry `Deprecation: true` and a `Link: <…>; rel="successor-version"` header naming the live path. No removal date is scheduled; those headers are where that will change first.

**Parameters:**

- `id` (path, required) — string — Task id

**Responses:**

- `200` — The task.
- `400` — Validation error — invalid body, query, or path param (code: validation_error or invalid_json). `details` carries Zod field errors; PATCH /edges also adds `formErrors`.
- `401` — Missing, malformed, expired, or revoked API key (code: unauthorized).
- `403` — Forbidden. One of: api_key_user_not_found (key belongs to a user absent from this environment); client_identification_required (no recognized X-TeamYou-Client; carries skill_install_url, registerUrl, docs_url; only when TEAMYOU_GATE_REQUIRE_IDENTIFIED_CLIENT); agent_not_registered (registerUrl, skill_install_url, docs_url); skill_update_required (required_version, install_url, docs_url; possibly Deprecation/Sunset headers); client_update_nudge (a soft, relent-able staleness nudge for an agentic client below the latest release when TEAMYOU_GATE_NAG_ENABLED is on; carries verified_version, required_version, upgrade_url, ack_url, ack_token, nag_interval, nag_acks_so_far, docs_url — upgrade to end it, or fetch ack_url to relent one call at a rising cost); insufficient_scope (the API key lacks this operation’s x-teamyou-scope; carries required_scope, granted_scopes, docs_url — NOT retryable: scopes are fixed at key creation, so create a new key with the required scope instead of retrying); or an AI-preference denial AI_UPDATE_DISABLED / AI_DELETE_DISABLED (requiredPreference). Scopes and AI preferences compose as AND — passing one does not bypass the other. Gate codes only apply when the corresponding env flag is enabled.
- `404` — Resource not found (code: not_found).
- `429` — Rate limit exceeded (code: rate_limit_exceeded). Includes Retry-After and X-RateLimit-* headers.
- `500` — Internal server error (code: internal_error).

### Update a task (deprecated path)

```http
PUT /todos/{id}
```

DEPRECATED PATH — use `PUT /tasks/{id}` instead. Identical behaviour, identical request and response: this is the same handler, reached through an alias route file rather than a redirect, so a request body survives the call. Responses from this path carry `Deprecation: true` and a `Link: <…>; rel="successor-version"` header naming the live path. No removal date is scheduled; those headers are where that will change first.

**Parameters:**

- `id` (path, required) — string — Task id

**Request body:**

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| `title` | string | no | len 1..500 |
| `status` | `todo` \| `done` | no |  |
| `priority` | `high` \| `medium` \| `low` \| `none` | no |  |
| `dueDate` | string \| null | no |  |
| `isArchived` | boolean | no |  |
| `topicId` | string \| null | no | len 1..∞ |
| `projectId` | string \| null | no | Assign/move into this project; null removes from its project. — len 1..∞ |
| `position` | PlanPosition | no | Reorder within the project plan; with projectId, positions on assign. |

**Responses:**

- `200` — Updated task.
- `400` — Validation error — invalid body, query, or path param (code: validation_error or invalid_json). `details` carries Zod field errors; PATCH /edges also adds `formErrors`.
- `401` — Missing, malformed, expired, or revoked API key (code: unauthorized).
- `403` — Forbidden. One of: api_key_user_not_found (key belongs to a user absent from this environment); client_identification_required (no recognized X-TeamYou-Client; carries skill_install_url, registerUrl, docs_url; only when TEAMYOU_GATE_REQUIRE_IDENTIFIED_CLIENT); agent_not_registered (registerUrl, skill_install_url, docs_url); skill_update_required (required_version, install_url, docs_url; possibly Deprecation/Sunset headers); client_update_nudge (a soft, relent-able staleness nudge for an agentic client below the latest release when TEAMYOU_GATE_NAG_ENABLED is on; carries verified_version, required_version, upgrade_url, ack_url, ack_token, nag_interval, nag_acks_so_far, docs_url — upgrade to end it, or fetch ack_url to relent one call at a rising cost); insufficient_scope (the API key lacks this operation’s x-teamyou-scope; carries required_scope, granted_scopes, docs_url — NOT retryable: scopes are fixed at key creation, so create a new key with the required scope instead of retrying); or an AI-preference denial AI_UPDATE_DISABLED / AI_DELETE_DISABLED (requiredPreference). Scopes and AI preferences compose as AND — passing one does not bypass the other. Gate codes only apply when the corresponding env flag is enabled.
- `404` — Resource not found (code: not_found).
- `429` — Rate limit exceeded (code: rate_limit_exceeded). Includes Retry-After and X-RateLimit-* headers.
- `500` — Internal server error (code: internal_error).

### Delete a task (deprecated path)

```http
DELETE /todos/{id}
```

DEPRECATED PATH — use `DELETE /tasks/{id}` instead. Identical behaviour, identical request and response: this is the same handler, reached through an alias route file rather than a redirect, so a request body survives the call. Responses from this path carry `Deprecation: true` and a `Link: <…>; rel="successor-version"` header naming the live path. No removal date is scheduled; those headers are where that will change first.

**Parameters:**

- `id` (path, required) — string — Task id

**Responses:**

- `200` — Deleted.
- `400` — Validation error — invalid body, query, or path param (code: validation_error or invalid_json). `details` carries Zod field errors; PATCH /edges also adds `formErrors`.
- `401` — Missing, malformed, expired, or revoked API key (code: unauthorized).
- `403` — Forbidden. One of: api_key_user_not_found (key belongs to a user absent from this environment); client_identification_required (no recognized X-TeamYou-Client; carries skill_install_url, registerUrl, docs_url; only when TEAMYOU_GATE_REQUIRE_IDENTIFIED_CLIENT); agent_not_registered (registerUrl, skill_install_url, docs_url); skill_update_required (required_version, install_url, docs_url; possibly Deprecation/Sunset headers); client_update_nudge (a soft, relent-able staleness nudge for an agentic client below the latest release when TEAMYOU_GATE_NAG_ENABLED is on; carries verified_version, required_version, upgrade_url, ack_url, ack_token, nag_interval, nag_acks_so_far, docs_url — upgrade to end it, or fetch ack_url to relent one call at a rising cost); insufficient_scope (the API key lacks this operation’s x-teamyou-scope; carries required_scope, granted_scopes, docs_url — NOT retryable: scopes are fixed at key creation, so create a new key with the required scope instead of retrying); or an AI-preference denial AI_UPDATE_DISABLED / AI_DELETE_DISABLED (requiredPreference). Scopes and AI preferences compose as AND — passing one does not bypass the other. Gate codes only apply when the corresponding env flag is enabled.
- `404` — Resource not found (code: not_found).
- `429` — Rate limit exceeded (code: rate_limit_exceeded). Includes Retry-After and X-RateLimit-* headers.
- `500` — Internal server error (code: internal_error).

### Mark a task done (deprecated path)

```http
POST /todos/{id}/complete
```

DEPRECATED PATH — use `POST /tasks/{id}/complete` instead. Identical behaviour, identical request and response: this is the same handler, reached through an alias route file rather than a redirect, so a request body survives the call. Responses from this path carry `Deprecation: true` and a `Link: <…>; rel="successor-version"` header naming the live path. No removal date is scheduled; those headers are where that will change first.

**Parameters:**

- `id` (path, required) — string — Task id

**Responses:**

- `200` — Completed task.
- `401` — Missing, malformed, expired, or revoked API key (code: unauthorized).
- `403` — Forbidden. One of: api_key_user_not_found (key belongs to a user absent from this environment); client_identification_required (no recognized X-TeamYou-Client; carries skill_install_url, registerUrl, docs_url; only when TEAMYOU_GATE_REQUIRE_IDENTIFIED_CLIENT); agent_not_registered (registerUrl, skill_install_url, docs_url); skill_update_required (required_version, install_url, docs_url; possibly Deprecation/Sunset headers); client_update_nudge (a soft, relent-able staleness nudge for an agentic client below the latest release when TEAMYOU_GATE_NAG_ENABLED is on; carries verified_version, required_version, upgrade_url, ack_url, ack_token, nag_interval, nag_acks_so_far, docs_url — upgrade to end it, or fetch ack_url to relent one call at a rising cost); insufficient_scope (the API key lacks this operation’s x-teamyou-scope; carries required_scope, granted_scopes, docs_url — NOT retryable: scopes are fixed at key creation, so create a new key with the required scope instead of retrying); or an AI-preference denial AI_UPDATE_DISABLED / AI_DELETE_DISABLED (requiredPreference). Scopes and AI preferences compose as AND — passing one does not bypass the other. Gate codes only apply when the corresponding env flag is enabled.
- `404` — Resource not found (code: not_found).
- `429` — Rate limit exceeded (code: rate_limit_exceeded). Includes Retry-After and X-RateLimit-* headers.
- `500` — Internal server error (code: internal_error).
