<!-- GENERATED FROM openapi.json — DO NOT EDIT. Run `pnpm skill:contract:generate`. -->

# TeamYou API Reference

REST contract for the TeamYou external API (`/api/external/v1`).

**Recommended: use the TeamYou skill** — it is the supported path. The skill installs from
the link below, identifies every request, and registers your agent in one step.

Raw HTTP works today, but client-identification enforcement is being rolled out. Once it is
enabled, a call with no recognized `X-TeamYou-Client` is rejected with a 403
`client_identification_required` (carrying `skill_install_url`, `registerUrl`, and `docs_url`).
Provisioned tool integrations are the planned non-skill path; until then, install the skill.
If an automated call is unexpectedly rejected, stop and report it rather than changing how the
client identifies itself.

**MCP.** The same operations are also served over the Model Context Protocol at
`https://www.teamyou.com/mcp` — same scopes, same handlers; the tool catalogue is generated from
this contract. Authentication follows the client: OAuth for the ones that speak it (Claude
Code, Claude Desktop / claude.ai, Cursor, Codex, ChatGPT), and `Authorization: Bearer
ty_<key>` for header-only clients.
A read-only server is at `https://www.teamyou.com/mcp/readonly`: only the reading tools are offered, a
sign-in there asks for `read` alone, and a key presented there can change nothing whatever
scopes it holds.
https://www.teamyou.com/mcp/install says which is which and carries the configuration for each.

All endpoints require `Authorization: Bearer ty_<key>` except `GET /openapi.json`. Any 2xx body
may also carry an optional `agent_ecosystem_notice` when the calling skill client is outdated.

**Scopes.** Each API key carries a fixed set of scopes chosen when it was created. Every
operation below publishes what it needs as `x-teamyou-scope` — a string, or an array when an
operation composes two writes and requires ALL of them; a key without one gets a 403
`insufficient_scope` carrying `required_scope` and `granted_scopes`. That denial is NOT
retryable — scopes cannot be edited after creation, so the fix is a new key, not another
attempt. Scopes are separate from the account-wide AI preferences and compose with them as
AND: a call needs the scope on its key AND the preference on the account.

## Contents

- [Authentication](#authentication)
- [Base URL](#base-url)
- [Rate limits](#rate-limits)
- [Discovery](#discovery)
- [MCP](#mcp)
- [Reference files](#reference-files)

## Authentication

All requests except `GET /openapi.json` require an API key:

```http
Authorization: Bearer ty_<your-api-key>
```

Generate API keys at `https://www.teamyou.com/settings`.

## Base URL

```text
https://www.teamyou.com/api/external/v1
```

## Rate limits

Reads 100/min, writes 60/min, search 30/min (all 1000/hour). Every response carries
`X-RateLimit-Limit`, `X-RateLimit-Remaining`, and `X-RateLimit-Reset` headers.

## Discovery

### OpenAPI 3.1 contract

```http
GET /openapi.json
```

Public machine-readable contract. No authentication required.

**Responses:**

- `200` — The OpenAPI 3.1 document.

## MCP

The same operations are served over the Model Context Protocol at
`https://www.teamyou.com/mcp` (streamable HTTP). Same nouns, same scopes, same handlers.
Authentication follows the client: OAuth for the ones that speak it (Claude Code, Claude
Desktop / claude.ai, Cursor, Codex, ChatGPT), and the same `Authorization: Bearer ty_<key>`
as above for header-only clients.
https://www.teamyou.com/mcp/install says which is which and carries the configuration for each.
Each tool is named for one
pillar at one permission level (`knowledge_read` / `knowledge_write`, `work_read` / `work_write`,
`agent_drive_read` / `agent_drive_write`, and `sharing`) and takes a required
`action` argument naming the operation to run. The one exception to the naming is `search`
(`POST /search/all` and `POST /search/related`), which belongs to no pillar because it
crosses every store, and needs only `read`.
8 tools are advertised by
default and carry every knowledge, work and Agent Drive operation plus `search`; `?tools=extended`
widens that to 10 with the Team pillar (`team_read` / `team_write`: agent
identity and preferences, instructions, routines, state). A tool name identifies exactly
one action set. The catalogue is
generated from this contract, so no tool describes an operation differently from the
reference files below.

## Reference files

One file per domain, each self-contained, beside this one under `references/api/`:

| File | Covers | Operations |
| --- | --- | --- |
| `topics.md` | Topics | 5 |
| `details.md` | Details | 4 |
| `edges.md` | Edges | 4 |
| `search.md` | Search | 4 |
| `tasks.md` | Tasks | 6 |
| `projects.md` | Projects | 9 |
| `areas.md` | Areas | 8 |
| `agents.md` | Agents | 3 |
| `agent-drive.md` | Agent Drive | 9 |
| `preferences.md` | Preferences | 1 |
| `agent-drive-deprecated.md` | Agent Drive (deprecated paths) | 8 |
| `tasks-deprecated.md` | Tasks (deprecated paths) | 6 |
