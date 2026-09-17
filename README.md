# TeamYou Clawdbot Skill


A Clawdbot skill for interacting with the [TeamYou](https://teamyou.ai) API to manage knowledge topics, details, todos, and semantic search.


## Installation

Install from the artifact link TeamYou gives you — the same version-pinned archive
`GET /api/skill/install` returns (the controlled Vercel Blob zip, also surfaced to the
gate and update notices as `install_url`). Download and unzip it, then set your API key
(see Setup below):

```bash
curl -L -o teamyou-skill.zip "<artifact-url-from-your-TeamYou-install-page>"
unzip teamyou-skill.zip
```

## Setup

Get your API key from [TeamYou Settings](https://teamyou.com/settings), then configure:

```bash
# Option 1: Environment variable
export TEAMYOU_API_KEY="ty_your_api_key_here"

# Option 2: Config file (recommended)
echo "ty_your_api_key_here" > ~/.teamyou_key
```

## Usage

Once installed, you can interact with TeamYou through OpenClaw:

```
"Search my TeamYou topics for anything about Italian cooking"
"Create a new TeamYou topic called 'Project Ideas' about AI applications"
"Add these details to topic abc123: Use RAG for context, Focus on mobile UX"
"Update TeamYou topic abc123 summary to focus on launch milestones"
"Delete detail def456 from topic abc123"
"Show me my high priority todos"
"Create a todo to review the PR, high priority, due tomorrow"
```

When creating or renaming topics, keep the name to 1-3 words (for example: `Sprint Planning`, `Dr Martinez`, `Spanish`) and file it into an existing area with `teamyou.sh ty areas refs-add`.
When linking topics, use the dedicated edges API: `teamyou.sh ty graph edges-create SOURCE_TOPIC_ID TARGET_TOPIC_ID "label" --mirror-label "inverse label"`. A single edge row covers both directions of the relationship.
When adding details, run a quick `search-topics` on keywords from the new detail and create edges only for actionable relationships.
When richer context is needed, `topics-get` returns inlined `edges` — follow relevant `linkedTopicId`s (usually one hop) for context.
When details contain durable named entities (especially people), create/reuse entity topics and link them once with `edges-create`.

## Features

- **Topics**: Create, read, update, delete knowledge containers (optionally with initial edges)
- **Details**: Create, read, update, delete atomic facts with automatic embedding generation
- **Edges**: Create, read, update, delete graph relationships between topics
- **Search**: Semantic search across all topics and details
- **Todos**: Task management with priorities, due dates, and archiving


## Requirements

- `jq` - JSON processor (typically included with OpenClaw setup)
- TeamYou API key

## Development

### Testing the Script

```bash
# Set your API key
export TEAMYOU_API_KEY="ty_your_key"

# Test commands (resolve TY_DIR once, per SKILL.md "Using the helper")
"$TY_DIR/scripts/teamyou.sh" ty graph topics-list
"$TY_DIR/scripts/teamyou.sh" ty graph search-topics "test query" medium
"$TY_DIR/scripts/teamyou.sh" ty todos list --status todo
```

### Packaging

```bash
# Package the skill for release from repo root
./scripts/package-teamyou-skill.sh public 3.2.0
```

### Creating a release

Use GitHub Actions workflow `Release TeamYou Skill` with inputs `variant` and `version`:

- Validates SemVer input and `metadata.version` alignment
- Packages immutable artifact(s) under `dist/`
- Creates tag `skill/teamyou-public/vX.Y.Z`
- Publishes a GitHub Release with `teamyou-skill-public-vX.Y.Z.zip` and `SHA256SUMS`

### Publish a direct install ZIP via Vercel Blob

If you want a link-share install path, upload the artifact to your public Blob store:

```bash
# repo root
export BLOB_READ_WRITE_TOKEN="vercel_blob_rw_..."
./scripts/publish-teamyou-skill.sh public 3.2.0 teamyou-skill
```

The script prints a public download URL that can be shared directly with OpenClaw users.

## Documentation

- [SKILL.md](SKILL.md) - the skill body: conventions, nouns, notices
- [references/](references/) - command references per noun, conventions, update handling, and the generated per-domain API reference under `references/api/`
