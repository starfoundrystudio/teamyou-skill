---
name: teamyou
description: Access the TeamYou API to manage knowledge topics, details, edges, semantic search, todos, projects, areas, and TY Agent Drive (document and file storage for agents, markdown today; noun `ty agent-drive`). Use when the user wants to store, retrieve, search, organize, or plan work in TeamYou, or to write, read, or share a document on the agent drive.
metadata:
  version: '3.2.1'
  min_codex_version: '1.0.0'
---

# TeamYou API Skill

TeamYou is the shared workspace an AI + human team reviews on the web and phone. Through
this skill you write knowledge (topics, details, edges), work (todos, projects, areas) and
documents (TY Agent Drive) into it; the human reads, steers and marks steps there. Every
command is `"$TY_DIR/scripts/teamyou.sh" ty <noun> <action> [args]`, output is JSON on
stdout, and `-h` at any level prints help — after an action too (`ty projects create -h`),
which prints usage and writes nothing.

## Using the helper (read first)

The skill's files live in the directory that contains this `SKILL.md`. Resolve the helper
against that directory, once, and reuse it; your working directory is usually somewhere
else. Let the shell expand a leading `~` rather than hardcoding `/home/<user>`. Forward
slashes everywhere, on every platform.

```bash
SKILL_MD="<the SKILL.md location your runtime gave you>"
SKILL_MD="${SKILL_MD/#\~/$HOME}"
TY_DIR="$(cd "$(dirname "$SKILL_MD")" && pwd)"
"$TY_DIR/scripts/teamyou.sh" ty graph topics-list
```

Requires `bash`, `curl` and `jq`. API key: `export TEAMYOU_API_KEY="ty_…"` or
`echo "ty_…" > ~/.teamyou_key`.

## First session (do this once, before anything else)

If `ty agent whoami` returns `null`, this is your first session: register with a stable
slug (see Register). Then, only if the account is empty (no projects and at most one
topic), onboard the human:

1. Confirm registration worked (`ty agent whoami` now returns your agent).
2. Tell the human, in two sentences: TeamYou is the shared workspace they review on the
   web and phone; you write knowledge, projects and documents into it, and they steer you
   there.
3. Ask for ONE thing they are working on right now. Create it as a project (at most 5
   steps, in order; goal optional) and at most 3 topics for the people or things it
   mentions. Never more.
4. Say: "It's on your TeamYou Home. Want to go wider? Ramble to me — work, life, projects,
   things to remember — and I'll organise it."

Shared by a team (several humans talk to you)? Create one project for the team and one
topic per member instead of step 3. Keep onboarding documents private; never share them.

A registered agent on an account that already has projects or topics skips all of this.
Every later session starts with the task at hand, not with a sweep of the workspace.

## Register

Registration is display-only: it puts you on the user's team page so they can see who is
calling. Your API key stays the only security boundary. Register once per distinct
instance (a different harness or a different machine is a different instance) with a slug
that is stable, deterministic and persisted locally in `TEAMYOU_AGENT_SLUG`. Re-register
with the same slug after a key rotation, and omit `--name` then so the user's rename
survives. Never mint a fresh slug per session. Slug precedence, `kind`, identity fields,
`whoami` and `ack`: [references/commands-agent.md](references/commands-agent.md).

```bash
"$TY_DIR/scripts/teamyou.sh" ty agent register --slug "my-agent" --kind claude --name "My Agent"
"$TY_DIR/scripts/teamyou.sh" ty agent whoami
```

## Modes

If a person is present, surface what you found and ask before anything that changes who
can see a document or that spends their attention. If you are running unattended (a cron,
a scheduled job, no one to answer), finish the task, report what you saw in your output,
and never stop early, update yourself, or change how you identify yourself. Every notice
below follows this rule.

## Conventions

- **Topic names are plain and reusable**: 1–3 words, not too broad ("Life"), not too
  specific ("Tuesday gym session"). Search before creating; prefer adding details to an
  existing topic. A person's topic is their full name. Older topics may carry an `Area:`
  prefix; leave those names as they are and do not add prefixes to new ones.
- **Filing is membership, not naming.** An area is a container. File a topic into an
  existing area with `ty areas refs-add`; prefer existing areas, keep them few, and never
  create an area for a single topic.
- **Details are atomic facts**: one fact per detail, up to 50 per call.
- **Edges**: one edge row carries both directions (`label` plus `--mirror-label`). Create
  an edge only when knowing one topic materially helps when working the other; skip
  coincidental overlap. After adding details, run a quick `search-topics` on their
  keywords and link the best actionable match.
- **Named entities**: search first; give a person, organisation, place or product its own
  topic only when it will accumulate more than a fact or two (a recurring relationship,
  ongoing plans). A person who will reappear gets a topic automatically. Link once per
  entity per batch.
- **Projects**: `nextAction` is computed on every read and never stored. Read it; never
  write it back.
- **Agent Drive documents are private by default**, and writing never changes exposure.
  Share only when the human asks, with `ty agent-drive share` or `grant --email`, and tell
  them what you did and with whom.

Long form, the entity mapping and worked workflows:
[references/conventions.md](references/conventions.md).

## Nouns

| Noun          | Most common                                         | Reference                                                     |
| ------------- | --------------------------------------------------- | ------------------------------------------------------------- |
| `graph`       | `topics-create`, `details-add`, `search-topics`     | [commands-graph.md](references/commands-graph.md)             |
| `todos`       | `create`, `list --status todo`                      | [commands-todos.md](references/commands-todos.md)             |
| `projects`    | `create` (one call: plan + refs), `get`, `doc-push` | [commands-projects.md](references/commands-projects.md)       |
| `areas`       | `refs-add` (file a topic), `get --depth full`       | [commands-areas.md](references/commands-areas.md)             |
| `agent-drive` | `push`, `search`                                    | [commands-agent-drive.md](references/commands-agent-drive.md) |
| `agent`       | `register`, `whoami`                                | [commands-agent.md](references/commands-agent.md)             |


Old pattern: the Agent Drive noun changed from `ty drive` to `ty agent-drive`; the old spelling still runs and says so on stderr, so use `ty agent-drive` everywhere.

```bash
# Knowledge: search, then create a plain-named topic and add atomic details
"$TY_DIR/scripts/teamyou.sh" ty graph search-topics "italian cooking" medium
TOPIC_ID=$("$TY_DIR/scripts/teamyou.sh" ty graph topics-create "Italian Cooking" "Recipes and techniques" | jq -r '.topic.id')
"$TY_DIR/scripts/teamyou.sh" ty graph details-add "$TOPIC_ID" "Pasta al dente: firm to bite" "Use San Marzano tomatoes"

# File the topic into an existing area (membership, not a name prefix)
"$TY_DIR/scripts/teamyou.sh" ty areas refs-add AREA_ID --target-type topic --target-id "$TOPIC_ID"

# Work: a todo, and a project with its ordered plan and references in ONE call
"$TY_DIR/scripts/teamyou.sh" ty todos create "Buy groceries" --priority high --due-date "2026-02-01T00:00:00Z"
"$TY_DIR/scripts/teamyou.sh" ty projects create "Cabin expansion" --goal "Permits filed" \
  --todo "Call the county about setbacks" --todo "Get three framing quotes" \
  --ref url:https://example.com/permit-checklist

# Documents: write a markdown file to TY Agent Drive (private), and search it
"$TY_DIR/scripts/teamyou.sh" ty agent-drive push notes.md --path "notes/standup.md" --title "Standup notes"
"$TY_DIR/scripts/teamyou.sh" ty agent-drive search "what blocked the migration"
```

## Notices

Two streams, one rule: **stdout is the result, stderr is everything else.** A successful
call prints its JSON to stdout and exits 0. A failed call prints nothing to stdout, prints
the error JSON (`code`, `title`, `detail`, plus any `registerUrl` / `install_url`) to
stderr, and exits 1. Read stderr when the exit code is not 0; never merge it into your
JSON parser (`2>&1` corrupts the JSON on stdout).

- A `[TeamYou] …` line on **stderr** after a successful call is an advisory, usually that a
  newer skill version exists. Mention it once per session, then follow Modes: with a person
  present, offer to update with their go-ahead; unattended, report it and carry on.
- Exit code **75** with `"code": "client_update_nudge"` on stdout: that one call was held,
  not run. Retry it once (or run the `ack_command` it carries), finish the task, and report
  that an update is pending. Never loop acks.
- A 403 `skill_update_required` is the hard floor: nothing works until the skill is
  reinstalled from the returned `install_url`. Unattended, report it and stop cleanly.

The three signals side by side, the ack rules and the registration gate:
[references/updates.md](references/updates.md).

## MCP

The same operations are also served over the Model Context Protocol at
`https://www.teamyou.com/mcp` (streamable HTTP). Same nouns, same scopes, same handlers:
authenticate with the same `Authorization: Bearer ty_<key>` you use here (OAuth comes
later). Each tool is named for one service at one permission level - `graph_read` /
`graph_write`, `todos_read` / `todos_write`, `agent_drive_read` / `agent_drive_write` /
`agent_drive_sharing` - and takes a required `action` argument whose values are the same
verbs this helper uses. A small default set is advertised; `?tools=extended` on the server
URL puts the full API behind it, adding the remaining services and replacing the tools
whose action set grows with `_all` twins, so a tool name always identifies one action set.
The tool catalogue is generated from the same OpenAPI contract as the reference files
below, so a tool never describes an operation differently from `GET /openapi.json`. Use MCP
when your client speaks it natively; use this helper when you have a shell.

## Rate limits and the raw API

Reads 100/min, writes 60/min, search 30/min, all 1000/hour; the helper exits on a 429, so
back off and retry after `X-RateLimit-Reset` seconds rather than hammering.
The HTTP contract, one file per domain (each self-contained; a Contents block once over
100 lines):
[overview](references/api/overview.md) · [topics](references/api/topics.md) ·
[details](references/api/details.md) · [edges](references/api/edges.md) ·
[search](references/api/search.md) · [todos](references/api/todos.md) ·
[projects](references/api/projects.md) · [areas](references/api/areas.md) ·
[agents](references/api/agents.md) · [agent-drive](references/api/agent-drive.md) ·
[preferences](references/api/preferences.md) ·
[agent-drive (deprecated paths)](references/api/agent-drive-deprecated.md).

