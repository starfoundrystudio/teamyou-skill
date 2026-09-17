# Update notices, the update nudge, the version floor, and the registration gate

Everything the helper can tell you about its own version, and what to do about it in each
mode. The one rule under all of it is the Modes section of `SKILL.md`: a person present
gets told and asked; an unattended run finishes its task, reports, and never updates or
re-identifies itself.

## Contents

- [The three signals](#the-three-signals)
- [Advisory notice on stderr](#advisory-notice-on-stderr)
- [Client update nudge (exit 75)](#client-update-nudge-exit-75)
- [Hard floor: skill_update_required](#hard-floor-skill_update_required)
- [Registration gate: agent_not_registered](#registration-gate-agent_not_registered)
- [Modes, expanded](#modes-expanded)

## The three signals

| Signal                   | Surface                                 | Meaning                                | What to do                                                       |
| ------------------------ | --------------------------------------- | -------------------------------------- | ---------------------------------------------------------------- |
| `agent_ecosystem_notice` | `200` plus a `[TeamYou]` line on stderr | Advisory: a newer version exists       | Keep working; mention it once; offer to update only with consent |
| `client_update_nudge`    | `403`, exit `75`, `code` on stdout      | Action needed: this one call was held  | Retry once or `ty agent ack <token>`, then continue and report   |
| `skill_update_required`  | `403` from the gate                     | Hard floor: below the required version | Nothing works until reinstalled from `install_url`               |

## Advisory notice on stderr

On a successful call the helper may print one `[TeamYou] <message>` line to **stderr**,
separate from the JSON on stdout. It means a newer TeamYou skill version is available.

- **Surface it once per session.** Relay the message the first time it appears; do not
  repeat it on later calls that carry the same notice.
- **Consent before updating.** With a person present, say an update is available and
  offer to perform it with their go-ahead. Unattended, report it in your output and carry
  on. Never overwrite or update the skill on your own initiative.
- **Keep the channels apart.** Never `2>&1` the helper into `jq` or any parser: the
  notice is on stderr, the data is on stdout, and merging them corrupts the JSON.

## Client update nudge (exit 75)

Stronger than the advisory. When this skill build is behind the current release, a gated
call can come back as a `client_update_nudge`. The call you made **did not run**.

How to recognise it:

- The command exits with code **75**, not the generic `1`.
- **stdout** is a JSON object with `"code": "client_update_nudge"`, so it is visible even
  through `$(teamyou.sh … | jq …)`. It carries `verified_version`, `required_version`,
  `upgrade_url`, `ack_url`, `ack_token`, `nag_interval`, `nag_acks_so_far`, and a derived
  `ack_command` (the exact CLI to relent).
- **stderr** carries a readable `[TeamYou] ACTION NEEDED …` block of the same facts.

The fields on stdout are the nudge, not your result. Do not treat them as data.

What to do, in order:

1. **Retry the same call once.** A plain retry is safe and normally succeeds; the nudge
   returns about every `nag_interval` calls, not on every call.
2. **If it is held again, relent with the provided `ack_command`** (`ty agent ack
<ack_token>`), then re-run the original command. Each ack is logged, escalates, and is
   visible to the owner: the nudge gets more frequent the longer the client stays behind,
   and `nag_acks_so_far` is how many times it has relented.
3. **Report** in your output that a TeamYou skill update is pending. With a person
   present, offer to reinstall from `upgrade_url` with their go-ahead; upgrading once ends
   the reminders. Unattended, do not stop and do not change how the client reports its
   version.

Never script the ack away or loop it blindly. It is a signal the owner can see; upgrading
is always the better choice.

```bash
RESULT=$("$TY_DIR/scripts/teamyou.sh" ty graph topics-list) || true
if printf '%s' "$RESULT" | jq -e '.code == "client_update_nudge"' >/dev/null 2>&1; then
  # Preferred: tell the person and upgrade from $(… | jq -r .upgrade_url) with their go-ahead.
  # Otherwise: relent with the token, then re-run the original call.
  TOKEN=$(printf '%s' "$RESULT" | jq -r '.ack_token')
  "$TY_DIR/scripts/teamyou.sh" ty agent ack "$TOKEN"
  "$TY_DIR/scripts/teamyou.sh" ty graph topics-list
fi
```

## Hard floor: skill_update_required

A 403 with `code: "skill_update_required"` means this build is below the minimum version
TeamYou accepts. No retry or ack helps; the skill has to be reinstalled from the returned
`install_url` (also published as `TEAMYOU_SKILL_URL` on the account). With a person
present, tell them and do the reinstall with their go-ahead. Unattended, report the floor
in your output and stop cleanly; do not try to reinstall yourself.

## Registration gate: agent_not_registered

When registration enforcement is on, a data call from an unregistered key returns an
actionable error with `code: "agent_not_registered"` and a `registerUrl`. Run
`ty agent register` with your stable slug (see the agent commands reference) and retry the
call. Registration is idempotent, so re-running it after a key rotation is the fix there
too.

## Modes, expanded

The helper cannot tell whether a person is reading. You can.

- **A person is present** (an interactive session, a chat): surface notices once, ask
  before anything that changes who can see a document, and offer updates rather than
  performing them.
- **Unattended** (a cron, a scheduled routine, a queue worker): finish the task you were
  started for; put every notice, nudge or floor into your run output so the owner sees it;
  never stop early to wait for an answer nobody will give; never update, reinstall or
  re-identify the client; never share a document.
