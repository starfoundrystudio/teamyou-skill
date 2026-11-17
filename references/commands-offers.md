# Commands: `ty offers`

An offer is something **TeamYou** suggests to your person: today, a guided project (a
ready-made project, such as a daily work log or a morning brief, that you and they run
together). The same offers show on their From TeamYou strip in the app, with the same
reasons, so what you say and what they see never disagree.

## Semantics

- **It is TeamYou's suggestion, never yours.** Say it as TeamYou's: "TeamYou suggests …",
  from the offer's `agentLine`, with its `why`. Never present it as your own idea.
- **Raise one when it fits.** Mention an offer when it matches what your person is doing
  or asking, not as a list read out unprompted. If you notice a need one of
  the guided projects meets, find it with `list --all` and suggest it the same way.
- **Quiet means don't raise it.** When `list` answers `quiet: true`, your person turned on
  Quiet for suggestions: the list still answers, but mention none of it unless they ask
  what TeamYou suggests. Reading the list records nothing.
- **Only your person answers.** `accept`, `snooze` and `dismiss` record their answer. Run
  `accept` only on their own yes, `snooze` on "not now" and `dismiss` on "not for me" —
  never on your own judgment, and never unattended. With no one to ask, say nothing and
  raise it in your next live session.
- **Accepting starts the project.** `accept <offer_id>` starts the offer's project;
  `accept guided:<id>` starts a guided project by key, whether or not an offer for it is
  on their list. Its agent steps are assigned to you and theirs are left unassigned: do
  your steps in order, starting with step 1, which asks and proposes defaults. One
  project per guided template per account, so a repeat returns the same project with
  `alreadyAccepted: true`, and an archived one is set back to active.
- **Not now rests it.** `snooze` hides it for 14 days; a second Not now dismisses it. Only
  your person brings back a dismissed offer, in the app.

## All actions

```bash
teamyou.sh ty offers list [--all]
teamyou.sh ty offers get <offer_id>
teamyou.sh ty offers accept <offer_id|guided:key>
teamyou.sh ty offers snooze <offer_id>
teamyou.sh ty offers dismiss <offer_id>
```

## Example

> **Person:** I keep forgetting what my agents did yesterday.
> **You:** TeamYou suggests "Get a daily standup from your agents": each weekday I gather every agent's
> log into one report before your standup. Want me to start it?
> **Person:** Yes.

```bash
teamyou.sh ty offers accept guided:standup-prep
```
