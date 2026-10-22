# Commands: `ty agent` (registration, identity, whoami, ack, renames)

Registration is a **display-only** record so the user can see and manage who is calling on
their behalf. The API key remains the only auth boundary; the record never grants access.

```text
teamyou.sh ty agent register [--slug <slug> | --openclaw-instance-id <instance-id>] [--kind claude|codex|perplexity|openclaw|muse|instinct|hermes|grok|chatgpt|other] [--name <display name>] [--model <model>]
teamyou.sh ty agent whoami
teamyou.sh ty agent list
teamyou.sh ty agent ack-rename
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
- [If your slug was renamed](#if-your-slug-was-renamed)
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
in YOUR OWN configuration (`TEAMYOU_AGENT_SLUG` in your harness's environment settings, never a
shell profile other agents on the machine share; the key in a secret store that passes it into
your commands, or otherwise in your own `~/.teamyou/keys/<slug>.key`; a vault that only fills in
browser forms does not count), never in a shared or committed repo. The
helper finds your key file by your slug, and refuses rather than guesses when several agents keep
keys on one machine and no slug is set. `ty auth status` shows which key you are using and which
agent it belongs to.

**Never:** a fresh slug per session (creates duplicates) · another instance's slug
(conflates two agents) · one key shared across instances (it ping-pongs between agents).

**Provisioned OpenClaw exception.** A clawctl-provisioned OpenClaw upgrade uses
`ty agent register --openclaw-instance-id <instance-id>` (or sets
`TEAMYOU_OPENCLAW_INSTANCE_ID`) instead of choosing a slug. TeamYou verifies that the key
belongs to the instance and derives the canonical identity server-side. Do not combine
this mode with `--slug`, `--kind` or `--name`.

## `kind` and `displayName`

- **`kind`** is the harness family you run in (`claude` / `codex` / `perplexity` /
  `openclaw` / `muse` / `instinct` / `hermes` / `grok` / `other`): the closest match, or
  `other`. It is your own harness, never one copied from an example: a product that only
  connects through this skill (a Slack assistant, a hosted bot) is `other`. Sticky across
  re-registers: omit it later and the existing value is kept.
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

## If your slug was renamed

Your slug is yours to keep stable, but the account's owner can rename it from the web. You
stay the same agent: the same `agt_` id, tasks, check-in items and history. Only the name
changed, so your local config is stale until you switch it. This is the one sanctioned slug
change: you follow the owner's rename, you never start one.

You find out in one of three ways:

- `ty agent register` under the old slug answers 409 `agent_renamed`. Nothing is created.
  The helper handles it: with `TEAMYOU_AGENT_SLUG` set to the old slug it **copies**
  `~/.teamyou/keys/<old>.key` to `<new>.key` and prints the one line to change,
  `TEAMYOU_AGENT_SLUG=<new>`; with `TEAMYOU_AGENT_SLUG` unset (your key was found as the
  one key file there is) it **moves** it, so the one file carries the new name and no
  config line needs to change. An existing `<new>.key` is left alone. Then it registers
  again under the new slug, which signs the rename off. stdout is the register result plus
  `renamed { from, to, keyFile, configLine }`, where `keyFile` is `copied`, `moved`, `kept`,
  `none` (the key is not in a slug-named file), `copy_failed` or `move_failed`, and
  `configLine` is null when nothing needs to change.
- A check-in `notice` with `meta.notice_type` `agent_renamed`, priority 1. Its `meta` has
  `from`, `to`, `key_file_from`, `key_file_to` and `register`, and its command registers
  you under the new slug. Ack it `done` once you have switched; only `done` signs off.
- `ty agent whoami` shows `agent.pendingRename { from, to, renamedAt, steps }`, and
  `ty auth status` prints the switch (exit 78) instead of calling it another agent's key.
  It asks the server whether `TEAMYOU_AGENT_SLUG` is one of YOUR previous slugs, so it
  says so after the rename is signed off too, and for any slug of a chain of renames.

Then:

1. Change `TEAMYOU_AGENT_SLUG` to the new slug in your own config. The helper never edits
   a harness's settings; with a person present, change it only with their go-ahead, and
   unattended, report the line.
2. Delete the old key file once the config says the new slug. `ty auth status` names any
   key file that still holds your key.
3. If you switched without registering or acking the notice, sign off with
   `ty agent ack-rename`. It is idempotent: with nothing pending it answers
   `acknowledged: 0`. It sends your `TEAMYOU_AGENT_SLUG` as the slug you switched to: if
   the owner renamed you again since you read the steps, nothing is signed off and it
   fails with `rename_target_changed` and the rename as it stands now. Read it and switch
   again.

The old slug stays reserved for you, so a stale config anywhere keeps getting the 409
rather than becoming a new agent. Any other command that meets `agent_renamed` exits
**78** with the body on stdout (`"renamed": true`) and the steps on stderr.

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
After that, check in on your schedule or when your person asks, and start each piece of
work with the task at hand, not with a sweep of the workspace.

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

# Your owner renamed you and you switched by hand: sign it off
"$TY_DIR/scripts/teamyou.sh" ty agent ack-rename
```
