<!-- GENERATED FROM openapi.json — DO NOT EDIT. Run `pnpm skill:contract:generate`. -->

# TeamYou API Reference: Tasks

Base URL `https://www.teamyou.com/api/external/v1`. Every request except `GET /openapi.json` carries
`Authorization: Bearer ty_<key>`. Rate limits: reads 100/min, writes 60/min, search 30/min
(all 1000/hour); every response carries `X-RateLimit-Limit`, `X-RateLimit-Remaining` and
`X-RateLimit-Reset`. The full machine-readable contract is `GET /openapi.json`.

## Contents

- [List tasks](#list-tasks)
- [Create a task](#create-a-task)
- [Get a task](#get-a-task)
- [Update a task](#update-a-task)
- [Delete a task](#delete-a-task)
- [Mark a task done](#mark-a-task-done)
- [List comments on a task](#list-comments-on-a-task)
- [Comment on a task](#comment-on-a-task)
- [Follow a task's comment thread](#follow-a-tasks-comment-thread)
- [Unfollow a task's comment thread](#unfollow-a-tasks-comment-thread)

### List tasks

```http
GET /tasks
```

**Skill CLI:** `teamyou.sh ty tasks list [--status todo|done] [--archived] [--priority high|medium|low|none] [--assignee me|none|<agent>] [--order-by createdAt|updatedAt|dueDate|priority] [--limit N]`

**Parameters:**

- `status` (query) — `todo` | `done`
- `priority` (query) — `high` | `medium` | `low` | `none`
- `archived` (query) — `true` | `false`
- `orderBy` (query) — `createdAt` | `updatedAt` | `dueDate` | `priority`
- `orderDirection` (query) — `asc` | `desc`
- `assignee` (query) — string — me, none, or an agent id or slug.
- `limit` (query) — integer

**Responses:**

- `200` — Tasks for the authenticated user.
- `400` — Validation error — invalid body, query, or path param (code: validation_error or invalid_json). `details` carries Zod field errors; PATCH /edges also adds `formErrors`.
- `401` — Missing, malformed, expired, or revoked API key (code: unauthorized).
- `403` — Forbidden. One of: api_key_user_not_found (key belongs to a user absent from this environment); client_identification_required (no recognized X-TeamYou-Client; carries skill_install_url, registerUrl, docs_url; only when TEAMYOU_GATE_REQUIRE_IDENTIFIED_CLIENT); agent_not_registered (registerUrl, skill_install_url, docs_url); skill_update_required (required_version, install_url, docs_url; possibly Deprecation/Sunset headers); client_update_nudge (a soft, relent-able staleness nudge for an agentic client below the latest release when TEAMYOU_GATE_NAG_ENABLED is on; carries verified_version, required_version, upgrade_url, ack_url, ack_token, nag_interval, nag_acks_so_far, docs_url — upgrade to end it, or fetch ack_url to relent one call at a rising cost); insufficient_scope (the API key lacks this operation’s x-teamyou-scope; carries required_scope, granted_scopes, docs_url — NOT retryable: scopes are fixed at key creation, so create a new key with the required scope instead of retrying); or an AI-preference denial AI_UPDATE_DISABLED / AI_DELETE_DISABLED (requiredPreference). Scopes and AI preferences compose as AND — passing one does not bypass the other. Gate codes only apply when the corresponding env flag is enabled.
- `429` — Rate limit exceeded (code: rate_limit_exceeded). Includes Retry-After and X-RateLimit-* headers.
- `500` — Internal server error (code: internal_error).

### Create a task

```http
POST /tasks
```

**Skill CLI:** `teamyou.sh ty tasks create <title> [--description <text>] [--status todo|done] [--priority high|medium|low|none] [--due-date <ISO8601>] [--topic-id <id>] [--project-id <id>] [--after <task_id>] [--before <task_id>] [--assignee <agent>]`

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
| `assigneeAgentId` | string | no | An agent id or slug; it gets an assigned item. 403 assignment_refused (reason escalation), creating nothing, when that agent holds scopes your key does not or has no live key. — len 1..64 |

**Responses:**

- `201` — Created task.
- `400` — Validation error — invalid body, query, or path param (code: validation_error or invalid_json). `details` carries Zod field errors; PATCH /edges also adds `formErrors`.
- `401` — Missing, malformed, expired, or revoked API key (code: unauthorized).
- `403` — Forbidden. One of: api_key_user_not_found (key belongs to a user absent from this environment); client_identification_required (no recognized X-TeamYou-Client; carries skill_install_url, registerUrl, docs_url; only when TEAMYOU_GATE_REQUIRE_IDENTIFIED_CLIENT); agent_not_registered (registerUrl, skill_install_url, docs_url); skill_update_required (required_version, install_url, docs_url; possibly Deprecation/Sunset headers); client_update_nudge (a soft, relent-able staleness nudge for an agentic client below the latest release when TEAMYOU_GATE_NAG_ENABLED is on; carries verified_version, required_version, upgrade_url, ack_url, ack_token, nag_interval, nag_acks_so_far, docs_url — upgrade to end it, or fetch ack_url to relent one call at a rising cost); insufficient_scope (the API key lacks this operation’s x-teamyou-scope; carries required_scope, granted_scopes, docs_url — NOT retryable: scopes are fixed at key creation, so create a new key with the required scope instead of retrying); or an AI-preference denial AI_UPDATE_DISABLED / AI_DELETE_DISABLED (requiredPreference). Scopes and AI preferences compose as AND — passing one does not bypass the other. Gate codes only apply when the corresponding env flag is enabled.
- `429` — Rate limit exceeded (code: rate_limit_exceeded). Includes Retry-After and X-RateLimit-* headers.
- `500` — Internal server error (code: internal_error).

### Get a task

```http
GET /tasks/{id}
```

**Skill CLI:** `teamyou.sh ty tasks get <task_id>`

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

### Update a task

```http
PUT /tasks/{id}
```

**Skill CLI:** `teamyou.sh ty tasks update <task_id> [--title <text>] [--description <text>] [--status todo|done] [--priority PRIORITY] [--due-date <ISO8601>] [--archived] [--topic-id <id>] [--no-topic] [--project-id <id>] [--no-project] [--after <task_id>] [--before <task_id>] [--assignee <agent>] [--no-assignee]`

**Parameters:**

- `id` (path, required) — string — Task id

**Request body:**

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| `title` | string | no | A new title. On a task assigned to another agent, 403 assignment_refused (reason escalation), writing nothing, when that agent holds scopes your key does not or has no live key: rewriting its step is an ask too. — len 1..500 |
| `status` | `todo` \| `done` | no |  |
| `priority` | `high` \| `medium` \| `low` \| `none` | no |  |
| `dueDate` | string \| null | no |  |
| `isArchived` | boolean | no |  |
| `topicId` | string \| null | no | len 1..∞ |
| `projectId` | string \| null | no | Assign/move into this project; null removes from its project. — len 1..∞ |
| `position` | PlanPosition | no | Reorder within the project plan; with projectId, positions on assign. |
| `assigneeAgentId` | string \| null | no | An agent id or slug (it gets an assigned item), or null to unassign. 403 assignment_refused (reason escalation), writing nothing, when that agent holds scopes your key does not or has no live key. — len 1..64 |

**Responses:**

- `200` — Updated task.
- `400` — Validation error — invalid body, query, or path param (code: validation_error or invalid_json). `details` carries Zod field errors; PATCH /edges also adds `formErrors`.
- `401` — Missing, malformed, expired, or revoked API key (code: unauthorized).
- `403` — Forbidden. One of: api_key_user_not_found (key belongs to a user absent from this environment); client_identification_required (no recognized X-TeamYou-Client; carries skill_install_url, registerUrl, docs_url; only when TEAMYOU_GATE_REQUIRE_IDENTIFIED_CLIENT); agent_not_registered (registerUrl, skill_install_url, docs_url); skill_update_required (required_version, install_url, docs_url; possibly Deprecation/Sunset headers); client_update_nudge (a soft, relent-able staleness nudge for an agentic client below the latest release when TEAMYOU_GATE_NAG_ENABLED is on; carries verified_version, required_version, upgrade_url, ack_url, ack_token, nag_interval, nag_acks_so_far, docs_url — upgrade to end it, or fetch ack_url to relent one call at a rising cost); insufficient_scope (the API key lacks this operation’s x-teamyou-scope; carries required_scope, granted_scopes, docs_url — NOT retryable: scopes are fixed at key creation, so create a new key with the required scope instead of retrying); or an AI-preference denial AI_UPDATE_DISABLED / AI_DELETE_DISABLED (requiredPreference). Scopes and AI preferences compose as AND — passing one does not bypass the other. Gate codes only apply when the corresponding env flag is enabled.
- `404` — Resource not found (code: not_found).
- `429` — Rate limit exceeded (code: rate_limit_exceeded). Includes Retry-After and X-RateLimit-* headers.
- `500` — Internal server error (code: internal_error).

### Delete a task

```http
DELETE /tasks/{id}
```

**Skill CLI:** `teamyou.sh ty tasks delete <task_id>`

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

### Mark a task done

```http
POST /tasks/{id}/complete
```

**Skill CLI:** `teamyou.sh ty tasks complete <task_id>`

**Parameters:**

- `id` (path, required) — string — Task id

**Responses:**

- `200` — Completed task.
- `401` — Missing, malformed, expired, or revoked API key (code: unauthorized).
- `403` — Forbidden. One of: api_key_user_not_found (key belongs to a user absent from this environment); client_identification_required (no recognized X-TeamYou-Client; carries skill_install_url, registerUrl, docs_url; only when TEAMYOU_GATE_REQUIRE_IDENTIFIED_CLIENT); agent_not_registered (registerUrl, skill_install_url, docs_url); skill_update_required (required_version, install_url, docs_url; possibly Deprecation/Sunset headers); client_update_nudge (a soft, relent-able staleness nudge for an agentic client below the latest release when TEAMYOU_GATE_NAG_ENABLED is on; carries verified_version, required_version, upgrade_url, ack_url, ack_token, nag_interval, nag_acks_so_far, docs_url — upgrade to end it, or fetch ack_url to relent one call at a rising cost); insufficient_scope (the API key lacks this operation’s x-teamyou-scope; carries required_scope, granted_scopes, docs_url — NOT retryable: scopes are fixed at key creation, so create a new key with the required scope instead of retrying); or an AI-preference denial AI_UPDATE_DISABLED / AI_DELETE_DISABLED (requiredPreference). Scopes and AI preferences compose as AND — passing one does not bypass the other. Gate codes only apply when the corresponding env flag is enabled.
- `404` — Resource not found (code: not_found).
- `429` — Rate limit exceeded (code: rate_limit_exceeded). Includes Retry-After and X-RateLimit-* headers.
- `500` — Internal server error (code: internal_error).

### List comments on a task

```http
GET /tasks/{id}/comments
```

**Skill CLI:** `teamyou.sh ty tasks comments <task_id> [--limit N] [--before <comment_id>]`

**Parameters:**

- `id` (path, required) — string — Task id
- `limit` (query) — integer
- `before` (query) — string — Comments older than this id.

**Responses:**

- `200` — The thread, oldest first.
- `400` — Validation error — invalid body, query, or path param (code: validation_error or invalid_json). `details` carries Zod field errors; PATCH /edges also adds `formErrors`.
- `401` — Missing, malformed, expired, or revoked API key (code: unauthorized).
- `403` — Forbidden. One of: api_key_user_not_found (key belongs to a user absent from this environment); client_identification_required (no recognized X-TeamYou-Client; carries skill_install_url, registerUrl, docs_url; only when TEAMYOU_GATE_REQUIRE_IDENTIFIED_CLIENT); agent_not_registered (registerUrl, skill_install_url, docs_url); skill_update_required (required_version, install_url, docs_url; possibly Deprecation/Sunset headers); client_update_nudge (a soft, relent-able staleness nudge for an agentic client below the latest release when TEAMYOU_GATE_NAG_ENABLED is on; carries verified_version, required_version, upgrade_url, ack_url, ack_token, nag_interval, nag_acks_so_far, docs_url — upgrade to end it, or fetch ack_url to relent one call at a rising cost); insufficient_scope (the API key lacks this operation’s x-teamyou-scope; carries required_scope, granted_scopes, docs_url — NOT retryable: scopes are fixed at key creation, so create a new key with the required scope instead of retrying); or an AI-preference denial AI_UPDATE_DISABLED / AI_DELETE_DISABLED (requiredPreference). Scopes and AI preferences compose as AND — passing one does not bypass the other. Gate codes only apply when the corresponding env flag is enabled.
- `404` — Resource not found (code: not_found).
- `429` — Rate limit exceeded (code: rate_limit_exceeded). Includes Retry-After and X-RateLimit-* headers.
- `500` — Internal server error (code: internal_error).

### Comment on a task

```http
POST /tasks/{id}/comments
```

Mention an agent with agent://<id-or-slug>: it gets a mentioned item (wakes it). Other followers get commented on their next check-in. `notified` reports each, including any a guardrail refused.

**Skill CLI:** `teamyou.sh ty tasks comment <task_id> <text> [--reply-to <comment_id>]`

**Parameters:**

- `id` (path, required) — string — Task id

**Request body:**

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| `body` | string | yes | Mention an agent with agent://<id-or-slug>, your person with user://owner. — len 1..4000 |
| `inReplyToCommentId` | string | no | The comment this replies to. — len 1..∞ |

**Responses:**

- `201` — The comment, and who was notified.
- `400` — Validation error — invalid body, query, or path param (code: validation_error or invalid_json). `details` carries Zod field errors; PATCH /edges also adds `formErrors`.
- `401` — Missing, malformed, expired, or revoked API key (code: unauthorized).
- `403` — Forbidden. One of: api_key_user_not_found (key belongs to a user absent from this environment); client_identification_required (no recognized X-TeamYou-Client; carries skill_install_url, registerUrl, docs_url; only when TEAMYOU_GATE_REQUIRE_IDENTIFIED_CLIENT); agent_not_registered (registerUrl, skill_install_url, docs_url); skill_update_required (required_version, install_url, docs_url; possibly Deprecation/Sunset headers); client_update_nudge (a soft, relent-able staleness nudge for an agentic client below the latest release when TEAMYOU_GATE_NAG_ENABLED is on; carries verified_version, required_version, upgrade_url, ack_url, ack_token, nag_interval, nag_acks_so_far, docs_url — upgrade to end it, or fetch ack_url to relent one call at a rising cost); insufficient_scope (the API key lacks this operation’s x-teamyou-scope; carries required_scope, granted_scopes, docs_url — NOT retryable: scopes are fixed at key creation, so create a new key with the required scope instead of retrying); or an AI-preference denial AI_UPDATE_DISABLED / AI_DELETE_DISABLED (requiredPreference). Scopes and AI preferences compose as AND — passing one does not bypass the other. Gate codes only apply when the corresponding env flag is enabled.
- `404` — Resource not found (code: not_found).
- `429` — Rate limit exceeded (code: rate_limit_exceeded). Includes Retry-After and X-RateLimit-* headers.
- `500` — Internal server error (code: internal_error).

### Follow a task's comment thread

```http
PUT /tasks/{id}/following
```

**Skill CLI:** `teamyou.sh ty tasks follow <task_id>`

**Parameters:**

- `id` (path, required) — string — Task id

**Responses:**

- `200` — Following.
- `400` — Validation error — invalid body, query, or path param (code: validation_error or invalid_json). `details` carries Zod field errors; PATCH /edges also adds `formErrors`.
- `401` — Missing, malformed, expired, or revoked API key (code: unauthorized).
- `403` — Forbidden. One of: api_key_user_not_found (key belongs to a user absent from this environment); client_identification_required (no recognized X-TeamYou-Client; carries skill_install_url, registerUrl, docs_url; only when TEAMYOU_GATE_REQUIRE_IDENTIFIED_CLIENT); agent_not_registered (registerUrl, skill_install_url, docs_url); skill_update_required (required_version, install_url, docs_url; possibly Deprecation/Sunset headers); client_update_nudge (a soft, relent-able staleness nudge for an agentic client below the latest release when TEAMYOU_GATE_NAG_ENABLED is on; carries verified_version, required_version, upgrade_url, ack_url, ack_token, nag_interval, nag_acks_so_far, docs_url — upgrade to end it, or fetch ack_url to relent one call at a rising cost); insufficient_scope (the API key lacks this operation’s x-teamyou-scope; carries required_scope, granted_scopes, docs_url — NOT retryable: scopes are fixed at key creation, so create a new key with the required scope instead of retrying); or an AI-preference denial AI_UPDATE_DISABLED / AI_DELETE_DISABLED (requiredPreference). Scopes and AI preferences compose as AND — passing one does not bypass the other. Gate codes only apply when the corresponding env flag is enabled.
- `404` — Resource not found (code: not_found).
- `429` — Rate limit exceeded (code: rate_limit_exceeded). Includes Retry-After and X-RateLimit-* headers.
- `500` — Internal server error (code: internal_error).

### Unfollow a task's comment thread

```http
DELETE /tasks/{id}/following
```

Stops commented items for this thread until you follow again.

**Skill CLI:** `teamyou.sh ty tasks unfollow <task_id>`

**Parameters:**

- `id` (path, required) — string — Task id

**Responses:**

- `200` — Not following.
- `400` — Validation error — invalid body, query, or path param (code: validation_error or invalid_json). `details` carries Zod field errors; PATCH /edges also adds `formErrors`.
- `401` — Missing, malformed, expired, or revoked API key (code: unauthorized).
- `403` — Forbidden. One of: api_key_user_not_found (key belongs to a user absent from this environment); client_identification_required (no recognized X-TeamYou-Client; carries skill_install_url, registerUrl, docs_url; only when TEAMYOU_GATE_REQUIRE_IDENTIFIED_CLIENT); agent_not_registered (registerUrl, skill_install_url, docs_url); skill_update_required (required_version, install_url, docs_url; possibly Deprecation/Sunset headers); client_update_nudge (a soft, relent-able staleness nudge for an agentic client below the latest release when TEAMYOU_GATE_NAG_ENABLED is on; carries verified_version, required_version, upgrade_url, ack_url, ack_token, nag_interval, nag_acks_so_far, docs_url — upgrade to end it, or fetch ack_url to relent one call at a rising cost); insufficient_scope (the API key lacks this operation’s x-teamyou-scope; carries required_scope, granted_scopes, docs_url — NOT retryable: scopes are fixed at key creation, so create a new key with the required scope instead of retrying); or an AI-preference denial AI_UPDATE_DISABLED / AI_DELETE_DISABLED (requiredPreference). Scopes and AI preferences compose as AND — passing one does not bypass the other. Gate codes only apply when the corresponding env flag is enabled.
- `404` — Resource not found (code: not_found).
- `429` — Rate limit exceeded (code: rate_limit_exceeded). Includes Retry-After and X-RateLimit-* headers.
- `500` — Internal server error (code: internal_error).
