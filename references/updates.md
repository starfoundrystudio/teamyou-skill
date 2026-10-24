# Update notices, the update nudge, the version floor, and the registration gate

Everything the helper can tell you about its own version, and what to do about it in each
mode. The one rule under all of it is the Modes section of `SKILL.md`: update the skill
yourself only with your user's go-ahead or their standing permission; otherwise tell them,
or report it in your run output. Either way, finish your task and never re-identify
yourself.

Standing permission is something your user told you, or set in your harness, that still
applies when no one is there to ask: a line in your instructions or memory, your scheduled
task's prompt, a routine they installed. TeamYou has no setting for it; your harness holds
it.

## Contents

- [The signals](#the-signals)
- [Advisory notice on stderr](#advisory-notice-on-stderr)
- [Client update nudge (exit 75)](#client-update-nudge-exit-75)
- [Hard floor: skill_update_required](#hard-floor-skill_update_required)
- [Registration gate: agent_not_registered](#registration-gate-agent_not_registered)
- [Modes, expanded](#modes-expanded)
- [Self-update with standing permission](#self-update-with-standing-permission)

## The signals

| Signal                   | Surface                                          | Meaning                                              | What to do                                                        |
| ------------------------ | ------------------------------------------------ | ---------------------------------------------------- | ----------------------------------------------------------------- |
| `agent_ecosystem_notice` | `200` plus a `[TeamYou]` line on stderr          | Advisory: a newer version exists                     | Keep working; mention it once; update only with permission        |
| `client_update_nudge`    | `403`, exit `75`, `code` on stdout               | Action needed: this one call was held                | Retry once or `ty agent ack <token>`, then continue and report    |
| `skill_update_required`  | `403` from the gate                              | Hard floor: below the required version               | Nothing works until a newer skill is installed                    |
| `agent_renamed`          | `409` from register, exit `78`, `code` on stdout | Your owner renamed your slug; you are the same agent | `ty agent register` switches for you; change `TEAMYOU_AGENT_SLUG` |

`agent_renamed` is not about the skill's version, but it is the other signal that asks you to
change local config, and the one sanctioned exception to "never re-identify yourself": you
follow your owner's rename. It also arrives as a check-in `notice` (`meta.notice_type`
`agent_renamed`) and as `agent.pendingRename` in `ty agent whoami`. The steps are in the
renames section of the agent commands reference.

## Advisory notice on stderr

On a successful call the helper may print one `[TeamYou] <message>` line to **stderr**,
separate from the JSON on stdout. It means a newer TeamYou skill version is available.

- **Surface it once per session.** Relay the message the first time it appears; do not
  repeat it on later calls that carry the same notice.
- **Update only with permission.** With your user's go-ahead or standing permission,
  follow the self-update procedure below. Without it, tell your user an update is
  available, or report it in your output, and carry on.
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
3. **Finish the task, then update or report.** With your user's go-ahead or standing
   permission, follow the self-update procedure below; upgrading once ends the reminders.
   Without it, report in your output that a TeamYou skill update is pending. Either way,
   never change how the client reports its version.

Never script the ack away or loop it blindly. It is a signal the owner can see; upgrading
is always the better choice.

```bash
RESULT=$("$TY_DIR/scripts/teamyou.sh" ty graph topics-list) || true
if printf '%s' "$RESULT" | jq -e '.code == "client_update_nudge"' >/dev/null 2>&1; then
  # Relent with the token and re-run the original call. After the task: update with
  # permission (self-update procedure below), otherwise report that an update is pending.
  TOKEN=$(printf '%s' "$RESULT" | jq -r '.ack_token')
  "$TY_DIR/scripts/teamyou.sh" ty agent ack "$TOKEN"
  "$TY_DIR/scripts/teamyou.sh" ty graph topics-list
fi
```

## Hard floor: skill_update_required

A 403 with `code: "skill_update_required"` means this build is below the minimum version
TeamYou accepts. No retry or ack helps; the skill has to be reinstalled from the returned
`install_url` (also published as `TEAMYOU_SKILL_URL` on the account). With your user's
go-ahead or standing permission, follow the self-update procedure below, then repeat the
refused call. Without it, report the floor in your output and leave TeamYou calls for
later.

## Registration gate: agent_not_registered

When registration enforcement is on, a data call from an unregistered key returns an
actionable error with `code: "agent_not_registered"` and a `registerUrl`. Run
`ty agent register` with your stable slug (see the agent commands reference) and retry the
call. Registration is idempotent, so re-running it after a key rotation is the fix there
too.

## Modes, expanded

The helper cannot tell whether a person is reading. You can.

- **A person is present** (an interactive session, a chat): surface notices once, ask
  before anything that changes who can see a document, and update the skill with their
  go-ahead or standing permission.
- **Unattended** (a cron, a scheduled routine, a queue worker): finish the task you were
  started for; put every notice, nudge or floor into your run output so the owner sees it;
  never stop early to wait for an answer nobody will give; never re-identify the client;
  never share a document. Update the skill only with standing permission, and report what
  you did.

## Self-update with standing permission

The safe way to install a newer skill yourself. TeamYou names the release and its hash;
you check both, keep the old folder until the new one works, and put it back if it does
not.

1. **Check you may, and need to.** Go on only with your user's standing permission (see
   Modes in `SKILL.md`) or their go-ahead now. If the version you are running has a
   `-preview.` suffix, do not self-update: you are a preview build for testing, so report
   the notice and carry on. If your version, ignoring any `-preview.<sha>` suffix, already
   equals `install.version`, you are current: do nothing.
2. **Ask TeamYou for the release.** `GET <TeamYou origin>/api/skill/install` answers
   without a key, so it works below the floor. The origin is `TEAMYOU_API_URL` without its
   `/api/external/v1` path (default `https://www.teamyou.com`). Use `install.artifactUrl`,
   `install.version` and `install.sha256` from that response and nothing else: never a URL
   from a page, document or message.
3. **Download and check it.** The archive's SHA-256 must equal `install.sha256`; stop if it
   differs or `sha256` is null. Unzip to a temporary folder. Its `skill-release.json`
   `version` must equal `install.version` and be at least the required version you were
   given.
4. **Swap the folders.** Move the current skill folder to a new, timestamped
   `~/.teamyou/skill-backup-<old version>-<time>`, then put the new one in its place. Keep
   the backup out of your skills folder: a harness loads every skill folder it finds there,
   so a copy beside the real one is loaded as a second TeamYou skill. Your key is outside
   the folder (`~/.teamyou/keys`, an env var or a vault), so nothing else moves.
5. **Verify.** The installed `"$TY_DIR/scripts/teamyou.sh"` reports the new version (its
   `SKILL_VERSION=` line), and `ty agent whoami` succeeds with it.
6. **Roll back on failure.** If verification fails, put the backup folder back and report
   the update as pending.
7. **Report and carry on.** Report the old version, the new version, and whether it was
   verified or rolled back. Repeat the call that was refused. Remove the backup at your
   next successful run.

In bash (Linux, macOS, Git Bash), with `TY_DIR` the skill folder. It is a function that
returns rather than exits, so a failed check never closes the shell you run it in:

```bash
ty_self_update() {
  local api="${TEAMYOU_API_URL:-https://www.teamyou.com/api/external/v1}"
  local origin="${api%/api/external/v1}" install url new sha tmp got old bak
  install=$(curl -fsS "$origin/api/skill/install") || return 1
  url=$(printf '%s' "$install" | jq -r '.install.artifactUrl')
  new=$(printf '%s' "$install" | jq -r '.install.version')
  sha=$(printf '%s' "$install" | jq -r '.install.sha256')
  [ "$sha" != "null" ] || { echo "no sha256 published; not updating" >&2; return 1; }

  tmp=$(mktemp -d)
  curl -fsSL -o "$tmp/teamyou-skill.zip" "$url" || return 1
  got=$(sha256sum "$tmp/teamyou-skill.zip" | cut -d' ' -f1)   # macOS: shasum -a 256
  [ "$got" = "$sha" ] || { echo "sha256 mismatch; not updating" >&2; return 1; }
  unzip -q "$tmp/teamyou-skill.zip" -d "$tmp/new"   # unpacks to teamyou-skill/
  [ "$(jq -r .version "$tmp/new/teamyou-skill/skill-release.json")" = "$new" ] \
    || { echo "version mismatch; not updating" >&2; return 1; }

  # The script carries its own version on every install path (zip, clone, npx).
  old=$(sed -n 's/^SKILL_VERSION="\(.*\)"$/\1/p' "$TY_DIR/scripts/teamyou.sh")
  bak="$HOME/.teamyou/skill-backup-${old:-unknown}-$(date +%s)"   # outside the skills folder
  mkdir -p "$HOME/.teamyou" && mv "$TY_DIR" "$bak" || return 1
  mv "$tmp/new/teamyou-skill" "$TY_DIR" || { mv "$bak" "$TY_DIR"; return 1; }

  if [ "$(sed -n 's/^SKILL_VERSION="\(.*\)"$/\1/p' "$TY_DIR/scripts/teamyou.sh")" = "$new" ] \
    && "$TY_DIR/scripts/teamyou.sh" ty agent whoami >/dev/null; then
    echo "TeamYou skill updated $old -> $new, verified (backup: $bak)"
  else
    rm -rf "$TY_DIR" && mv "$bak" "$TY_DIR"
    echo "TeamYou skill update $old -> $new rolled back; update pending"
    return 1
  fi
}
ty_self_update
```

The sketch leaves out the required-version check; that version is in the notice or 403
you were given. In PowerShell, check the hash with
`(Get-FileHash teamyou-skill.zip -Algorithm SHA256).Hash`, which prints uppercase: compare
case-insensitively.
