# Commands: `ty todos`

Task management: priorities, due dates, status, archiving, and optional links to a topic
or a project plan.

```bash
# List todos with filters
teamyou.sh ty todos list [--status todo|done] [--archived] [--priority high|medium|low|none] [--order-by createdAt|updatedAt|dueDate|priority] [--limit N]

# Create a todo. --topic-id links it to a topic; --project-id puts it on a project plan
# (with --after / --before to place it; omit both to append).
teamyou.sh ty todos create "TITLE" [--description "DESC"] [--status todo|done] [--priority high|medium|low|none] [--due-date "2026-02-01T00:00:00Z"] [--topic-id TOPIC_ID] [--project-id PROJECT_ID] [--after TODO_ID] [--before TODO_ID]

# Get a todo
teamyou.sh ty todos get TODO_ID

# Update. --no-topic unlinks the topic; --no-project takes it off the plan.
teamyou.sh ty todos update TODO_ID [--title "TITLE"] [--description "DESC"] [--status todo|done] [--priority PRIORITY] [--due-date "DATE"] [--archived] [--topic-id TOPIC_ID] [--no-topic] [--project-id PROJECT_ID] [--no-project] [--after TODO_ID] [--before TODO_ID]

# Delete
teamyou.sh ty todos delete TODO_ID

# Complete (shortcut for --status done)
teamyou.sh ty todos complete TODO_ID
```

Notes:

- `list` returns up to `--limit` todos, default 100, maximum 100 (a larger value is a 400).
  Archived todos are excluded unless you pass `--archived`, which lists archived todos
  instead. Responses are `{ todos: [Todo] }`; every other action returns `{ todo: Todo }`
  (deletes return `{ success: true }`).
- `--due-date` is a date-time instant (ISO 8601). A project's `dueDate` is a calendar day
  (`YYYY-MM-DD`); the two are different shapes.
- A todo on a project plan keeps its plan position when completed; a project's
  `nextAction` is the first incomplete, non-archived todo in plan order.

## Examples

```bash
# Today's high-priority todos, soonest first
"$TY_DIR/scripts/teamyou.sh" ty todos list --status todo --priority high --order-by dueDate

# Create with a due date and link to a topic
"$TY_DIR/scripts/teamyou.sh" ty todos create "Review PR" \
  --description "Check TeamYou API skill PR" \
  --priority high \
  --due-date "2026-01-31T17:00:00Z" \
  --topic-id TOPIC_ID

# Add a step to the end of a project plan
"$TY_DIR/scripts/teamyou.sh" ty todos create "Book the inspector" --project-id PROJECT_ID

# Complete, then archive
"$TY_DIR/scripts/teamyou.sh" ty todos complete TODO_ID
"$TY_DIR/scripts/teamyou.sh" ty todos update TODO_ID --archived
```
