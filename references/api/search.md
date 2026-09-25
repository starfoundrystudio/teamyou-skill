<!-- GENERATED FROM openapi.json — DO NOT EDIT. Run `pnpm skill:contract:generate`. -->

# TeamYou API Reference: Search

Base URL `https://www.teamyou.com/api/external/v1`. Every request except `GET /openapi.json` carries
`Authorization: Bearer ty_<key>`. Rate limits: reads 100/min, writes 60/min, search 30/min
(all 1000/hour); every response carries `X-RateLimit-Limit`, `X-RateLimit-Remaining` and
`X-RateLimit-Reset`. The full machine-readable contract is `GET /openapi.json`.

## Contents

- [Semantic topic search](#semantic-topic-search)
- [Semantic detail search](#semantic-detail-search)
- [Search across all types](#search-across-all-types)
- [Items one hop from an item](#items-one-hop-from-an-item)

### Semantic topic search

```http
POST /search/topics
```

**Skill CLI:** `teamyou.sh ty graph search-topics <query> [precision]`

**Request body:**

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| `query` | string | yes | len 1..500 |
| `precision` | `high` \| `medium` \| `low` | no | default `medium` |

**Responses:**

- `200` — Ranked topic results (may include one-hop graph neighbors).
- `400` — Validation error — invalid body, query, or path param (code: validation_error or invalid_json). `details` carries Zod field errors; PATCH /edges also adds `formErrors`.
- `401` — Missing, malformed, expired, or revoked API key (code: unauthorized).
- `403` — Forbidden. One of: api_key_user_not_found (key belongs to a user absent from this environment); client_identification_required (no recognized X-TeamYou-Client; carries skill_install_url, registerUrl, docs_url; only when TEAMYOU_GATE_REQUIRE_IDENTIFIED_CLIENT); agent_not_registered (registerUrl, skill_install_url, docs_url); skill_update_required (required_version, install_url, docs_url; possibly Deprecation/Sunset headers); client_update_nudge (a soft, relent-able staleness nudge for an agentic client below the latest release when TEAMYOU_GATE_NAG_ENABLED is on; carries verified_version, required_version, upgrade_url, ack_url, ack_token, nag_interval, nag_acks_so_far, docs_url — upgrade to end it, or fetch ack_url to relent one call at a rising cost); insufficient_scope (the API key lacks this operation’s x-teamyou-scope; carries required_scope, granted_scopes, docs_url — NOT retryable: scopes are fixed at key creation, so create a new key with the required scope instead of retrying); or an AI-preference denial AI_UPDATE_DISABLED / AI_DELETE_DISABLED (requiredPreference). Scopes and AI preferences compose as AND — passing one does not bypass the other. Gate codes only apply when the corresponding env flag is enabled.
- `429` — Rate limit exceeded (code: rate_limit_exceeded). Includes Retry-After and X-RateLimit-* headers.
- `500` — Internal server error (code: internal_error).

### Semantic detail search

```http
POST /search/details
```

**Skill CLI:** `teamyou.sh ty graph search-details <query> [precision]`

**Request body:**

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| `query` | string | yes | len 1..500 |
| `precision` | `high` \| `medium` \| `low` | no | default `medium` |

**Responses:**

- `200` — Ranked detail results.
- `400` — Validation error — invalid body, query, or path param (code: validation_error or invalid_json). `details` carries Zod field errors; PATCH /edges also adds `formErrors`.
- `401` — Missing, malformed, expired, or revoked API key (code: unauthorized).
- `403` — Forbidden. One of: api_key_user_not_found (key belongs to a user absent from this environment); client_identification_required (no recognized X-TeamYou-Client; carries skill_install_url, registerUrl, docs_url; only when TEAMYOU_GATE_REQUIRE_IDENTIFIED_CLIENT); agent_not_registered (registerUrl, skill_install_url, docs_url); skill_update_required (required_version, install_url, docs_url; possibly Deprecation/Sunset headers); client_update_nudge (a soft, relent-able staleness nudge for an agentic client below the latest release when TEAMYOU_GATE_NAG_ENABLED is on; carries verified_version, required_version, upgrade_url, ack_url, ack_token, nag_interval, nag_acks_so_far, docs_url — upgrade to end it, or fetch ack_url to relent one call at a rising cost); insufficient_scope (the API key lacks this operation’s x-teamyou-scope; carries required_scope, granted_scopes, docs_url — NOT retryable: scopes are fixed at key creation, so create a new key with the required scope instead of retrying); or an AI-preference denial AI_UPDATE_DISABLED / AI_DELETE_DISABLED (requiredPreference). Scopes and AI preferences compose as AND — passing one does not bypass the other. Gate codes only apply when the corresponding env flag is enabled.
- `429` — Rate limit exceeded (code: rate_limit_exceeded). Includes Retry-After and X-RateLimit-* headers.
- `500` — Internal server error (code: internal_error).

### Search across all types

```http
POST /search/all
```

Use this before acting on a vague question about what the user already has: one ranked list across topics, details, tasks, projects, areas and Agent Drive documents.

Each type is searched by meaning (vector), words (full-text) and spelling (trigram). The matches of each arm are pooled across types and fused ONCE by weighted RRF with a small recency boost, so a hit that matched on several arms outranks a single-arm hit of any type. Projects and areas have no vector arm. `score` is comparable within one response only; `methods` names the arms that matched.

Each result carries its `type`, an absolute `url` and `structure` - where it sits: a detail's topic, a task's project and topic, a project's areas, a document's projects. Follow `structure` to the neighbours of a hit rather than searching again.

`counts` is the number of candidates per type BEFORE the cut to `limit`. One store failing does not fail the request: the failed type is named in `warnings` (`store_unavailable`) and is absent from `counts` and `results`. Nor does an unavailable query embedding: every type is then searched by words and spelling only, with an `embedding_unavailable` warning.

`types` narrows the search; omit it for every type. `scope` (mine | shared | all) applies to documents only. An empty `query` is allowed only with `orderBy: recency`, and then lists the most recently updated items with `score` null and `methods` empty; an empty query with `relevance` is a 400. With a non-empty query, `orderBy: recency` selects candidates by relevance and returns them newest first. The per-type endpoints (`/search/topics`, `/search/details`, `/search/documents`) remain for type-specific fields and filters such as `pathPrefix` and `where`.

**Skill CLI:** `teamyou.sh ty search search <query> [--types t1,t2] [--scope mine|shared|all] [--precision high|medium|low] [--order-by relevance|recency] [--limit N]`

**Request body:**

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| `query` | string | no | What to look for. Empty only with orderBy recency. — len 0..500, default `` |
| `types` | `topic` \| `detail` \| `task` \| `project` \| `area` \| `document`[] | no | Only these types. Omit for all. |
| `scope` | `mine` \| `shared` \| `all` | no | Documents only: yours, shared with you, or both. — default `mine` |
| `precision` | `high` \| `medium` \| `low` | no | default `medium` |
| `orderBy` | `relevance` \| `recency` | no | default `relevance` |
| `limit` | integer | no | 1..50, default `20` |

**Responses:**

- `200` — One ranked, typed list.
- `400` — Validation error — invalid body, query, or path param (code: validation_error or invalid_json). `details` carries Zod field errors; PATCH /edges also adds `formErrors`.
- `401` — Missing, malformed, expired, or revoked API key (code: unauthorized).
- `403` — Forbidden. One of: api_key_user_not_found (key belongs to a user absent from this environment); client_identification_required (no recognized X-TeamYou-Client; carries skill_install_url, registerUrl, docs_url; only when TEAMYOU_GATE_REQUIRE_IDENTIFIED_CLIENT); agent_not_registered (registerUrl, skill_install_url, docs_url); skill_update_required (required_version, install_url, docs_url; possibly Deprecation/Sunset headers); client_update_nudge (a soft, relent-able staleness nudge for an agentic client below the latest release when TEAMYOU_GATE_NAG_ENABLED is on; carries verified_version, required_version, upgrade_url, ack_url, ack_token, nag_interval, nag_acks_so_far, docs_url — upgrade to end it, or fetch ack_url to relent one call at a rising cost); insufficient_scope (the API key lacks this operation’s x-teamyou-scope; carries required_scope, granted_scopes, docs_url — NOT retryable: scopes are fixed at key creation, so create a new key with the required scope instead of retrying); or an AI-preference denial AI_UPDATE_DISABLED / AI_DELETE_DISABLED (requiredPreference). Scopes and AI preferences compose as AND — passing one does not bypass the other. Gate codes only apply when the corresponding env flag is enabled.
- `429` — Rate limit exceeded (code: rate_limit_exceeded). Includes Retry-After and X-RateLimit-* headers.
- `500` — Internal server error (code: internal_error).

### Items one hop from an item

```http
POST /search/related
```

Use this to see what one item is connected to, instead of searching again: the items one hop away, each with its relation.

topic: its edge-linked topics (with the edge `label`) and its details. detail: its topic. task: its project and topic. project: the areas holding it, its tasks, and the documents and topics it references. area: its projects. document: the caller's projects that reference it. Parents and peers come before children, so a long child list cannot crowd them out. Archived tasks, projects and areas are left out, except a task's own project.

Each result has the `search/all` hit shape without `score` and `methods`, plus `relation`, read as "<this item> <relation> <anchor>". A document is admitted only when the caller owns it or holds a live grant on it.

An id that does not exist, belongs to someone else, or names a document the caller cannot open is the same 404 whatever the cause.

**Skill CLI:** `teamyou.sh ty search related <type> <id> [--limit N]`

**Request body:**

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| `type` | `topic` \| `detail` \| `task` \| `project` \| `area` \| `document` | yes |  |
| `id` | string | yes | len 1..200 |
| `limit` | integer | no | 1..50, default `20` |

**Responses:**

- `200` — The neighbours, one hop away.
- `400` — Validation error — invalid body, query, or path param (code: validation_error or invalid_json). `details` carries Zod field errors; PATCH /edges also adds `formErrors`.
- `401` — Missing, malformed, expired, or revoked API key (code: unauthorized).
- `403` — Forbidden. One of: api_key_user_not_found (key belongs to a user absent from this environment); client_identification_required (no recognized X-TeamYou-Client; carries skill_install_url, registerUrl, docs_url; only when TEAMYOU_GATE_REQUIRE_IDENTIFIED_CLIENT); agent_not_registered (registerUrl, skill_install_url, docs_url); skill_update_required (required_version, install_url, docs_url; possibly Deprecation/Sunset headers); client_update_nudge (a soft, relent-able staleness nudge for an agentic client below the latest release when TEAMYOU_GATE_NAG_ENABLED is on; carries verified_version, required_version, upgrade_url, ack_url, ack_token, nag_interval, nag_acks_so_far, docs_url — upgrade to end it, or fetch ack_url to relent one call at a rising cost); insufficient_scope (the API key lacks this operation’s x-teamyou-scope; carries required_scope, granted_scopes, docs_url — NOT retryable: scopes are fixed at key creation, so create a new key with the required scope instead of retrying); or an AI-preference denial AI_UPDATE_DISABLED / AI_DELETE_DISABLED (requiredPreference). Scopes and AI preferences compose as AND — passing one does not bypass the other. Gate codes only apply when the corresponding env flag is enabled.
- `404` — Resource not found (code: not_found).
- `429` — Rate limit exceeded (code: rate_limit_exceeded). Includes Retry-After and X-RateLimit-* headers.
- `500` — Internal server error (code: internal_error).
