# Commands: `ty search` (one ranked list across every type, and what an item is connected to)

One call searches topics, details, tasks, projects, areas and TY Agent Drive documents and
returns a single ranked list. Reach for it before acting on a vague question about what the
user already has ("what do I have on the Q4 pricing launch?"), or before creating something that may
already exist. Use the per-type searches (`ty graph search-topics`, `ty agent-drive search`)
when you already know the type and need their extra fields or filters (`--path-prefix`,
`--where`).

## Contents

- [Usage](#usage)
- [Reading a hit](#reading-a-hit)
- [`score` and `methods`](#score-and-methods)
- [`structure`: where a hit sits](#structure-where-a-hit-sits)
- [`counts` and `warnings`](#counts-and-warnings)
- [`ty search related`: one hop from one item](#ty-search-related-one-hop-from-one-item)

## Usage

```text
teamyou.sh ty search <query> [--types t1,t2] [--scope mine|shared|all] [--precision high|medium|low] [--order-by relevance|recency] [--limit N]
teamyou.sh ty search related <type> <id> [--limit N]
```

- `search` is the implicit action: `ty search <query>` and `ty search search <query>` are
  the same call.
- `--types` is a comma-separated list of `topic`, `detail`, `task`, `project`, `area`,
  `document`. Omit it to search every type.
- `--scope` applies to documents only: `mine` (default), `shared` (only documents shared
  with you) or `all`.
- `--limit` is 1-50 (default 20). `--precision` defaults to `medium`.
- An empty query needs `--order-by recency` and lists the most recently updated items:
  `ty search --order-by recency --limit 10`.
- `ty search related <type> <id>` is the other action (see below). To search for the word
  "related" itself, run `ty search search related`.

## Reading a hit

```json
{
  "type": "task",
  "id": "...",
  "title": "Draft the pricing page copy",
  "snippet": "...",
  "score": 0.031,
  "methods": ["vector", "fts"],
  "url": "https://www.teamyou.com/tasks",
  "structure": {
    "project": { "id": "...", "name": "Q4 pricing launch" },
    "topic": null
  },
  "updatedAt": "2026-09-20T17:04:11.000Z"
}
```

- `type` says which store the hit came from, and so which command reads or changes it
  (`ty graph topics-get`, `ty tasks get`, `ty projects get`, `ty areas get`,
  `ty agent-drive pull`). A detail has no command of its own: read its topic.
- `title` is the item's name. A detail has none, so its title is its text cut to 80
  characters. `snippet` is a short excerpt: a topic's description, a detail's text, a
  task's title with its status and due date, a project's goal, an area's description, or a
  document's best-matching chunk.
- `url` is absolute and meant for a person. A detail links to its topic's page, a task to
  the tasks page.
- `sharedBy` appears only on a `document` hit that someone shared with you:
  `{ "userId": "...", "name": "Bea" }` (`name` can be `null`). It is the same field
  `ty agent-drive search` returns. It is absent on your own documents and on every other
  type, so its absence means the document is yours. Do not write to a shared-in document's
  path: it is a path in THEIR Agent Drive.

## `score` and `methods`

- `score` is a fused relevance score, higher is better. It is NOT a similarity or a
  percentage: compare it only within one response, never across two calls.
- `methods` names the arms that matched: `vector` (meaning), `fts` (words), `trigram`
  (spelling). A hit that matched on several arms usually beats a single-arm hit of any
  type. Projects and areas have no `vector` arm, so they match on words and spelling only.
- On an empty-query recency listing, `score` is `null` and `methods` is `[]`.

## `structure`: where a hit sits

| `type`     | `structure`                                                   |
| ---------- | ------------------------------------------------------------- |
| `detail`   | `{ topic: {id, name} }` - the topic it belongs to             |
| `task`     | `{ project: {id, name} or null, topic: {id, name} or null }`  |
| `project`  | `{ areas: [{id, name}] }` - the areas that contain it         |
| `document` | `{ projects: [{id, name}] }` - the projects that reference it |
| `topic`    | `{}`                                                          |
| `area`     | `{}`                                                          |

Follow `structure` to a hit's neighbours instead of searching again: a detail that answers
the question usually means its topic is the thing to read (`ty graph topics-get <id>`).

## `counts` and `warnings`

- `counts` is the number of candidates found per requested type BEFORE the cut to
  `--limit`. A count above what `results` shows for that type means there is more: raise
  `--limit` or narrow with `--types`. `0` means the type was searched and nothing matched.
- `warnings` appears only when something degraded. Tell the entries apart by `code`:
  - `store_unavailable` - one store failed:
    `{ "code": "store_unavailable", "type": "document", "message": "..." }`. The other
    types still answered; the failed type is missing from `results` AND from `counts`, so
    absent is not the same as zero. Say that part of the search did not run rather than
    reporting "nothing found", and retry later.
  - `embedding_unavailable` - semantic matching was down for this call, so every type was
    searched on words (`fts`) and spelling (`trigram`) only:
    `{ "code": "embedding_unavailable", "message": "..." }`. It has no `type`. The results
    are real but may miss items that match only in meaning; retry later before concluding
    something does not exist.

```bash
# The top five hits, one line each
"$TY_DIR/scripts/teamyou.sh" ty search "pricing launch" --limit 5 \
  | jq -r '.results[] | "\(.type)\t\(.title)\t\(.url)"'

# Only tasks and projects, newest first
"$TY_DIR/scripts/teamyou.sh" ty search "pricing" --types task,project --order-by recency
```

## `ty search related`: one hop from one item

Given one item, list the items one hop away, each with how it relates. Use it on a hit you
already have instead of searching again.

```bash
"$TY_DIR/scripts/teamyou.sh" ty search related project <project_id> --limit 10 \
  | jq -r '.results[] | "\(.relation)\t\(.type)\t\(.title)"'
```

- `<type>` is one of `topic`, `detail`, `task`, `project`, `area`, `document`; `<id>` is
  that item's id (from a search hit, or any other command). `--limit` is 1-50 (default 20).
- Each result is a search hit without `score` and `methods`, plus `relation` (and
  `sharedBy` on a shared-in document, as above). Read it as "this item `<relation>` the
  anchor":

| Anchor     | `relation` of what comes back                                           |
| ---------- | ----------------------------------------------------------------------- |
| `topic`    | `linked_topic` (a graph edge; the hit carries its `label`), `detail_of` |
| `detail`   | `topic_of` - its topic                                                  |
| `task`     | `project_of`, `topic_of`                                                |
| `project`  | `contains` (an area holding it), `task_of`, `document_in`, `topic_in`   |
| `area`     | `project_in` - its projects                                             |
| `document` | `contains` - your projects that reference it                            |

- Parents and peers come first, then children, so a project's areas are never crowded out
  by a long task list. Archived tasks, projects and areas are left out, except a task's own
  project.
- A document comes back only if you own it or it is shared with you (a live grant), both
  as an anchor and as a project's `document_in`.
- An id that does not exist, is someone else's, or names a document you cannot open is
  the same `404 not_found` - there is no way to tell those apart, by design. Check the
  type and the id before reporting that something is missing.
