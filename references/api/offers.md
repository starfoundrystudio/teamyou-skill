<!-- GENERATED FROM openapi.json — DO NOT EDIT. Run `pnpm skill:contract:generate`. -->

# TeamYou API Reference: Offers

What TeamYou suggests to your person, and the guided projects catalogue. Present an offer as TeamYou's suggestion, never your own idea, and accept, snooze or dismiss one only on your person's answer.

Base URL `https://www.teamyou.com/api/external/v1`. Every request except `GET /openapi.json` carries
`Authorization: Bearer ty_<key>`. Rate limits: reads 100/min, writes 120/min, search 30/min
(all 2000/hour); every response carries `X-RateLimit-Limit`, `X-RateLimit-Remaining` and
`X-RateLimit-Reset`. The full machine-readable contract is `GET /openapi.json`.

## Contents

- [List what TeamYou suggests](#list-what-teamyou-suggests)
- [Start a guided project by key](#start-a-guided-project-by-key)
- [Get an offer](#get-an-offer)
- [Accept an offer](#accept-an-offer)
- [Snooze an offer (Not now)](#snooze-an-offer-not-now)
- [Dismiss an offer (Not for me)](#dismiss-an-offer-not-for-me)

### List what TeamYou suggests

```http
GET /offers
```

What TeamYou suggests to your person now: the same offers, order and reasons as the From TeamYou strip in the app, so you never disagree with it. Reading it records nothing. When quiet is true your person turned on Quiet: the list still answers, but raise none of it unless they ask what TeamYou suggests.

Present each as TeamYou's suggestion, never your own idea ("TeamYou suggests …", from agentLine), with why. Raise one only when it fits what your person is doing or asking. Accept, snooze or dismiss only on your person's own answer.

all=true adds the guided catalogue: every guided project with its level, tracks, whether it was started or finished, and its offer when one is on the list. Use it when you notice a need one of them meets; start it by key with POST /offers/accept-template, on your person's yes.

**Skill CLI:** `teamyou.sh ty offers list [--all]`

**Parameters:**

- `all` (query) — `true` | `false` — true adds the guided catalogue.

**Responses:**

- `200` — The offers, and the catalogue with all=true.
- `400` — Validation error — invalid body, query, or path param (code: validation_error or invalid_json). `details` carries Zod field errors; PATCH /edges also adds `formErrors`.
- `401` — Missing, malformed, expired, or revoked API key (code: unauthorized). A revoked key whose agent has been retired answers 403 agent_retired instead.
- `403` — Forbidden. One of: api_key_user_not_found (key belongs to a user absent from this environment); client_identification_required (no recognized X-TeamYou-Client; carries skill_install_url, registerUrl, docs_url; only when TEAMYOU_GATE_REQUIRE_IDENTIFIED_CLIENT); agent_not_registered (registerUrl, skill_install_url, docs_url); skill_update_required (required_version, install_url, docs_url; possibly Deprecation/Sunset headers); client_update_nudge (a soft, relent-able staleness nudge for an agentic client below the latest release when TEAMYOU_GATE_NAG_ENABLED is on; carries verified_version, required_version, upgrade_url, ack_url, ack_token, nag_interval, nag_acks_so_far, docs_url — upgrade to end it, or fetch ack_url to relent one call at a rising cost); insufficient_scope (the API key lacks this operation’s x-teamyou-scope; carries required_scope, granted_scopes, docs_url — NOT retryable: scopes are fixed at key creation, so create a new key with the required scope instead of retrying); agent_retired (this key was revoked and its agent has been retired; carries agent {id, slug}, retiredAt, harness and remove {schedule, keyFile} — switch to a new key for this account if you were given one, otherwise stop checking in to this account; NOT retryable with this key); or an AI-preference denial AI_UPDATE_DISABLED / AI_DELETE_DISABLED / AI_SHARE_DISABLED (an account-wide block in Settings > Agent permissions is on; carries requiredPreference, blockedPreferences (every preference in the way; a sharing call can be blocked by two), fix (one line to relay to your person as-is: which switch or switches to turn off, and where) and settingsUrl (the link to those switches) - NOT retryable until the person turns the block off). Scopes and AI preferences compose as AND — passing one does not bypass the other. Gate codes only apply when the corresponding env flag is enabled.
- `429` — Rate limit exceeded (code: rate_limit_exceeded). Includes Retry-After and X-RateLimit-* headers.
- `500` — Internal server error (code: internal_error).
- `503` — The limit check itself failed, so the request was not run (code: rate_limit_unavailable). The caller did not go over a limit. Includes Retry-After.

### Start a guided project by key

```http
POST /offers/accept-template
```

On your person's yes, start a guided project by its key (guided:<id>, from GET /offers?all=true), whether or not an offer for it is on their list. Its steps meant for an agent are assigned to YOU (this key recorded as the assigner); your person's steps are left unassigned. Do your steps in order. Any live offer for the template is recorded as accepted by you. One project per guided template per account: if it exists it is returned with created false and status 200 (alreadyAccepted true), so a retry is safe; an archived one is set back to active. Never accept without your person's yes. Needs a key registered to an agent (409 agent_not_registered otherwise); 403 assignment_refused (reason escalation), creating nothing, when your agent's other live keys hold scopes this key does not.

**Request body:**

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| `templateKey` | string | yes | A guided project template, `guided:<id>`, from `GET /offers?all=true`. — pattern |

**Responses:**

- `200` — The account already had the project; it is returned (an archived one set back to active).
- `201` — Started the project.
- `400` — Validation error — invalid body, query, or path param (code: validation_error or invalid_json). `details` carries Zod field errors; PATCH /edges also adds `formErrors`.
- `401` — Missing, malformed, expired, or revoked API key (code: unauthorized). A revoked key whose agent has been retired answers 403 agent_retired instead.
- `402` — Payment required — product_limit_exceeded: the request would pass a limit of the account’s plan, and nothing was written. `detail` is a sentence to relay to the person; `upgradeUrl` (when a higher plan is better for this limit) is a page they can open to upgrade, and `settingsUrl` shows their plan and usage. Not retryable until the person upgrades or frees room.
- `403` — Forbidden. One of: api_key_user_not_found (key belongs to a user absent from this environment); client_identification_required (no recognized X-TeamYou-Client; carries skill_install_url, registerUrl, docs_url; only when TEAMYOU_GATE_REQUIRE_IDENTIFIED_CLIENT); agent_not_registered (registerUrl, skill_install_url, docs_url); skill_update_required (required_version, install_url, docs_url; possibly Deprecation/Sunset headers); client_update_nudge (a soft, relent-able staleness nudge for an agentic client below the latest release when TEAMYOU_GATE_NAG_ENABLED is on; carries verified_version, required_version, upgrade_url, ack_url, ack_token, nag_interval, nag_acks_so_far, docs_url — upgrade to end it, or fetch ack_url to relent one call at a rising cost); insufficient_scope (the API key lacks this operation’s x-teamyou-scope; carries required_scope, granted_scopes, docs_url — NOT retryable: scopes are fixed at key creation, so create a new key with the required scope instead of retrying); agent_retired (this key was revoked and its agent has been retired; carries agent {id, slug}, retiredAt, harness and remove {schedule, keyFile} — switch to a new key for this account if you were given one, otherwise stop checking in to this account; NOT retryable with this key); or an AI-preference denial AI_UPDATE_DISABLED / AI_DELETE_DISABLED / AI_SHARE_DISABLED (an account-wide block in Settings > Agent permissions is on; carries requiredPreference, blockedPreferences (every preference in the way; a sharing call can be blocked by two), fix (one line to relay to your person as-is: which switch or switches to turn off, and where) and settingsUrl (the link to those switches) - NOT retryable until the person turns the block off). Scopes and AI preferences compose as AND — passing one does not bypass the other. Gate codes only apply when the corresponding env flag is enabled.
- `409` — Conflict, and nothing was created. agent_not_registered: this key has no registered agent, and the project's agent steps are assigned to the agent that accepts it; carries registerUrl: register (`ty agent register`), then call again. offer_not_startable: the offer starts no project; tell your person about it instead.
- `429` — Rate limit exceeded (code: rate_limit_exceeded). Includes Retry-After and X-RateLimit-* headers.
- `500` — Internal server error (code: internal_error).
- `503` — The limit check itself failed, so the request was not run (code: rate_limit_unavailable). The caller did not go over a limit. Includes Retry-After.

### Get an offer

```http
GET /offers/{id}
```

One offer and where your person is with it (state, why, and the project an accept started). 404 for an offer they were never shown and cannot see.

**Skill CLI:** `teamyou.sh ty offers get <offer_id>`

**Parameters:**

- `id` (path, required) — string — Offer id, off_….

**Responses:**

- `200` — The offer.
- `401` — Missing, malformed, expired, or revoked API key (code: unauthorized). A revoked key whose agent has been retired answers 403 agent_retired instead.
- `403` — Forbidden. One of: api_key_user_not_found (key belongs to a user absent from this environment); client_identification_required (no recognized X-TeamYou-Client; carries skill_install_url, registerUrl, docs_url; only when TEAMYOU_GATE_REQUIRE_IDENTIFIED_CLIENT); agent_not_registered (registerUrl, skill_install_url, docs_url); skill_update_required (required_version, install_url, docs_url; possibly Deprecation/Sunset headers); client_update_nudge (a soft, relent-able staleness nudge for an agentic client below the latest release when TEAMYOU_GATE_NAG_ENABLED is on; carries verified_version, required_version, upgrade_url, ack_url, ack_token, nag_interval, nag_acks_so_far, docs_url — upgrade to end it, or fetch ack_url to relent one call at a rising cost); insufficient_scope (the API key lacks this operation’s x-teamyou-scope; carries required_scope, granted_scopes, docs_url — NOT retryable: scopes are fixed at key creation, so create a new key with the required scope instead of retrying); agent_retired (this key was revoked and its agent has been retired; carries agent {id, slug}, retiredAt, harness and remove {schedule, keyFile} — switch to a new key for this account if you were given one, otherwise stop checking in to this account; NOT retryable with this key); or an AI-preference denial AI_UPDATE_DISABLED / AI_DELETE_DISABLED / AI_SHARE_DISABLED (an account-wide block in Settings > Agent permissions is on; carries requiredPreference, blockedPreferences (every preference in the way; a sharing call can be blocked by two), fix (one line to relay to your person as-is: which switch or switches to turn off, and where) and settingsUrl (the link to those switches) - NOT retryable until the person turns the block off). Scopes and AI preferences compose as AND — passing one does not bypass the other. Gate codes only apply when the corresponding env flag is enabled.
- `404` — Resource not found (code: not_found).
- `429` — Rate limit exceeded (code: rate_limit_exceeded). Includes Retry-After and X-RateLimit-* headers.
- `500` — Internal server error (code: internal_error).
- `503` — The limit check itself failed, so the request was not run (code: rate_limit_unavailable). The caller did not go over a limit. Includes Retry-After.

### Accept an offer

```http
POST /offers/{id}/accept
```

On your person's yes, accept the offer: its project is started from the template it names, with its agent steps assigned to YOU and your person's left unassigned, and the offer is recorded as accepted by you. Do your steps in order. Idempotent: a second accept returns the same project with created false, status 200 and alreadyAccepted true; an archived project is set back to active. Never accept without your person's yes. 409 offer_not_startable for an offer that starts no project, 409 agent_not_registered for a key with no registered agent, 403 assignment_refused (reason escalation) as for POST /offers/accept-template.

**Skill CLI:** `teamyou.sh ty offers accept <offer_id|guided:key>`

**Parameters:**

- `id` (path, required) — string — Offer id, off_….

**Responses:**

- `200` — The project was already started; it is returned (an archived one set back to active).
- `201` — Started the project.
- `401` — Missing, malformed, expired, or revoked API key (code: unauthorized). A revoked key whose agent has been retired answers 403 agent_retired instead.
- `402` — Payment required — product_limit_exceeded: the request would pass a limit of the account’s plan, and nothing was written. `detail` is a sentence to relay to the person; `upgradeUrl` (when a higher plan is better for this limit) is a page they can open to upgrade, and `settingsUrl` shows their plan and usage. Not retryable until the person upgrades or frees room.
- `403` — Forbidden. One of: api_key_user_not_found (key belongs to a user absent from this environment); client_identification_required (no recognized X-TeamYou-Client; carries skill_install_url, registerUrl, docs_url; only when TEAMYOU_GATE_REQUIRE_IDENTIFIED_CLIENT); agent_not_registered (registerUrl, skill_install_url, docs_url); skill_update_required (required_version, install_url, docs_url; possibly Deprecation/Sunset headers); client_update_nudge (a soft, relent-able staleness nudge for an agentic client below the latest release when TEAMYOU_GATE_NAG_ENABLED is on; carries verified_version, required_version, upgrade_url, ack_url, ack_token, nag_interval, nag_acks_so_far, docs_url — upgrade to end it, or fetch ack_url to relent one call at a rising cost); insufficient_scope (the API key lacks this operation’s x-teamyou-scope; carries required_scope, granted_scopes, docs_url — NOT retryable: scopes are fixed at key creation, so create a new key with the required scope instead of retrying); agent_retired (this key was revoked and its agent has been retired; carries agent {id, slug}, retiredAt, harness and remove {schedule, keyFile} — switch to a new key for this account if you were given one, otherwise stop checking in to this account; NOT retryable with this key); or an AI-preference denial AI_UPDATE_DISABLED / AI_DELETE_DISABLED / AI_SHARE_DISABLED (an account-wide block in Settings > Agent permissions is on; carries requiredPreference, blockedPreferences (every preference in the way; a sharing call can be blocked by two), fix (one line to relay to your person as-is: which switch or switches to turn off, and where) and settingsUrl (the link to those switches) - NOT retryable until the person turns the block off). Scopes and AI preferences compose as AND — passing one does not bypass the other. Gate codes only apply when the corresponding env flag is enabled.
- `404` — Resource not found (code: not_found).
- `409` — Conflict, and nothing was created. agent_not_registered: this key has no registered agent, and the project's agent steps are assigned to the agent that accepts it; carries registerUrl: register (`ty agent register`), then call again. offer_not_startable: the offer starts no project; tell your person about it instead.
- `429` — Rate limit exceeded (code: rate_limit_exceeded). Includes Retry-After and X-RateLimit-* headers.
- `500` — Internal server error (code: internal_error).
- `503` — The limit check itself failed, so the request was not run (code: rate_limit_unavailable). The caller did not go over a limit. Includes Retry-After.

### Snooze an offer (Not now)

```http
POST /offers/{id}/snooze
```

Your person said not now: the offer rests 14 days, and a second Not now dismisses it. Recorded as yours. The same move again answers changed false.

**Skill CLI:** `teamyou.sh ty offers snooze <offer_id>`

**Parameters:**

- `id` (path, required) — string — Offer id, off_….

**Responses:**

- `200` — Where the offer is now.
- `401` — Missing, malformed, expired, or revoked API key (code: unauthorized). A revoked key whose agent has been retired answers 403 agent_retired instead.
- `403` — Forbidden. One of: api_key_user_not_found (key belongs to a user absent from this environment); client_identification_required (no recognized X-TeamYou-Client; carries skill_install_url, registerUrl, docs_url; only when TEAMYOU_GATE_REQUIRE_IDENTIFIED_CLIENT); agent_not_registered (registerUrl, skill_install_url, docs_url); skill_update_required (required_version, install_url, docs_url; possibly Deprecation/Sunset headers); client_update_nudge (a soft, relent-able staleness nudge for an agentic client below the latest release when TEAMYOU_GATE_NAG_ENABLED is on; carries verified_version, required_version, upgrade_url, ack_url, ack_token, nag_interval, nag_acks_so_far, docs_url — upgrade to end it, or fetch ack_url to relent one call at a rising cost); insufficient_scope (the API key lacks this operation’s x-teamyou-scope; carries required_scope, granted_scopes, docs_url — NOT retryable: scopes are fixed at key creation, so create a new key with the required scope instead of retrying); agent_retired (this key was revoked and its agent has been retired; carries agent {id, slug}, retiredAt, harness and remove {schedule, keyFile} — switch to a new key for this account if you were given one, otherwise stop checking in to this account; NOT retryable with this key); or an AI-preference denial AI_UPDATE_DISABLED / AI_DELETE_DISABLED / AI_SHARE_DISABLED (an account-wide block in Settings > Agent permissions is on; carries requiredPreference, blockedPreferences (every preference in the way; a sharing call can be blocked by two), fix (one line to relay to your person as-is: which switch or switches to turn off, and where) and settingsUrl (the link to those switches) - NOT retryable until the person turns the block off). Scopes and AI preferences compose as AND — passing one does not bypass the other. Gate codes only apply when the corresponding env flag is enabled.
- `404` — Resource not found (code: not_found).
- `409` — Conflict — offer_state_conflict: the offer is not in a state this move applies to (already accepted, or dismissed by your person), or it changed while the call ran. Nothing moved. Get the offer to see where it stands.
- `429` — Rate limit exceeded (code: rate_limit_exceeded). Includes Retry-After and X-RateLimit-* headers.
- `500` — Internal server error (code: internal_error).
- `503` — The limit check itself failed, so the request was not run (code: rate_limit_unavailable). The caller did not go over a limit. Includes Retry-After.

### Dismiss an offer (Not for me)

```http
POST /offers/{id}/dismiss
```

Your person said not for them: the offer is dismissed until they bring it back in the app. Recorded as yours. The same move again answers changed false.

**Skill CLI:** `teamyou.sh ty offers dismiss <offer_id>`

**Parameters:**

- `id` (path, required) — string — Offer id, off_….

**Responses:**

- `200` — Where the offer is now.
- `401` — Missing, malformed, expired, or revoked API key (code: unauthorized). A revoked key whose agent has been retired answers 403 agent_retired instead.
- `403` — Forbidden. One of: api_key_user_not_found (key belongs to a user absent from this environment); client_identification_required (no recognized X-TeamYou-Client; carries skill_install_url, registerUrl, docs_url; only when TEAMYOU_GATE_REQUIRE_IDENTIFIED_CLIENT); agent_not_registered (registerUrl, skill_install_url, docs_url); skill_update_required (required_version, install_url, docs_url; possibly Deprecation/Sunset headers); client_update_nudge (a soft, relent-able staleness nudge for an agentic client below the latest release when TEAMYOU_GATE_NAG_ENABLED is on; carries verified_version, required_version, upgrade_url, ack_url, ack_token, nag_interval, nag_acks_so_far, docs_url — upgrade to end it, or fetch ack_url to relent one call at a rising cost); insufficient_scope (the API key lacks this operation’s x-teamyou-scope; carries required_scope, granted_scopes, docs_url — NOT retryable: scopes are fixed at key creation, so create a new key with the required scope instead of retrying); agent_retired (this key was revoked and its agent has been retired; carries agent {id, slug}, retiredAt, harness and remove {schedule, keyFile} — switch to a new key for this account if you were given one, otherwise stop checking in to this account; NOT retryable with this key); or an AI-preference denial AI_UPDATE_DISABLED / AI_DELETE_DISABLED / AI_SHARE_DISABLED (an account-wide block in Settings > Agent permissions is on; carries requiredPreference, blockedPreferences (every preference in the way; a sharing call can be blocked by two), fix (one line to relay to your person as-is: which switch or switches to turn off, and where) and settingsUrl (the link to those switches) - NOT retryable until the person turns the block off). Scopes and AI preferences compose as AND — passing one does not bypass the other. Gate codes only apply when the corresponding env flag is enabled.
- `404` — Resource not found (code: not_found).
- `409` — Conflict — offer_state_conflict: the offer is not in a state this move applies to (already accepted, or dismissed by your person), or it changed while the call ran. Nothing moved. Get the offer to see where it stands.
- `429` — Rate limit exceeded (code: rate_limit_exceeded). Includes Retry-After and X-RateLimit-* headers.
- `500` — Internal server error (code: internal_error).
- `503` — The limit check itself failed, so the request was not run (code: rate_limit_unavailable). The caller did not go over a limit. Includes Retry-After.
