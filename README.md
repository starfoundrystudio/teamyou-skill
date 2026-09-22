# TeamYou Skill


An agent skill for the [TeamYou](https://teamyou.ai) API: knowledge topics, details and
edges, semantic search, tasks, projects and areas, and TY Agent Drive (document and file
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
"$TY_DIR/scripts/teamyou.sh" ty tasks list --status todo
"$TY_DIR/scripts/teamyou.sh" ty agent-drive list
```

In conversation that looks like:

```
"Search my TeamYou topics for anything about Italian cooking"
"Create a new TeamYou topic called 'Project Ideas' about AI applications"
"Add these details to topic abc123: Use RAG for context, Focus on mobile UX"
"Show me my high priority tasks"
"Write today's meeting notes to my agent drive and share them with the team"
```

## What it covers

- **Topics** — create, read, update, delete knowledge containers, optionally with edges
- **Details** — atomic facts with automatic embedding generation
- **Edges** — graph relationships between topics, one row covering both directions
- **Search** — semantic search across topics and details
- **Tasks, projects, areas** — the work surface the human reviews
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
| `payload_sha256` | a content fingerprint of the payload: the SHA-256 of the sorted `<sha256>  <path>` index of every file, the manifest itself excluded |

`payload_sha256` is the same value in the published archive and at this tag for a given
release, so it tells you the two carry the same files. It is not the checksum of the
archive, and it cannot be: the hash of an archive cannot live inside that archive, because
writing it in would change the bytes being hashed.

### Verifying a download

The archive's own SHA-256 is published from teamyou.com, outside the archive:

```bash
curl -s https://www.teamyou.com/api/skill/install
```

Download the zip at `install.artifactUrl`, then compare the file's SHA-256 with
`install.sha256`: `sha256sum` on Linux and Git Bash, `shasum -a 256` on macOS, or
`(Get-FileHash <file> -Algorithm SHA256).Hash` in PowerShell (uppercase; compare
case-insensitively). Do not install if they differ. The same value appears on
<https://www.teamyou.com/llms.txt>.

The value is computed by teamyou.com from the bytes it currently serves at that URL, so a
match tells you your download is exactly what TeamYou is publishing right now, intact and
current. The publish procedure separately checks that value against the archive the release
was built from.

## License

[MIT](LICENSE) — Copyright (c) 2026 Star Foundry Studio.
