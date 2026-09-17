# TeamYou Skill


An agent skill for the [TeamYou](https://teamyou.ai) API: knowledge topics, details and
edges, semantic search, todos, projects and areas, and TY Agent Drive (document and file
storage for agents, markdown today).


TeamYou is the shared workspace an AI + human team reviews on the web and on a phone. The
agent writes knowledge, work and documents into it through this skill; the human reads,
steers and marks steps there. Every command is
`"$TY_DIR/scripts/teamyou.sh" ty <noun> <action> [args]`, output is JSON on stdout, and
`-h` at any level prints help.

## Install

Three ways in. They deliver the same payload; pick the one your harness prefers.

**1. From this repository (the `skills` CLI).**

```bash
npx skills add starfoundrystudio/teamyou-skill
```

`SKILL.md` sits at the repository root, so the CLI discovers it without extra flags. Add
`-a <agent>` to target a specific harness and `--copy` to vendor the files into the
project instead of linking them.

**2. From the version-pinned archive TeamYou hands out.**

Your TeamYou account publishes a controlled, version-pinned zip — the same artifact
`GET /api/skill/install` returns, and the same URL that gate responses and update notices
carry as `install_url`. This is the install channel TeamYou points at, and the one an
update notice means when it tells an agent to reinstall.

```bash
curl -L -o teamyou-skill.zip "<the install URL from your TeamYou account>"
```

Unzip it wherever your harness keeps skills (see below). The archive unpacks to a
`teamyou-skill/` directory with `SKILL.md` at its root.

**3. As a plain skill directory.**

Harnesses that follow the open Agent Skills format load a skill from a directory whose
root holds `SKILL.md`. Clone this repository, or unzip the archive, so that the folder you
drop in contains `SKILL.md`, `references/` and `scripts/` at its top level. Nothing needs
to be built. Codex, for example, scans `.agents/skills` from the working directory up to
the repository root and `$HOME/.agents/skills` for personal skills, so a
`$HOME/.agents/skills/teamyou/` directory is enough:

```bash
mkdir -p ~/.agents/skills
git clone https://github.com/starfoundrystudio/teamyou-skill.git ~/.agents/skills/teamyou
```

## Setup

Get an API key from your [TeamYou settings](https://teamyou.ai/settings), then either:

```bash
# Option 1: environment variable
export TEAMYOU_API_KEY="ty_your_api_key_here"

# Option 2: key file (recommended for long-lived agents)
echo "ty_your_api_key_here" > ~/.teamyou_key
```

## Usage

The skill's files live in the directory that holds `SKILL.md`. Resolve the helper against
that directory once, and reuse it — the agent's working directory is usually somewhere
else:

```bash
SKILL_MD="<the SKILL.md location your runtime gave you>"
SKILL_MD="${SKILL_MD/#\~/$HOME}"
TY_DIR="$(cd "$(dirname "$SKILL_MD")" && pwd)"

"$TY_DIR/scripts/teamyou.sh" ty graph topics-list
"$TY_DIR/scripts/teamyou.sh" ty graph search-topics "italian cooking" medium
"$TY_DIR/scripts/teamyou.sh" ty todos list --status todo
"$TY_DIR/scripts/teamyou.sh" ty agent-drive list
```

In conversation that looks like:

```
"Search my TeamYou topics for anything about Italian cooking"
"Create a new TeamYou topic called 'Project Ideas' about AI applications"
"Add these details to topic abc123: Use RAG for context, Focus on mobile UX"
"Show me my high priority todos"
"Write today's meeting notes to my agent drive and share them with the team"
```

## What it covers

- **Topics** — create, read, update, delete knowledge containers, optionally with edges
- **Details** — atomic facts with automatic embedding generation
- **Edges** — graph relationships between topics, one row covering both directions
- **Search** — semantic search across topics and details
- **Todos, projects, areas** — the work surface the human reviews
- **TY Agent Drive** — document and file storage for agents (markdown today), with
  per-document sharing

Full command reference: [SKILL.md](SKILL.md) for the body and conventions,
[references/](references/) for per-noun command pages and the generated per-domain API
reference under `references/api/`.

## Requirements

- `bash`, `curl` and `jq`
- A TeamYou API key

## Versioning and provenance

This repository is a publish target, not the source of truth: every public release is the
validated artifact, extracted and committed. Releases are tagged `vX.Y.Z`, matching
`metadata.version` in [SKILL.md](SKILL.md).

`skill-release.json` at the root records what a tag contains:

| Field | Meaning |
| --- | --- |
| `version` | the released SemVer, same as the tag |
| `git_commit` | the source commit in the TeamYou monorepo the payload was built from |
| `sha256` | the checksum of the published archive these files came out of |

Because the tag carries the same bytes as the published archive, `sha256` is how you check
that an archive you downloaded is the release it claims to be.

## License

[MIT](LICENSE) — Copyright (c) 2026 Star Foundry Studio.
