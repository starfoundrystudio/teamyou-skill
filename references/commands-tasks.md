# Commands: `ty tasks`

Task management: priorities, due dates, status, archiving, and optional links to a topic
or a project plan.

```bash
# List tasks with filters
teamyou.sh ty tasks list [--status todo|done] [--archived] [--priority high|medium|low|none] [--order-by createdAt|updatedAt|dueDate|priority] [--limit N]

# Create a task. --topic-id links it to a topic; --project-id puts it on a project plan
# (with --after / --before to place it; omit both to append).
teamyou.sh ty tasks create "TITLE" [--description "DESC"] [--status todo|done] [--priority high|medium|low|none] [--due-date "2026-02-01T00:00:00Z"] [--topic-id TOPIC_ID] [--project-id PROJECT_ID] [--after TASK_ID] [--before TASK_ID]

# Get a task
teamyou.sh ty tasks get TASK_ID

# Update. --no-topic unlinks the topic; --no-project takes it off the plan.
teamyou.sh ty tasks update TASK_ID [--title "TITLE"] [--description "DESC"] [--status todo|done] [--priority PRIORITY] [--due-date "DATE"] [--archived] [--topic-id TOPIC_ID] [--no-topic] [--project-id PROJECT_ID] [--no-project] [--after TASK_ID] [--before TASK_ID]

# Delete
teamyou.sh ty tasks delete TASK_ID

# Complete (shortcut for --status done)
teamyou.sh ty tasks complete TASK_ID
```

Notes:

- `list` returns up to `--limit` tasks, default 100, maximum 100 (a larger value is a 400).
  Archived tasks are excluded unless you pass `--archived`, which lists archived tasks
  instead. Responses are `{ tasks: [Task] }`; every other action returns `{ task: Task }`
  (deletes return `{ success: true }`). Read those keys: the same value also rides under a
  deprecated older key for clients that predate them.
- `--due-date` is a date-time instant (ISO 8601). A project's `dueDate` is a calendar day
  (`YYYY-MM-DD`); the two are different shapes.
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
