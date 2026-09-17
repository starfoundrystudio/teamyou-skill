# Commands: `ty agent` (registration, identity, whoami, ack)

Registration is a **display-only** record so the user can see and manage who is calling on
their behalf. The API key remains the only auth boundary; the record never grants access.

```text
teamyou.sh ty agent register [--slug <slug> | --openclaw-instance-id <instance-id>] [--kind claude|codex|perplexity|openclaw|other] [--name <display name>] [--model <model>]
teamyou.sh ty agent whoami
teamyou.sh ty agent ack <token>
```

Environment: `TEAMYOU_AGENT_SLUG` is the default `--slug`; `TEAMYOU_OPENCLAW_INSTANCE_ID`
selects the provisioned OpenClaw mode.

## One durable identity per distinct instance

Register **one identity per distinct instance**, and reuse it forever. Two agents are
distinct if they differ in **harness** (Claude Desktop, Codex, OpenClaw, Hermes, …) or in
**where they run** (machine, host, deployment).

## Pick your `slug` (the stable natural key)

Re-registering with the same slug refreshes the same agent and re-attaches a rotated API
key to it instead of creating a duplicate. Resolve it in order:

1. **`TEAMYOU_AGENT_SLUG` is set** → use it. (Named or autonomous agents: the wakeup
   script or operator sets this, e.g. `hermes`; the helper reads it as the default.)
2. **You were given a name** → use it, and persist it to `TEAMYOU_AGENT_SLUG`.
3. **Neither** → derive a stable `<harness>-<host>`, e.g. `claude-desktop-work-laptop`.

Keep it stable, deterministic, anchored on whatever is durable for you (the name for
migratable or cloud agents, the host for machine-pinned harnesses), and persisted
machine-locally (`TEAMYOU_AGENT_SLUG` in the shell profile; the key in `~/.teamyou_key`),
never in a shared or committed repo.

**Never:** a fresh slug per session (creates duplicates) · another instance's slug
(conflates two agents) · one key shared across instances (it ping-pongs between agents).

**Provisioned OpenClaw exception.** A clawctl-provisioned OpenClaw upgrade uses
`ty agent register --openclaw-instance-id <instance-id>` (or sets
`TEAMYOU_OPENCLAW_INSTANCE_ID`) instead of choosing a slug. TeamYou verifies that the key
belongs to the instance and derives the canonical identity server-side. Do not combine
this mode with `--slug`, `--kind` or `--name`.

## `kind` and `displayName`

- **`kind`** is the harness family (`claude` / `codex` / `perplexity` / `openclaw` /
  `other`): the closest match, or `other`. Sticky across re-registers: omit it later and
  the existing value is kept.
- **`displayName`** (`--name`) is the label in the user's list. Set it once on first
  registration and omit it on later registers, so an in-app rename is never overwritten.

## Richer identity (optional, display-only)

You may also send `model`, `declaredSkills`, `mcpServers`, and a verbatim `a2aCard` for
portable agent-to-agent metadata. These are informational. A malformed optional field is
dropped to a non-fatal `warnings[]` entry; registration still succeeds.

## Status, and the self-healing gate

- `ty agent whoami` returns this key's agent (status and last-seen), or `null` if not yet
  registered.
- When registration enforcement is on, a data call from an unregistered key returns
  `code: "agent_not_registered"` with a `registerUrl`: run `ty agent register` and retry.
  A `code: "skill_update_required"` response means this build is below the required
  version; the skill must be reinstalled from the returned `install_url` before any call
  works.

## `ack`

`ty agent ack <token>` relents one held call after a `client_update_nudge` (exit 75). Use
the `ack_command` the nudge carries, then re-run the original command. Each ack is logged
and visible to the owner; never loop it. The full rule set is in the updates reference
linked from `SKILL.md`.

## Examples

```bash
# Register once (idempotent). Set --name on the FIRST register only.
"$TY_DIR/scripts/teamyou.sh" ty agent register --slug "mycroft" --kind openclaw --name "Mycroft"

# Re-register later (key rotation, manifest refresh): same slug, no --name
"$TY_DIR/scripts/teamyou.sh" ty agent register --slug "mycroft"

# No name given and slug not preset: derive a stable <harness>-<host>
"$TY_DIR/scripts/teamyou.sh" ty agent register --slug "claude-desktop-work-laptop" --kind claude

# Check status
"$TY_DIR/scripts/teamyou.sh" ty agent whoami
```
