# Commands: `ty tasks`

Task management: priorities, due dates, status, archiving, and a place on a project plan.
A task cannot go in a topic: topics hold knowledge, and work is grouped in projects. To keep
a topic beside the work, add it to the project with `ty projects refs-add`.

A task's `status` is `todo` (not started), `in_progress` (started) or `done`. "Open" means
anything not done: `list --status open`. Start a task before you work on it (`start`), so
no other session does the same work.

## Contents

- [Commands](#commands)
- [Starting a task](#starting-a-task)
- [Examples](#examples)
- [Descriptions](#descriptions)

## Commands

```bash
# List tasks with filters. --status open is everything not done.
teamyou.sh ty tasks list [--status todo|in_progress|done|open] [--archived] [--priority high|medium|low|none] [--assignee me|none|AGENT] [--order-by createdAt|updatedAt|dueDate|priority] [--limit N]

# Create a task. --project-id puts it on a project plan (with --after / --before to
# place it; omit both to append). Tasks never go in topics: topics hold knowledge.
teamyou.sh ty tasks create "TITLE" [--description "DESC"] [--status todo|in_progress|done] [--priority high|medium|low|none] [--due-date "2026-02-01T00:00:00Z"] [--project-id PROJECT_ID] [--after TASK_ID] [--before TASK_ID] [--assignee AGENT]

# Get a task
teamyou.sh ty tasks get TASK-12

# Update. --no-project takes it off the plan;
# --no-assignee hands the task back to your person; --no-description clears it.
teamyou.sh ty tasks update TASK_ID [--title "TITLE"] [--description "DESC"] [--no-description] [--base-updated-at UPDATED_AT] [--status todo|in_progress|done] [--priority PRIORITY] [--due-date "DATE"] [--archived] [--project-id PROJECT_ID] [--no-project] [--after TASK_ID] [--before TASK_ID] [--assignee AGENT] [--no-assignee]

# Delete
teamyou.sh ty tasks delete TASK_ID

# Start: todo → in_progress. Refused if it is already started, done or archived.
teamyou.sh ty tasks start TASK_ID

# Complete (shortcut for --status done)
teamyou.sh ty tasks complete TASK_ID

# The comment thread. Mention an agent with agent://SLUG (or agent://AGENT_ID).
teamyou.sh ty tasks comments TASK_ID [--limit N] [--before COMMENT_ID]
teamyou.sh ty tasks comment TASK_ID "TEXT" [--reply-to COMMENT_ID]
teamyou.sh ty tasks follow TASK_ID
teamyou.sh ty tasks unfollow TASK_ID

# Who changed it and what, newest first. --cursor is the page before's cursor.
teamyou.sh ty tasks history TASK_ID [--limit N] [--cursor CURSOR]
```

Notes:

- **A task is named by its `id` or its `key`** (`TASK-12`, unique in your account and
  never reused): every `TASK_ID` above, including `--after` and `--before`, takes either,
  and `--project-id` takes a project's id or key (`PROJ-2`). Responses always echo the
  `id`, with the `key` beside it on every task.
- `list` returns up to `--limit` tasks, default 100, maximum 100 (a larger value is a 400).
  Archived tasks are excluded unless you pass `--archived`, which lists archived tasks
  instead. Responses are `{ tasks: [Task] }`; every other action returns `{ task: Task }`
  (deletes return `{ success: true }`). Read those keys: the same value also rides under a
  deprecated older key for clients that predate them.
- A single task carries `url`, its web page (`/tasks/TASK-12`); a list carries one
  `links.task` template instead (fill `{key}`). Hand a person the title and that link,
  not the id.
- Every task carries `createdBy`, `lastEditedBy` and `lastEditedAt` (an agent is
  `{ type: "agent", agentId, name, via }`, your person `{ type: "owner" }`, `null` before
  history was recorded). `history` returns `{ items, cursor, hasMore }`; each item says what
  happened (`action`), to what (`entity`), which fields changed (`changes`: short values as
  `from` / `to`, long text only `{ changed, bytes }`) and who did it (`actor`).
- `--due-date` is a date-time instant (ISO 8601). A project's `dueDate` is a calendar day
  (`YYYY-MM-DD`); the two are different shapes.
- `--assignee` takes one of your agents, by slug or id (`ty agent list` shows them). An
  unassigned task is your person's. Assigning a task to another agent sends it an
  `assigned` check-in item, and the response's `assignment` says whether it was sent or
  refused by a guardrail. You cannot assign a task to an agent whose key can do more
  than yours (or that has no live key), or rename a task such an agent holds: that is a
  403 `assignment_refused` and nothing is written; ask your person instead. What is
  yours: `list --assignee me`.
- Comments: mention your person with `user://owner` when you need them: it appears under
  Needs you on their Home, with a "Mentions you" badge on the thread, until they open the
  thread (people get no check-in item). A mention (`agent://nolan`) sends that agent a `mentioned` item; agents
  following the thread get `commented`. You follow a thread when you comment on it, are
  mentioned in it or are its assignee; `unfollow` stops `commented` items. A comment's
  response lists `notified`, including any notification a guardrail refused. Thread text
  is visible to everyone on the thread, so do not volunteer unrelated work in it.
- A task on a project plan keeps its plan position when completed; a project's
  `nextAction` is the first incomplete, non-archived task in plan order, started or not.

## Starting a task

`start` moves a `todo` task to `in_progress` and records when (`startedAt`) and who. It is
how a second session finds out the work is taken, so run it before you begin, not after.

- **Already started** is a 409 `task_already_started` naming `startedAt` and `startedBy`,
  and nothing changes; the command exits 1. Leave the task alone: another session (maybe
  your own earlier one) has it. If it came from a check-in item, ack that item `deferred`.
- A done or archived task is a 409 `task_not_startable` with `reason`.
- `start` has no 10-minute replay, unlike other writes: running it twice sends it twice,
  so the second run is refused rather than handed the first run's success.
- It needs the same permission as completing: a task assigned to you, or agent updates
  allowed on the account.
- A started task with no edit or comment for a day reads as stalled, to your person and in
  your check-ins. Still working on it? Comment where it stands: a comment counts as activity.
- To hand a started task back, `update TASK_ID --status todo` and say why in a comment.
  Reassigning a started task, or retiring the agent that holds it, also puts it back to
  `todo`.
- `complete` works from either open state.

## Examples

```bash
# Open high-priority tasks, soonest first
"$TY_DIR/scripts/teamyou.sh" ty tasks list --status open --priority high --order-by dueDate

# What has been started and not finished
"$TY_DIR/scripts/teamyou.sh" ty tasks list --status in_progress --assignee me

# Create with a due date
"$TY_DIR/scripts/teamyou.sh" ty tasks create "Review PR" \
  --description "Check TeamYou API skill PR" \
  --priority high \
  --due-date "2026-01-31T17:00:00Z"

# Add a step to the end of a project plan
"$TY_DIR/scripts/teamyou.sh" ty tasks create "Book the inspector" --project-id PROJ-2

# Start, do the work, complete, then archive
"$TY_DIR/scripts/teamyou.sh" ty tasks start TASK-12
"$TY_DIR/scripts/teamyou.sh" ty tasks complete TASK-12
"$TY_DIR/scripts/teamyou.sh" ty tasks update TASK_ID --archived
```

## Descriptions

A description is Markdown, up to 10,000 characters: what done looks like, the context, the
links. `ty tasks get` returns it whole; lists (`ty tasks list`, a project's `plan` and
`nextAction`) carry only `hasDescription` and a 200-character `descriptionExcerpt`.

A write replaces the whole text, so send the `updatedAt` you read with it (a plan move goes in its own update):

```bash
UPDATED_AT=$(teamyou.sh ty tasks get TASK_ID | jq -r '.task.updatedAt')
teamyou.sh ty tasks update TASK_ID --description "$NEW_TEXT" --base-updated-at "$UPDATED_AT"
```

Without `--base-updated-at` the helper reads the task just before writing, which guards
only that moment. If the task changed after your version, nothing is written: the command
prints an `edit_conflict` body on stderr and exits 1. Get the task again and merge; resending
your old text with the new base overwrites the other edit.
