# Commands: `ty agent` (registration, identity, whoami, ack)

Registration is a **display-only** record so the user can see and manage who is calling on
their behalf. The API key remains the only auth boundary; the record never grants access.

```text
teamyou.sh ty agent register [--slug <slug> | --openclaw-instance-id <instance-id>] [--kind claude|codex|perplexity|openclaw|other] [--name <display name>] [--model <model>]
teamyou.sh ty agent whoami
teamyou.sh ty agent list
teamyou.sh ty agent ack <token>
```

`ty agent list` is the peer roster: every agent on this account, with its `id`, `slug`,
`name`, `kind`, `status`, `isPrimary`, `isYou` and `lastSeenAt`. Address a handoff
(`ty checkin send --to`) with an `id` or `slug` from it. Keys and permissions are not
included.

Environment: `TEAMYOU_AGENT_SLUG` is the default `--slug`; `TEAMYOU_OPENCLAW_INSTANCE_ID`
selects the provisioned OpenClaw mode.

## Contents

- [One durable identity per distinct instance](#one-durable-identity-per-distinct-instance)
- [Pick your slug (the stable natural key)](#pick-your-slug-the-stable-natural-key)
- [kind and displayName](#kind-and-displayname)
- [Richer identity (optional, display-only)](#richer-identity-optional-display-only)
- [Status, and the self-healing gate](#status-and-the-self-healing-gate)
- [ack](#ack)
- [First session](#first-session)
- [Examples](#examples)

## One durable identity per distinct instance

Register **one identity per distinct instance**, and reuse it forever. Two agents are
distinct if they differ in **harness** (Claude Desktop, Codex, OpenClaw, Hermes, …) or in
**where they run** (machine, host, deployment).

## Pick your `slug` (the stable natural key)

Re-registering with the same slug refreshes the same agent and re-attaches a rotated API
key to it instead of creating a duplicate. A new key may only take over an identity that no
other live key still holds: rotate by having the old key **revoked first** (Settings → API
keys), then register with the new one. While the old key is live, registering returns 409
`agent_identity_in_use`; tell your person to revoke it, then register again. Resolve the
slug in order:

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

## First session

Your first check-in on an unregistered key returns a `system` item telling you to
register; that item is the trigger for this section, and this is what to do after the
`ty agent register` call succeeds.

If `ty agent whoami` returns `null`, this is your first session: register with a stable
slug (above). Then, only if the account is empty (no projects and at most one topic),
onboard the human:

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
Every later session starts with the check-in and the task at hand, not with a sweep of
the workspace.

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
