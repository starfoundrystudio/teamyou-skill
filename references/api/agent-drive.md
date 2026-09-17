<!-- GENERATED FROM openapi.json — DO NOT EDIT. Run `pnpm skill:contract:generate`. -->

# TeamYou API Reference: Agent Drive

Base URL `https://www.teamyou.com/api/external/v1`. Every request except `GET /openapi.json` carries
`Authorization: Bearer ty_<key>`. Rate limits: reads 100/min, writes 60/min, search 30/min
(all 1000/hour); every response carries `X-RateLimit-Limit`, `X-RateLimit-Remaining` and
`X-RateLimit-Reset`. The full machine-readable contract is `GET /openapi.json`.

## Contents

- [List documents](#list-documents)
- [Write (upsert-by-path) a document](#write-upsert-by-path-a-document)
- [Read a document](#read-a-document)
- [Delete a document](#delete-a-document)
- [Set who can open a document](#set-who-can-open-a-document)
- [Share a document with a person](#share-a-document-with-a-person)
- [Stop sharing a document with a person](#stop-sharing-a-document-with-a-person)
- [Restore a deleted document](#restore-a-deleted-document)
- [Search documents](#search-documents)

### List documents

```http
GET /agent-drive
```

Markdown documents (metadata only — no content), most-recently-updated first. By default lists only what the authenticated user OWNS; pass scope=shared to list only documents other people have shared with them, scope=all for both, or scope=accessed for the access-derived library — cross-user documents you or your agents have actually opened. Deleted (archived) documents are excluded by default; pass archived=true to list ONLY those. There is no way to list both at once. Optionally scoped to a folder with pathPrefix, which returns every document beneath that prefix plus the prefix’s immediate child folders. Folders are derived from path segments — there is no folders resource to create or rename, and the archived switch scopes them too, so a folder holding only deleted documents does not appear in the live tree. Folders and pathPrefix apply to your OWN documents only: paths are unique per owner, so shared-in documents have no place in your folder tree and any scope that includes them returns an empty folders array. Paged: the default limit is 100 (max 200), and `pagination.hasMore` tells you when to ask for the next offset.

**Skill CLI:** `teamyou.sh ty agent-drive list [--scope mine|shared|all|accessed] [--prefix <path>] [--archived] [--limit N] [--offset N]`

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

### Write (upsert-by-path) a document

```http
POST /agent-drive
```

Create or replace a markdown document keyed on its path. Re-posting the same path replaces the whole document. The path is canonicalized and matched case-insensitively (see the path field), so the stored path may differ from what you send — read it back off the returned document, and note that a push differing only in casing counts as replacing, not creating. Owner is the API-key user; the calling agent becomes createdByAgentId on the first write and lastModifiedByAgentId on every later one. Returns documentUrl, the document's canonical /agent-drive/{id} URL — its only URL, and its share URL once the owner makes it visible (url is a deprecated alias for the same value). Documents are private by default and this endpoint cannot change that. Writing a new path is ungated; replacing an existing one is an AI update and returns 403 AI_UPDATE_DISABLED when the owner has aiUpdateEnabled off — including a byte-identical re-push, so a denial cannot be used to probe stored content. Posting to a deleted path resurrects that document (same id, original creator preserved) and resets its visibility to private — reviving a document never re-shares it. contentType is not accepted here: sending it is ignored, not rejected. Status: 201 when the document was created OR its content/title changed; 200 with unchanged=true when the post was byte-identical to what is stored, in which case nothing is written and updatedAt keeps its stored value so a re-push does not reorder the list. If the owner has set a folder visibility rule covering the path ("documents created under reports/ start public"), a NEWLY CREATED document is stamped with it and the response carries folderRule saying what happened — but only if this key also holds the share scope; without that scope the document is created private and folderRule.applied is false. Replacing a document never applies a rule.

**Skill CLI:** `teamyou.sh ty agent-drive push <file> [--path <path>] [--title <text>]`

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

### Read a document

```http
GET /agent-drive/{id}
```

Full document including content, from whichever of three sources applies — and the access field says which. Reads (1) your own documents, (2) any document another TeamYou user shared with YOU by name, since a grant admits the person and your agents read as you, and (3) any PUBLIC document whose id you already have, exactly as an anonymous fetch of /agent-drive/{id}/raw would. A shared-in document comes back with access 'grant' and a sharedBy object naming its owner; treat it as theirs, not yours, and do not write to its path. A public document comes back with access 'public' and NO sharedBy — it was published to nobody in particular, so its owner is not identified. Reading a public id is not discovery: GET /agent-drive and the search scopes remain owner-and-grant scoped, so you can read a public document someone hands you but cannot find one you were not given. Find shared-in documents with GET /agent-drive?scope=shared or POST /search/documents with scope shared; a plain GET /agent-drive still lists only what you own, so syncing Agent Drive never sweeps up somebody else's files unless you ask it to. Grant access lasts exactly as long as the grant, and public access exactly as long as the document stays public — either can be taken back at any moment, and the next read 404s. 404 if the id is missing, not owned, not shared with you, and not public: all four are indistinguishable, so this is never a way to learn that someone else's document exists.

**Skill CLI:** `teamyou.sh ty agent-drive pull <id> [--out <file>]`

**Parameters:**

- `id` (path, required) — string — Document id

**Responses:**

- `200` — The document.
- `401` — Missing, malformed, expired, or revoked API key (code: unauthorized).
- `403` — Forbidden. One of: api_key_user_not_found (key belongs to a user absent from this environment); client_identification_required (no recognized X-TeamYou-Client; carries skill_install_url, registerUrl, docs_url; only when TEAMYOU_GATE_REQUIRE_IDENTIFIED_CLIENT); agent_not_registered (registerUrl, skill_install_url, docs_url); skill_update_required (required_version, install_url, docs_url; possibly Deprecation/Sunset headers); client_update_nudge (a soft, relent-able staleness nudge for an agentic client below the latest release when TEAMYOU_GATE_NAG_ENABLED is on; carries verified_version, required_version, upgrade_url, ack_url, ack_token, nag_interval, nag_acks_so_far, docs_url — upgrade to end it, or fetch ack_url to relent one call at a rising cost); insufficient_scope (the API key lacks this operation’s x-teamyou-scope; carries required_scope, granted_scopes, docs_url — NOT retryable: scopes are fixed at key creation, so create a new key with the required scope instead of retrying); or an AI-preference denial AI_UPDATE_DISABLED / AI_DELETE_DISABLED (requiredPreference). Scopes and AI preferences compose as AND — passing one does not bypass the other. Gate codes only apply when the corresponding env flag is enabled.
- `404` — Resource not found (code: not_found).
- `429` — Rate limit exceeded (code: rate_limit_exceeded). Includes Retry-After and X-RateLimit-* headers.
- `500` — Internal server error (code: internal_error).

### Delete a document

```http
DELETE /agent-drive/{id}
```

Delete a document. The content is archived rather than destroyed and stays recoverable indefinitely: list tombstones with GET /agent-drive?archived=true and bring one back with POST /agent-drive/{id}/restore. A deleted document is otherwise indistinguishable from one that never existed — GET /agent-drive/{id} returns 404 and so does a second DELETE of the same id. Returns 403 AI_DELETE_DISABLED when the owner has aiDeleteEnabled off; the gate runs before the lookup, so a denial never reveals whether the id exists.

**Skill CLI:** `teamyou.sh ty agent-drive delete <id>`

**Parameters:**

- `id` (path, required) — string — Document id

**Responses:**

- `200` — Deleted.
- `401` — Missing, malformed, expired, or revoked API key (code: unauthorized).
- `403` — Forbidden. One of: api_key_user_not_found (key belongs to a user absent from this environment); client_identification_required (no recognized X-TeamYou-Client; carries skill_install_url, registerUrl, docs_url; only when TEAMYOU_GATE_REQUIRE_IDENTIFIED_CLIENT); agent_not_registered (registerUrl, skill_install_url, docs_url); skill_update_required (required_version, install_url, docs_url; possibly Deprecation/Sunset headers); client_update_nudge (a soft, relent-able staleness nudge for an agentic client below the latest release when TEAMYOU_GATE_NAG_ENABLED is on; carries verified_version, required_version, upgrade_url, ack_url, ack_token, nag_interval, nag_acks_so_far, docs_url — upgrade to end it, or fetch ack_url to relent one call at a rising cost); insufficient_scope (the API key lacks this operation’s x-teamyou-scope; carries required_scope, granted_scopes, docs_url — NOT retryable: scopes are fixed at key creation, so create a new key with the required scope instead of retrying); or an AI-preference denial AI_UPDATE_DISABLED / AI_DELETE_DISABLED (requiredPreference). Scopes and AI preferences compose as AND — passing one does not bypass the other. Gate codes only apply when the corresponding env flag is enabled.
- `404` — Resource not found (code: not_found).
- `429` — Rate limit exceeded (code: rate_limit_exceeded). Includes Retry-After and X-RateLimit-* headers.
- `500` — Internal server error (code: internal_error).

### Set who can open a document

```http
PUT /agent-drive/{id}/visibility
```

Set a document's visibility: "private" (only the owner), "public" (anyone with the link, no sign-in), or "authenticated" (any signed-in TeamYou user). Setting "private" IS the revoke — there is no separate unshare endpoint, because there is no token to destroy. /agent-drive/{id} is the document's only URL and also its share URL, so sharing changes what that address does rather than producing a second one; turning sharing off and on again re-enables THE SAME URL for anyone who kept it, exactly as Google Docs does. Requires the share scope, which is never granted by default: the owner ticks it per key in Settings, so a key that can write documents cannot publish them unless someone said so. Every change is recorded with the acting agent and shown to the owner in the web share dialog, and the owner can override any setting an agent made. 404 when the id is missing, not owned, or DELETED — an archived document cannot be pre-set to public and then restored into exposure. Gated by aiUpdateEnabled (403 AI_UPDATE_DISABLED); the gate runs before the lookup, so a denial never reveals whether the id exists. Returns the stored visibility plus both URLs: documentUrl for a person, rawUrl for handing the markdown straight to another agent.

**Skill CLI:** `teamyou.sh ty agent-drive share <path-or-id> [--audience public|authenticated]`

**Also:** `teamyou.sh ty agent-drive unshare <path-or-id>` — sets visibility back to private

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

### Share a document with a person

```http
POST /agent-drive/{id}/grants
```

Share a document with ONE person by email — the third kind of share, beside public and signed-in visibility. If the address belongs to a TeamYou account they can open the document immediately; if not, an invite is stored and binds automatically when they sign up with that (verified) address. Either way the response is the same {shared:true}: this endpoint deliberately never tells you whether the address has an account, so it cannot be used to probe who has one. The person, and their agents reading as them, can then open /agent-drive/{id} — a narrower share than making it public. Requires the share scope, the same one PUT /agent-drive/{id}/visibility needs and never granted by default: the owner ticks it per key in Settings. The grant is recorded with the acting agent and shown to the owner in the web share dialog, and the owner can revoke it there at any time. Revoke via DELETE on this same path. 404 when the id is missing, not owned, or DELETED. 400 when the email is malformed or resolves to your own account (you already own it). Gated by aiUpdateEnabled (403 AI_UPDATE_DISABLED); the gate runs before the lookup, so a denial never reveals whether the id exists.

**Skill CLI:** `teamyou.sh ty agent-drive grant <path-or-id> --email <address>`

**Also:** `teamyou.sh ty agent-drive ungrant <path-or-id> --email <address>` — removes that person’s access

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

### Stop sharing a document with a person

```http
DELETE /agent-drive/{id}/grants
```

Remove one person's access, by the same email you granted it with — the undo for POST on this path. Their access ends on the next request; there is nothing cached and nothing to expire. revoked:true means a live grant was removed, revoked:false means the document is yours but nobody was shared on that address (a second ungrant is a no-op, not an error, so retrying is safe). Requires the share scope. 404 when the id is missing, not owned, or DELETED — the same uniform answer every Agent Drive route gives, so this is never a way to learn a document exists. Gated by aiUpdateEnabled (403 AI_UPDATE_DISABLED) before the lookup.

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

### Restore a deleted document

```http
POST /agent-drive/{id}/restore
```

Bring a deleted (archived) document back into Agent Drive, content byte-identical and with its original creator intact. Visibility is reset to private: deleting is how an owner pulls a document off the internet, so restoring never re-shares it at the same URL. Find the id with GET /agent-drive?archived=true. 404 when the id is missing, not owned, or NOT deleted — restoring an already-live document is not a silent success. This mutates an existing document, so it is gated by aiUpdateEnabled (403 AI_UPDATE_DISABLED), not aiDeleteEnabled.

**Skill CLI:** `teamyou.sh ty agent-drive restore <id>`

**Parameters:**

- `id` (path, required) — string — Document id

**Responses:**

- `200` — Restored document + its private reader URL.
- `401` — Missing, malformed, expired, or revoked API key (code: unauthorized).
- `403` — Forbidden. One of: api_key_user_not_found (key belongs to a user absent from this environment); client_identification_required (no recognized X-TeamYou-Client; carries skill_install_url, registerUrl, docs_url; only when TEAMYOU_GATE_REQUIRE_IDENTIFIED_CLIENT); agent_not_registered (registerUrl, skill_install_url, docs_url); skill_update_required (required_version, install_url, docs_url; possibly Deprecation/Sunset headers); client_update_nudge (a soft, relent-able staleness nudge for an agentic client below the latest release when TEAMYOU_GATE_NAG_ENABLED is on; carries verified_version, required_version, upgrade_url, ack_url, ack_token, nag_interval, nag_acks_so_far, docs_url — upgrade to end it, or fetch ack_url to relent one call at a rising cost); insufficient_scope (the API key lacks this operation’s x-teamyou-scope; carries required_scope, granted_scopes, docs_url — NOT retryable: scopes are fixed at key creation, so create a new key with the required scope instead of retrying); or an AI-preference denial AI_UPDATE_DISABLED / AI_DELETE_DISABLED (requiredPreference). Scopes and AI preferences compose as AND — passing one does not bypass the other. Gate codes only apply when the corresponding env flag is enabled.
- `404` — Resource not found (code: not_found).
- `429` — Rate limit exceeded (code: rate_limit_exceeded). Includes Retry-After and X-RateLimit-* headers.
- `500` — Internal server error (code: internal_error).

### Search documents

```http
POST /search/documents
```

Hybrid search over Agent Drive: semantic (vector) + full-text + trigram, fused by weighted RRF with a recency boost, returning one result per document. Search runs over CHUNKS, so content anywhere in a document is findable — not just its opening — and each result names the chunk that matched via snippet/headingPath/chunkIndex. A chunkIndex of 0 means the title or path matched rather than the body. By default searches only your own documents; scope=shared searches ONLY documents other people have shared with you, and scope=all searches both and fuses them into one ranked list. Newly written documents are indexed in the background, so a document pushed a moment ago may take a few seconds to become searchable. Deleted (archived) documents are never returned. `score` is a fused relevance score, NOT a cosine similarity: compare it within one response and never across two.

**Skill CLI:** `teamyou.sh ty agent-drive search <query> [precision] [--scope mine|shared|all] [--path-prefix <prefix>] [--limit N]`

**Request body:**

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| `query` | string | yes | len 1..500 |
| `precision` | `high` \| `medium` \| `low` | no | default `medium` |
| `pathPrefix` | string | no | Scope the search to a folder, e.g. "memory/". Canonicalized exactly the way a written path is and matched case-insensitively, so the prefix you send does not have to be the stored form. A trailing "/" is optional and "memory" cannot match a sibling document named "memory-archive.md". Omit to search all of Agent Drive. |
| `limit` | integer | no | Maximum documents to return. Defaults to the precision level’s own cap (high 15, medium 20, low 25); a larger value also widens how many candidates are retrieved. — 1..50 |
| `scope` | `mine` \| `shared` \| `all` | no | Which documents to search. mine (default) = only your own, exactly as this endpoint behaved before scope existed. shared = ONLY documents other people have granted to you — use this to answer "what did someone share with me about X" without wading through your own Agent Drive documents. all = both, fused into one ranked list. Shared-in hits come back with source "drive-shared" and a sharedBy object. Access is checked on every request, so a revoked document is gone from the very next search. — default `mine` |

**Responses:**

- `200` — Ranked document results.
- `400` — Validation error — invalid body, query, or path param (code: validation_error or invalid_json). `details` carries Zod field errors; PATCH /edges also adds `formErrors`.
- `401` — Missing, malformed, expired, or revoked API key (code: unauthorized).
- `403` — Forbidden. One of: api_key_user_not_found (key belongs to a user absent from this environment); client_identification_required (no recognized X-TeamYou-Client; carries skill_install_url, registerUrl, docs_url; only when TEAMYOU_GATE_REQUIRE_IDENTIFIED_CLIENT); agent_not_registered (registerUrl, skill_install_url, docs_url); skill_update_required (required_version, install_url, docs_url; possibly Deprecation/Sunset headers); client_update_nudge (a soft, relent-able staleness nudge for an agentic client below the latest release when TEAMYOU_GATE_NAG_ENABLED is on; carries verified_version, required_version, upgrade_url, ack_url, ack_token, nag_interval, nag_acks_so_far, docs_url — upgrade to end it, or fetch ack_url to relent one call at a rising cost); insufficient_scope (the API key lacks this operation’s x-teamyou-scope; carries required_scope, granted_scopes, docs_url — NOT retryable: scopes are fixed at key creation, so create a new key with the required scope instead of retrying); or an AI-preference denial AI_UPDATE_DISABLED / AI_DELETE_DISABLED (requiredPreference). Scopes and AI preferences compose as AND — passing one does not bypass the other. Gate codes only apply when the corresponding env flag is enabled.
- `429` — Rate limit exceeded (code: rate_limit_exceeded). Includes Retry-After and X-RateLimit-* headers.
- `500` — Internal server error (code: internal_error).
