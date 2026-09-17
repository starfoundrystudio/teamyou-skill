# Commands: `ty projects`

A project is a body of work with a goal, an ordered todo plan, and references (topics,
todos, other projects, documents, urls). `projects get` is the one-call orientation read.

## Contents

- [Semantics](#semantics)
- [All actions](#all-actions)
- [Create: plan and refs in one call](#create-plan-and-refs-in-one-call)
- [`--from-json`](#--from-json)
- [References: `refs-add`, `refs-reorder`, `refs-remove`](#references-refs-add-refs-reorder-refs-remove)
- [Documents: `doc-push`](#documents-doc-push)
- [Response shapes](#response-shapes)
- [Raw API: flat vs wrapped refs](#raw-api-flat-vs-wrapped-refs)

## Semantics

- `projects get PROJECT_ID` returns the project, its plan, its refs, a progress rollup
  (`total`, `done`, `percent`) and `nextAction`.
- **`nextAction` is computed on every read and never stored.** It is the first incomplete,
  non-archived todo in plan order, or `null` when the plan is finished or empty. Read it
  when deciding what to do next; never write it back.
- Status is one of `active | waiting | done | archived`. `--waiting-on` names who or what
  the work is blocked on — a short name or phrase (`Bill`, `legal review`), not a status
  update. Both project surfaces draw it in a narrow fixed-width slot and truncate the
  overflow, so a sentence written here is stored but never read. It is meaningful when the
  status is `waiting`, but not enforced against it: a project can carry it while active.
- `dueDate` is a calendar day (`YYYY-MM-DD`), a soft target that drives no behaviour. A
  todo's due date is a date-time instant; the shapes differ.
- Every reference a read returns carries `display`, its human name resolved from the live
  target (or the stored title or url when the target is gone). Read that rather than
  reaching into `target`. A dangling reference resolves as `{ resolved: false }`, never a
  failure.
- Deleting a project orphans its todos (they keep existing, off any plan) and cascades
  its references.

## All actions

```bash
teamyou.sh ty projects list [--status active|waiting|done|archived] [--limit N]
teamyou.sh ty projects create <name> [--goal <text>] [--status active|waiting|done|archived] [--waiting-on <text>] [--notes <text>] [--due-date <YYYY-MM-DD>] [--todo <title>]... [--ref <type>:<value>]... [--from-json <file>]
teamyou.sh ty projects get <project_id>
teamyou.sh ty projects update <project_id> [--name <text>] [--goal <text>] [--status active|waiting|done|archived] [--waiting-on <text>] [--notes <text>] [--due-date <YYYY-MM-DD>] [--no-goal] [--no-waiting-on] [--no-notes] [--no-due-date]
teamyou.sh ty projects delete <project_id>
teamyou.sh ty projects refs-add <project_id> --target-type topic|todo|project|doc|url [--target-id <id>] [--url <url>] [--title <text>] [--after <ref_id>] [--before <ref_id>]
teamyou.sh ty projects doc-push <project_id> <file> [--path <path>] [--title <text>] [--ref-title <text>] [--after <ref_id>] [--before <ref_id>]
teamyou.sh ty projects refs-reorder <project_id> <ref_id> [--after <ref_id>] [--before <ref_id>]
teamyou.sh ty projects refs-remove <project_id> <ref_id>
```

## Create: plan and refs in one call

`create` builds the project and its children in **one atomic call**: flag order is the
order, and a failure anywhere creates nothing. It is create-only (no upsert, no dedupe),
so running it twice makes two projects.

- `--todo <title>` (repeatable) adds a plan step; array order is plan order.
- `--ref <type>:<value>` (repeatable) adds a reference: `topic:<id>`, `todo:<id>`,
  `project:<id>`, `doc:<id>`, or `url:<url>`. The flag form carries no title, so a url
  ref made this way displays as the raw url; to title it, use `--from-json` (below) or
  `refs-add --title` afterwards. A ref cannot point at a `--todo` from the same call (it
  has no id yet); add it afterwards with `refs-add`.
- `--notes` is a narrative markdown body, stored verbatim.

```bash
# One-call hydrate: project + plan + refs + progress + nextAction
teamyou.sh ty projects get PROJECT_ID

# Create with an ordered plan and references in one transaction
teamyou.sh ty projects create "Cabin expansion" \
  --goal "Permits filed and framing started" \
  --todo "Call the county about setbacks" \
  --todo "Get three framing quotes" \
  --ref url:https://example.com/permit-checklist \
  --ref topic:TOPIC_ID
```

## `--from-json`

`--from-json <file>` is client-side only: the file is merged **over** the flags and posted
as the same JSON body. Use it for what the flags cannot express, such as per-todo `status`,
`priority`, `dueDate` or `topicId`, or a long plan you would rather write as data.

```bash
cat > cabin.json <<'EOF'
{
  "goal": "Permits filed and framing started",
  "todos": [
    { "title": "Call the county about setbacks", "priority": "high" },
    { "title": "Get three framing quotes", "dueDate": "2026-10-01T17:00:00Z" }
  ],
  "refs": [
    { "targetType": "url", "url": "https://example.com/permit-checklist", "title": "Permit checklist" }
  ]
}
EOF
teamyou.sh ty projects create "Cabin expansion" --from-json cabin.json
```

The body shape is the `POST /projects` request: `todos[]` are `{ title, description?,
status?, priority?, dueDate?, topicId? }` and `refs[]` are **flat** target objects (below).

## References: `refs-add`, `refs-reorder`, `refs-remove`

`refs-add` attaches one reference to an existing project and is the only form that takes a
`--title`. For a `url` reference the title is the name it displays under; without one it
displays as the raw url. `area` and `entity` targets are rejected on projects. Re-adding an
existing target is a 409.

```bash
# Attach a titled url reference
teamyou.sh ty projects refs-add PROJECT_ID \
  --target-type url \
  --url https://example.com/permit-checklist \
  --title "Permit checklist"

# Attach a topic, placed before another ref
teamyou.sh ty projects refs-add PROJECT_ID --target-type topic --target-id TOPIC_ID --before REF_ID

# Reorder and remove
teamyou.sh ty projects refs-reorder PROJECT_ID REF_ID --after OTHER_REF_ID
teamyou.sh ty projects refs-remove PROJECT_ID REF_ID
```

## Documents: `doc-push`

`doc-push` writes a markdown file to TY Agent Drive and links it to the project as a `doc`
reference in one call. Idempotent: `201` when the reference is created, `200` when the
document was already linked; never a 409.

- Document paths are **global per user, not per project**: re-pushing a path replaces
  that one document everywhere it is referenced. `--path` defaults to
  `projects/<project_id>/<basename>` so same-named files in different projects do not
  collide; pass the same `--path` from two projects only to share one document.
- `--title` names the document; `--ref-title` labels the reference only (the hydrated
  `display` always resolves from the live document title).
- The document is private, like every Agent Drive write. Linking it to a project does not
  share it.
- It is the one command that needs **two** scopes on the key: `agent-drive:write` for the
  document and `work:write` for the reference. A key holding only one gets a 403
  `insufficient_scope` before anything is written, so a partial push is not a state you
  can land in.

```bash
teamyou.sh ty projects doc-push PROJECT_ID notes.md --title "Permit notes"
teamyou.sh ty projects doc-push PROJECT_ID spec.md --path "projects/PROJECT_ID/spec.md" --ref-title "Spec (draft)"
```

## Response shapes

The field names to reach for with `jq`. Note the asymmetry on create: the request body
calls the plan `todos`, every read returns it as `plan`.

| Command                    | Shape                                                                                                                                                                                        |
| -------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `list`                     | `{ projects: [Project] }` (empty array when there are none)                                                                                                                                  |
| `create`, `get`            | `{ project: Project }` hydrated: `plan[]` (Todo, in order), `refs[]` (each with `display`), `progress` (`total`, `done`, `percent`), `nextAction` (Todo or null), `lastActivityAt`           |
| `update`                   | `{ project: Project }` (not hydrated)                                                                                                                                                        |
| `refs-add`, `refs-reorder` | `{ ref: ... }` with `id`, `targetType`, `display`                                                                                                                                            |
| `doc-push`                 | `{ document, ref, url }`: the document's metadata (`id`, `path`, `title`, `visibility`), the hydrated reference, and the document's URL, which is what to hand a person who wants to read it |
| `delete`, `refs-remove`    | `{ success: true }`                                                                                                                                                                          |

```bash
PROJECT_ID=$("$TY_DIR/scripts/teamyou.sh" ty projects create "Cabin permit" --todo "Call the county" | jq -r '.project.id')
"$TY_DIR/scripts/teamyou.sh" ty projects get "$PROJECT_ID" | jq '{next: .project.nextAction.title, steps: [.project.plan[].title], refs: [.project.refs[].display]}'
"$TY_DIR/scripts/teamyou.sh" ty projects doc-push "$PROJECT_ID" notes.md --title "Permit notes" | jq -r '.url'
```

## Raw API: flat vs wrapped refs

Writing the raw API instead of the helper? The inline `refs` on `POST /projects` are
**flat** target objects (`{"targetType":"url","url":"...","title":"Spec"}`), while
`POST /projects/{id}/refs` (`refs-add`) wraps the same object in `{"target": {...}}`.
Sending the wrapper inline is a 400.
