<!-- GENERATED FROM openapi.json — DO NOT EDIT. Run `pnpm skill:contract:generate`. -->

# TeamYou API Reference: Preferences

Base URL `https://www.teamyou.com/api/external/v1`. Every request except `GET /openapi.json` carries
`Authorization: Bearer ty_<key>`. Rate limits: reads 100/min, writes 120/min, search 30/min
(all 2000/hour); every response carries `X-RateLimit-Limit`, `X-RateLimit-Remaining` and
`X-RateLimit-Reset`. The full machine-readable contract is `GET /openapi.json`.

### Get effective user preferences

```http
GET /preferences
```

**Responses:**

- `200` — Effective preferences for the API key user.
- `401` — Missing, malformed, expired, or revoked API key (code: unauthorized). A revoked key whose agent has been retired answers 403 agent_retired instead.
- `403` — Forbidden. One of: api_key_user_not_found (key belongs to a user absent from this environment); client_identification_required (no recognized X-TeamYou-Client; carries skill_install_url, registerUrl, docs_url; only when TEAMYOU_GATE_REQUIRE_IDENTIFIED_CLIENT); agent_not_registered (registerUrl, skill_install_url, docs_url); skill_update_required (required_version, install_url, docs_url; possibly Deprecation/Sunset headers); client_update_nudge (a soft, relent-able staleness nudge for an agentic client below the latest release when TEAMYOU_GATE_NAG_ENABLED is on; carries verified_version, required_version, upgrade_url, ack_url, ack_token, nag_interval, nag_acks_so_far, docs_url — upgrade to end it, or fetch ack_url to relent one call at a rising cost); insufficient_scope (the API key lacks this operation’s x-teamyou-scope; carries required_scope, granted_scopes, docs_url — NOT retryable: scopes are fixed at key creation, so create a new key with the required scope instead of retrying); agent_retired (this key was revoked and its agent has been retired; carries agent {id, slug}, retiredAt, harness and remove {schedule, keyFile} — switch to a new key for this account if you were given one, otherwise stop checking in to this account; NOT retryable with this key); or an AI-preference denial AI_UPDATE_DISABLED / AI_DELETE_DISABLED / AI_SHARE_DISABLED (an account-wide block in Settings > Agent permissions is on; carries requiredPreference, blockedPreferences (every preference in the way; a sharing call can be blocked by two), fix (one line to relay to your person as-is: which switch or switches to turn off, and where) and settingsUrl (the link to those switches) - NOT retryable until the person turns the block off). Scopes and AI preferences compose as AND — passing one does not bypass the other. Gate codes only apply when the corresponding env flag is enabled.
- `429` — Rate limit exceeded (code: rate_limit_exceeded). Includes Retry-After and X-RateLimit-* headers.
- `500` — Internal server error (code: internal_error).
- `503` — The limit check itself failed, so the request was not run (code: rate_limit_unavailable). The caller did not go over a limit. Includes Retry-After.

### Get what your person lets agents save

```http
GET /preferences/never-save
```

What your person lets their agents save to TeamYou, per category: never, ask_first (ask them before saving it) or ok. Passwords, keys and tokens, ID numbers and payment card numbers are never saved, whatever the settings say.

Read it at the start of a task (`ty brief` prints `line`) and follow it in everything you save, here and in your own memory. The settings name categories, never things.

**Skill CLI:** `teamyou.sh ty never-save list`

**Responses:**

- `200` — Every category and its setting.
- `401` — Missing, malformed, expired, or revoked API key (code: unauthorized). A revoked key whose agent has been retired answers 403 agent_retired instead.
- `403` — Forbidden. One of: api_key_user_not_found (key belongs to a user absent from this environment); client_identification_required (no recognized X-TeamYou-Client; carries skill_install_url, registerUrl, docs_url; only when TEAMYOU_GATE_REQUIRE_IDENTIFIED_CLIENT); agent_not_registered (registerUrl, skill_install_url, docs_url); skill_update_required (required_version, install_url, docs_url; possibly Deprecation/Sunset headers); client_update_nudge (a soft, relent-able staleness nudge for an agentic client below the latest release when TEAMYOU_GATE_NAG_ENABLED is on; carries verified_version, required_version, upgrade_url, ack_url, ack_token, nag_interval, nag_acks_so_far, docs_url — upgrade to end it, or fetch ack_url to relent one call at a rising cost); insufficient_scope (the API key lacks this operation’s x-teamyou-scope; carries required_scope, granted_scopes, docs_url — NOT retryable: scopes are fixed at key creation, so create a new key with the required scope instead of retrying); agent_retired (this key was revoked and its agent has been retired; carries agent {id, slug}, retiredAt, harness and remove {schedule, keyFile} — switch to a new key for this account if you were given one, otherwise stop checking in to this account; NOT retryable with this key); or an AI-preference denial AI_UPDATE_DISABLED / AI_DELETE_DISABLED / AI_SHARE_DISABLED (an account-wide block in Settings > Agent permissions is on; carries requiredPreference, blockedPreferences (every preference in the way; a sharing call can be blocked by two), fix (one line to relay to your person as-is: which switch or switches to turn off, and where) and settingsUrl (the link to those switches) - NOT retryable until the person turns the block off). Scopes and AI preferences compose as AND — passing one does not bypass the other. Gate codes only apply when the corresponding env flag is enabled.
- `429` — Rate limit exceeded (code: rate_limit_exceeded). Includes Retry-After and X-RateLimit-* headers.
- `500` — Internal server error (code: internal_error).
- `503` — The limit check itself failed, so the request was not run (code: rate_limit_unavailable). The caller did not go over a limit. Includes Retry-After.

### Make a never-save category stricter

```http
PUT /preferences/never-save/{category}
```

When your person tells you never to keep something, or to ask first, set its category: say which category in one line ("I have set health to never"), and never repeat their words, here or anywhere.

You can only make a category stricter (ok, then ask_first, then never). A looser setting is refused with 403 never_save_loosen_refused and a settingsUrl: only your person loosens a category, in Settings. The same setting again answers changed: false. No account block applies: this only ever takes away what agents may save.

**Skill CLI:** `teamyou.sh ty never-save set <category> <never|ask-first>`

**Parameters:**

- `category` (path, required) — `health` | `money` | `family` | `contact_details` | `sex` | `religion` | `politics` | `legal` | `confidences` | `secrets` — The category id: one of health, money, family, contact_details, sex, religion, politics, legal, confidences.

**Request body:**

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| `setting` | `never` \| `ask_first` \| `ok` | yes | The new setting. Must be stricter than the current one (ok, then ask_first, then never), or the same. |

**Responses:**

- `200` — The category, whether it changed, and every setting now.
- `400` — Validation error — invalid body, query, or path param (code: validation_error or invalid_json). `details` carries Zod field errors; PATCH /edges also adds `formErrors`.
- `401` — Missing, malformed, expired, or revoked API key (code: unauthorized). A revoked key whose agent has been retired answers 403 agent_retired instead.
- `403` — Forbidden, and nothing was written. never_save_loosen_refused: the setting asked for is looser than the current one; only the person loosens a category, in Settings > Never save. Carries current (the setting now) and settingsUrl (a link to give the person). NOT retryable. never_save_fixed: passwords, keys and tokens, ID numbers and payment card numbers are never saved, and nobody can change that; carries current. Also any agent gate code: api_key_user_not_found, client_identification_required, agent_not_registered, skill_update_required, client_update_nudge, insufficient_scope or agent_retired, as on every gated call.
- `429` — Rate limit exceeded (code: rate_limit_exceeded). Includes Retry-After and X-RateLimit-* headers.
- `500` — Internal server error (code: internal_error).
- `503` — The limit check itself failed, so the request was not run (code: rate_limit_unavailable). The caller did not go over a limit. Includes Retry-After.
