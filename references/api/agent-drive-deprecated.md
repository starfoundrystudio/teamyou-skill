<!-- GENERATED FROM openapi.json — DO NOT EDIT. Run `pnpm skill:contract:generate`. -->

# TeamYou API Reference: Agent Drive (deprecated paths)

Base URL `https://www.teamyou.com/api/external/v1`. Every request except `GET /openapi.json` carries
`Authorization: Bearer ty_<key>`. Rate limits: reads 100/min, writes 60/min, search 30/min
(all 1000/hour); every response carries `X-RateLimit-Limit`, `X-RateLimit-Remaining` and
`X-RateLimit-Reset`. The full machine-readable contract is `GET /openapi.json`.

## Contents

- [List documents (deprecated path)](#list-documents-deprecated-path)
- [Write (upsert-by-path) a document (deprecated path)](#write-upsert-by-path-a-document-deprecated-path)
- [Read a document (deprecated path)](#read-a-document-deprecated-path)
- [Delete a document (deprecated path)](#delete-a-document-deprecated-path)
- [Set who can open a document (deprecated path)](#set-who-can-open-a-document-deprecated-path)
- [Share a document with a person (deprecated path)](#share-a-document-with-a-person-deprecated-path)
- [Stop sharing a document with a person (deprecated path)](#stop-sharing-a-document-with-a-person-deprecated-path)
- [Restore a deleted document (deprecated path)](#restore-a-deleted-document-deprecated-path)

### List documents (deprecated path)

```http
GET /drive
```

DEPRECATED PATH — use `GET /agent-drive` instead. Identical behaviour, identical request and response: this is the same handler, reached through an alias route file rather than a redirect, so a request body survives the call. Responses from this path carry `Deprecation: true` and a `Link: <…>; rel="successor-version"` header naming the live path. No removal date is scheduled; those headers are where that will change first.

**Parameters:**

- `scope` (query) — `mine` | `shared` | `all` | `accessed` — Which documents to list. mine (default) = only your own, exactly as this endpoint behaved before scope existed. shared = ONLY documents another user has granted to you, never your own, each carrying a sharedBy object naming its owner. all = both, merged newest-first. accessed = your LIBRARY: cross-user documents you or your agents have opened, whether by link or by grant, each carrying an accessed object naming the document owner, how you got in, and which of your agents last opened it. Shared-in and accessed documents are not yours: you cannot write to their paths, and access ends the moment the owner revokes it. Library entries are re-checked on every request, so one whose access has been revoked is simply absent from the list rather than returned as an id you cannot fetch — which is also why pagination.hasMore, not the length of documents, tells you whether to ask for another page. Note that accessed is NOT searchable yet: POST /search/documents rejects it.
- `archived` (query) — `true` | `false` — Omitted or false lists live documents; true lists only deleted (recoverable) ones. Applies to your own documents; shared-in documents are always live (a document its owner deleted disappears from your list entirely).
- `pathPrefix` (query) — string — Folder to scope to, e.g. "memory/". Canonicalized the same way a written path is; a trailing "/" is optional. Matched case-insensitively. Omit for all of Agent Drive.
- `limit` (query) — integer
- `offset` (query) — integer

**Responses:**

- `200` — Documents (metadata), the child folders of pathPrefix, and the page window.
- `400` — Validation error — invalid body, query, or path param (code: validation_error or invalid_json). `details` carries Zod field errors; PATCH /edges also adds `formErrors`.
- `401` — Missing, malformed, expired, or revoked API key (code: unauthorized).
- `403` — Forbidden. One of: api_key_user_not_found (key belongs to a user absent from this environment); client_identification_required (no recognized X-TeamYou-Client; carries skill_install_url, registerUrl, docs_url; only when TEAMYOU_GATE_REQUIRE_IDENTIFIED_CLIENT); agent_not_registered (registerUrl, skill_install_url, docs_url); skill_update_required (required_version, install_url, docs_url; possibly Deprecation/Sunset headers); client_update_nudge (a soft, relent-able staleness nudge for an agentic client below the latest release when TEAMYOU_GATE_NAG_ENABLED is on; carries verified_version, required_version, upgrade_url, ack_url, ack_token, nag_interval, nag_acks_so_far, docs_url — upgrade to end it, or fetch ack_url to relent one call at a rising cost); insufficient_scope (the API key lacks this operation’s x-teamyou-scope; carries required_scope, granted_scopes, docs_url — NOT retryable: scopes are fixed at key creation, so create a new key with the required scope instead of retrying); or an AI-preference denial AI_UPDATE_DISABLED / AI_DELETE_DISABLED (requiredPreference). Scopes and AI preferences compose as AND — passing one does not bypass the other. Gate codes only apply when the corresponding env flag is enabled.
- `429` — Rate limit exceeded (code: rate_limit_exceeded). Includes Retry-After and X-RateLimit-* headers.
- `500` — Internal server error (code: internal_error).

### Write (upsert-by-path) a document (deprecated path)

```http
POST /drive
```

DEPRECATED PATH — use `POST /agent-drive` instead. Identical behaviour, identical request and response: this is the same handler, reached through an alias route file rather than a redirect, so a request body survives the call. Responses from this path carry `Deprecation: true` and a `Link: <…>; rel="successor-version"` header naming the live path. No removal date is scheduled; those headers are where that will change first.

**Request body:**

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| `title` | string | yes | len 1..255 |
| `path` | string | yes | Relative logical path/key, and the upsert key — re-pushing the same path replaces the document. CANONICALIZED on write, so the stored path may differ from what you send: "\" becomes "/", empty and "." segments are dropped, and Unicode is normalized to NFC. Rejected: absolute paths (leading "/" or a drive letter), ".." segments, control characters, more than 16 segments, a segment over 255 bytes, over 1024 bytes total (measured as UTF-8, not characters), and — for portability to Windows and macOS sync targets — the characters < > : " \| ? * and the reserved device names CON, PRN, AUX, NUL, COM1-9, LPT1-9. Paths are matched CASE-INSENSITIVELY but stored case-preserving: pushing "Notes/x.md" over an existing "notes/x.md" replaces that document and keeps its original casing. The response returns the stored document, so the canonical path is always observable. — len 1..1024 |
| `content` | string | yes | Markdown source (~1 MB ceiling). — len 0..1000000 |

**Responses:**

- `200` — Unchanged — byte-identical to the stored document; nothing was written.
- `201` — Written document + its private reader URL.
- `400` — Validation error — invalid body, query, or path param (code: validation_error or invalid_json). `details` carries Zod field errors; PATCH /edges also adds `formErrors`.
- `401` — Missing, malformed, expired, or revoked API key (code: unauthorized).
- `403` — Forbidden. One of: api_key_user_not_found (key belongs to a user absent from this environment); client_identification_required (no recognized X-TeamYou-Client; carries skill_install_url, registerUrl, docs_url; only when TEAMYOU_GATE_REQUIRE_IDENTIFIED_CLIENT); agent_not_registered (registerUrl, skill_install_url, docs_url); skill_update_required (required_version, install_url, docs_url; possibly Deprecation/Sunset headers); client_update_nudge (a soft, relent-able staleness nudge for an agentic client below the latest release when TEAMYOU_GATE_NAG_ENABLED is on; carries verified_version, required_version, upgrade_url, ack_url, ack_token, nag_interval, nag_acks_so_far, docs_url — upgrade to end it, or fetch ack_url to relent one call at a rising cost); insufficient_scope (the API key lacks this operation’s x-teamyou-scope; carries required_scope, granted_scopes, docs_url — NOT retryable: scopes are fixed at key creation, so create a new key with the required scope instead of retrying); or an AI-preference denial AI_UPDATE_DISABLED / AI_DELETE_DISABLED (requiredPreference). Scopes and AI preferences compose as AND — passing one does not bypass the other. Gate codes only apply when the corresponding env flag is enabled.
- `429` — Rate limit exceeded (code: rate_limit_exceeded). Includes Retry-After and X-RateLimit-* headers.
- `500` — Internal server error (code: internal_error).

### Read a document (deprecated path)

```http
GET /drive/{id}
```

DEPRECATED PATH — use `GET /agent-drive/{id}` instead. Identical behaviour, identical request and response: this is the same handler, reached through an alias route file rather than a redirect, so a request body survives the call. Responses from this path carry `Deprecation: true` and a `Link: <…>; rel="successor-version"` header naming the live path. No removal date is scheduled; those headers are where that will change first.

**Parameters:**

- `id` (path, required) — string — Document id

**Responses:**

- `200` — The document.
- `401` — Missing, malformed, expired, or revoked API key (code: unauthorized).
- `403` — Forbidden. One of: api_key_user_not_found (key belongs to a user absent from this environment); client_identification_required (no recognized X-TeamYou-Client; carries skill_install_url, registerUrl, docs_url; only when TEAMYOU_GATE_REQUIRE_IDENTIFIED_CLIENT); agent_not_registered (registerUrl, skill_install_url, docs_url); skill_update_required (required_version, install_url, docs_url; possibly Deprecation/Sunset headers); client_update_nudge (a soft, relent-able staleness nudge for an agentic client below the latest release when TEAMYOU_GATE_NAG_ENABLED is on; carries verified_version, required_version, upgrade_url, ack_url, ack_token, nag_interval, nag_acks_so_far, docs_url — upgrade to end it, or fetch ack_url to relent one call at a rising cost); insufficient_scope (the API key lacks this operation’s x-teamyou-scope; carries required_scope, granted_scopes, docs_url — NOT retryable: scopes are fixed at key creation, so create a new key with the required scope instead of retrying); or an AI-preference denial AI_UPDATE_DISABLED / AI_DELETE_DISABLED (requiredPreference). Scopes and AI preferences compose as AND — passing one does not bypass the other. Gate codes only apply when the corresponding env flag is enabled.
- `404` — Resource not found (code: not_found).
- `429` — Rate limit exceeded (code: rate_limit_exceeded). Includes Retry-After and X-RateLimit-* headers.
- `500` — Internal server error (code: internal_error).

### Delete a document (deprecated path)

```http
DELETE /drive/{id}
```

DEPRECATED PATH — use `DELETE /agent-drive/{id}` instead. Identical behaviour, identical request and response: this is the same handler, reached through an alias route file rather than a redirect, so a request body survives the call. Responses from this path carry `Deprecation: true` and a `Link: <…>; rel="successor-version"` header naming the live path. No removal date is scheduled; those headers are where that will change first.

**Parameters:**

- `id` (path, required) — string — Document id

**Responses:**

- `200` — Deleted.
- `401` — Missing, malformed, expired, or revoked API key (code: unauthorized).
- `403` — Forbidden. One of: api_key_user_not_found (key belongs to a user absent from this environment); client_identification_required (no recognized X-TeamYou-Client; carries skill_install_url, registerUrl, docs_url; only when TEAMYOU_GATE_REQUIRE_IDENTIFIED_CLIENT); agent_not_registered (registerUrl, skill_install_url, docs_url); skill_update_required (required_version, install_url, docs_url; possibly Deprecation/Sunset headers); client_update_nudge (a soft, relent-able staleness nudge for an agentic client below the latest release when TEAMYOU_GATE_NAG_ENABLED is on; carries verified_version, required_version, upgrade_url, ack_url, ack_token, nag_interval, nag_acks_so_far, docs_url — upgrade to end it, or fetch ack_url to relent one call at a rising cost); insufficient_scope (the API key lacks this operation’s x-teamyou-scope; carries required_scope, granted_scopes, docs_url — NOT retryable: scopes are fixed at key creation, so create a new key with the required scope instead of retrying); or an AI-preference denial AI_UPDATE_DISABLED / AI_DELETE_DISABLED (requiredPreference). Scopes and AI preferences compose as AND — passing one does not bypass the other. Gate codes only apply when the corresponding env flag is enabled.
- `404` — Resource not found (code: not_found).
- `429` — Rate limit exceeded (code: rate_limit_exceeded). Includes Retry-After and X-RateLimit-* headers.
- `500` — Internal server error (code: internal_error).

### Set who can open a document (deprecated path)

```http
PUT /drive/{id}/visibility
```

DEPRECATED PATH — use `PUT /agent-drive/{id}/visibility` instead. Identical behaviour, identical request and response: this is the same handler, reached through an alias route file rather than a redirect, so a request body survives the call. Responses from this path carry `Deprecation: true` and a `Link: <…>; rel="successor-version"` header naming the live path. No removal date is scheduled; those headers are where that will change first.

**Parameters:**

- `id` (path, required) — string — Document id

**Request body:**

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| `visibility` | `private` \| `public` \| `authenticated` | yes | Who can open the document at its /agent-drive/{id} URL. "private" is owner-only and is how you REVOKE; "public" admits anyone with the link, signed in or not; "authenticated" admits any signed-in TeamYou user (signup is open, so this identifies viewers rather than restricting them — it is not an org boundary). Required, with no default: a body that omitted it and defaulted to something would turn a malformed request into an accidental publication. |

**Responses:**

- `200` — The stored visibility and the document’s URLs.
- `400` — Validation error — invalid body, query, or path param (code: validation_error or invalid_json). `details` carries Zod field errors; PATCH /edges also adds `formErrors`.
- `401` — Missing, malformed, expired, or revoked API key (code: unauthorized).
- `403` — Forbidden. One of: api_key_user_not_found (key belongs to a user absent from this environment); client_identification_required (no recognized X-TeamYou-Client; carries skill_install_url, registerUrl, docs_url; only when TEAMYOU_GATE_REQUIRE_IDENTIFIED_CLIENT); agent_not_registered (registerUrl, skill_install_url, docs_url); skill_update_required (required_version, install_url, docs_url; possibly Deprecation/Sunset headers); client_update_nudge (a soft, relent-able staleness nudge for an agentic client below the latest release when TEAMYOU_GATE_NAG_ENABLED is on; carries verified_version, required_version, upgrade_url, ack_url, ack_token, nag_interval, nag_acks_so_far, docs_url — upgrade to end it, or fetch ack_url to relent one call at a rising cost); insufficient_scope (the API key lacks this operation’s x-teamyou-scope; carries required_scope, granted_scopes, docs_url — NOT retryable: scopes are fixed at key creation, so create a new key with the required scope instead of retrying); or an AI-preference denial AI_UPDATE_DISABLED / AI_DELETE_DISABLED (requiredPreference). Scopes and AI preferences compose as AND — passing one does not bypass the other. Gate codes only apply when the corresponding env flag is enabled.
- `404` — Resource not found (code: not_found).
- `429` — Rate limit exceeded (code: rate_limit_exceeded). Includes Retry-After and X-RateLimit-* headers.
- `500` — Internal server error (code: internal_error).

### Share a document with a person (deprecated path)

```http
POST /drive/{id}/grants
```

DEPRECATED PATH — use `POST /agent-drive/{id}/grants` instead. Identical behaviour, identical request and response: this is the same handler, reached through an alias route file rather than a redirect, so a request body survives the call. Responses from this path carry `Deprecation: true` and a `Link: <…>; rel="successor-version"` header naming the live path. No removal date is scheduled; those headers are where that will change first.

**Parameters:**

- `id` (path, required) — string — Document id

**Request body:**

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| `email` | string | yes | The recipient's email address. If it belongs to a TeamYou account they get access immediately; if not, an invite is stored and binds when they sign up with that (verified) address — and this endpoint tells you neither which happened, deliberately, so it can never be used to check whether an address has an account. |

**Responses:**

- `200` — The share landed — with no signal of whether the address has an account.
- `400` — Validation error — invalid body, query, or path param (code: validation_error or invalid_json). `details` carries Zod field errors; PATCH /edges also adds `formErrors`.
- `401` — Missing, malformed, expired, or revoked API key (code: unauthorized).
- `403` — Forbidden. One of: api_key_user_not_found (key belongs to a user absent from this environment); client_identification_required (no recognized X-TeamYou-Client; carries skill_install_url, registerUrl, docs_url; only when TEAMYOU_GATE_REQUIRE_IDENTIFIED_CLIENT); agent_not_registered (registerUrl, skill_install_url, docs_url); skill_update_required (required_version, install_url, docs_url; possibly Deprecation/Sunset headers); client_update_nudge (a soft, relent-able staleness nudge for an agentic client below the latest release when TEAMYOU_GATE_NAG_ENABLED is on; carries verified_version, required_version, upgrade_url, ack_url, ack_token, nag_interval, nag_acks_so_far, docs_url — upgrade to end it, or fetch ack_url to relent one call at a rising cost); insufficient_scope (the API key lacks this operation’s x-teamyou-scope; carries required_scope, granted_scopes, docs_url — NOT retryable: scopes are fixed at key creation, so create a new key with the required scope instead of retrying); or an AI-preference denial AI_UPDATE_DISABLED / AI_DELETE_DISABLED (requiredPreference). Scopes and AI preferences compose as AND — passing one does not bypass the other. Gate codes only apply when the corresponding env flag is enabled.
- `404` — Resource not found (code: not_found).
- `429` — Rate limit exceeded (code: rate_limit_exceeded). Includes Retry-After and X-RateLimit-* headers.
- `500` — Internal server error (code: internal_error).

### Stop sharing a document with a person (deprecated path)

```http
DELETE /drive/{id}/grants
```

DEPRECATED PATH — use `DELETE /agent-drive/{id}/grants` instead. Identical behaviour, identical request and response: this is the same handler, reached through an alias route file rather than a redirect, so a request body survives the call. Responses from this path carry `Deprecation: true` and a `Link: <…>; rel="successor-version"` header naming the live path. No removal date is scheduled; those headers are where that will change first.

**Parameters:**

- `id` (path, required) — string — Document id

**Request body:**

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| `email` | string | yes | The recipient's email address. If it belongs to a TeamYou account they get access immediately; if not, an invite is stored and binds when they sign up with that (verified) address — and this endpoint tells you neither which happened, deliberately, so it can never be used to check whether an address has an account. |

**Responses:**

- `200` — Whether a live grant was removed.
- `400` — Validation error — invalid body, query, or path param (code: validation_error or invalid_json). `details` carries Zod field errors; PATCH /edges also adds `formErrors`.
- `401` — Missing, malformed, expired, or revoked API key (code: unauthorized).
- `403` — Forbidden. One of: api_key_user_not_found (key belongs to a user absent from this environment); client_identification_required (no recognized X-TeamYou-Client; carries skill_install_url, registerUrl, docs_url; only when TEAMYOU_GATE_REQUIRE_IDENTIFIED_CLIENT); agent_not_registered (registerUrl, skill_install_url, docs_url); skill_update_required (required_version, install_url, docs_url; possibly Deprecation/Sunset headers); client_update_nudge (a soft, relent-able staleness nudge for an agentic client below the latest release when TEAMYOU_GATE_NAG_ENABLED is on; carries verified_version, required_version, upgrade_url, ack_url, ack_token, nag_interval, nag_acks_so_far, docs_url — upgrade to end it, or fetch ack_url to relent one call at a rising cost); insufficient_scope (the API key lacks this operation’s x-teamyou-scope; carries required_scope, granted_scopes, docs_url — NOT retryable: scopes are fixed at key creation, so create a new key with the required scope instead of retrying); or an AI-preference denial AI_UPDATE_DISABLED / AI_DELETE_DISABLED (requiredPreference). Scopes and AI preferences compose as AND — passing one does not bypass the other. Gate codes only apply when the corresponding env flag is enabled.
- `404` — Resource not found (code: not_found).
- `429` — Rate limit exceeded (code: rate_limit_exceeded). Includes Retry-After and X-RateLimit-* headers.
- `500` — Internal server error (code: internal_error).

### Restore a deleted document (deprecated path)

```http
POST /drive/{id}/restore
```

DEPRECATED PATH — use `POST /agent-drive/{id}/restore` instead. Identical behaviour, identical request and response: this is the same handler, reached through an alias route file rather than a redirect, so a request body survives the call. Responses from this path carry `Deprecation: true` and a `Link: <…>; rel="successor-version"` header naming the live path. No removal date is scheduled; those headers are where that will change first.

**Parameters:**

- `id` (path, required) — string — Document id

**Responses:**

- `200` — Restored document + its private reader URL.
- `401` — Missing, malformed, expired, or revoked API key (code: unauthorized).
- `403` — Forbidden. One of: api_key_user_not_found (key belongs to a user absent from this environment); client_identification_required (no recognized X-TeamYou-Client; carries skill_install_url, registerUrl, docs_url; only when TEAMYOU_GATE_REQUIRE_IDENTIFIED_CLIENT); agent_not_registered (registerUrl, skill_install_url, docs_url); skill_update_required (required_version, install_url, docs_url; possibly Deprecation/Sunset headers); client_update_nudge (a soft, relent-able staleness nudge for an agentic client below the latest release when TEAMYOU_GATE_NAG_ENABLED is on; carries verified_version, required_version, upgrade_url, ack_url, ack_token, nag_interval, nag_acks_so_far, docs_url — upgrade to end it, or fetch ack_url to relent one call at a rising cost); insufficient_scope (the API key lacks this operation’s x-teamyou-scope; carries required_scope, granted_scopes, docs_url — NOT retryable: scopes are fixed at key creation, so create a new key with the required scope instead of retrying); or an AI-preference denial AI_UPDATE_DISABLED / AI_DELETE_DISABLED (requiredPreference). Scopes and AI preferences compose as AND — passing one does not bypass the other. Gate codes only apply when the corresponding env flag is enabled.
- `404` — Resource not found (code: not_found).
- `429` — Rate limit exceeded (code: rate_limit_exceeded). Includes Retry-After and X-RateLimit-* headers.
- `500` — Internal server error (code: internal_error).
