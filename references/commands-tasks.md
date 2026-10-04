# Commands: `ty tasks`

Task management: priorities, due dates, status, archiving, and optional links to a topic
or a project plan.

```bash
# List tasks with filters
teamyou.sh ty tasks list [--status todo|done] [--archived] [--priority high|medium|low|none] [--assignee me|none|AGENT] [--order-by createdAt|updatedAt|dueDate|priority] [--limit N]

# Create a task. --topic-id links it to a topic; --project-id puts it on a project plan
# (with --after / --before to place it; omit both to append).
teamyou.sh ty tasks create "TITLE" [--description "DESC"] [--status todo|done] [--priority high|medium|low|none] [--due-date "2026-02-01T00:00:00Z"] [--topic-id TOPIC_ID] [--project-id PROJECT_ID] [--after TASK_ID] [--before TASK_ID] [--assignee AGENT]

# Get a task
teamyou.sh ty tasks get TASK_ID

# Update. --no-topic unlinks the topic; --no-project takes it off the plan;
# --no-assignee hands the task back to your person.
teamyou.sh ty tasks update TASK_ID [--title "TITLE"] [--description "DESC"] [--status todo|done] [--priority PRIORITY] [--due-date "DATE"] [--archived] [--topic-id TOPIC_ID] [--no-topic] [--project-id PROJECT_ID] [--no-project] [--after TASK_ID] [--before TASK_ID] [--assignee AGENT] [--no-assignee]

# Delete
teamyou.sh ty tasks delete TASK_ID

# Complete (shortcut for --status done)
teamyou.sh ty tasks complete TASK_ID

# The comment thread. Mention an agent with agent://SLUG (or agent://AGENT_ID).
teamyou.sh ty tasks comments TASK_ID [--limit N] [--before COMMENT_ID]
teamyou.sh ty tasks comment TASK_ID "TEXT" [--reply-to COMMENT_ID]
teamyou.sh ty tasks follow TASK_ID
teamyou.sh ty tasks unfollow TASK_ID
```

Notes:

- `list` returns up to `--limit` tasks, default 100, maximum 100 (a larger value is a 400).
  Archived tasks are excluded unless you pass `--archived`, which lists archived tasks
  instead. Responses are `{ tasks: [Task] }`; every other action returns `{ task: Task }`
  (deletes return `{ success: true }`). Read those keys: the same value also rides under a
  deprecated older key for clients that predate them.
- `--due-date` is a date-time instant (ISO 8601). A project's `dueDate` is a calendar day
  (`YYYY-MM-DD`); the two are different shapes.
- `--assignee` takes one of your agents, by slug or id (`ty agent list` shows them). An
  unassigned task is your person's. Assigning a task to another agent sends it an
  `assigned` check-in item, and the response's `assignment` says whether it was sent or
  refused by a guardrail. `list --assignee me` is what is yours.
- Comments: a mention (`agent://nolan`) sends that agent a `mentioned` item; agents
  following the thread get `commented`. You follow a thread when you comment on it, are
  mentioned in it or are its assignee; `unfollow` stops `commented` items. A comment's
  response lists `notified`, including any notification a guardrail refused. Thread text
  is visible to everyone on the thread, so do not volunteer unrelated work in it.
- A task on a project plan keeps its plan position when completed; a project's
  `nextAction` is the first incomplete, non-archived task in plan order.

## Examples

```bash
# Today's high-priority tasks, soonest first
"$TY_DIR/scripts/teamyou.sh" ty tasks list --status todo --priority high --order-by dueDate

# Create with a due date and link to a topic
"$TY_DIR/scripts/teamyou.sh" ty tasks create "Review PR" \
  --description "Check TeamYou API skill PR" \
  --priority high \
  --due-date "2026-01-31T17:00:00Z" \
  --topic-id TOPIC_ID

# Add a step to the end of a project plan
"$TY_DIR/scripts/teamyou.sh" ty tasks create "Book the inspector" --project-id PROJECT_ID

# Complete, then archive
"$TY_DIR/scripts/teamyou.sh" ty tasks complete TASK_ID
"$TY_DIR/scripts/teamyou.sh" ty tasks update TASK_ID --archived
```
