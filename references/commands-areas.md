# Commands: `ty areas`

An area is a container: a cross-pillar context that groups knowledge and work (topics,
todos, projects, documents, urls) and can nest inside another area. Filing a topic means
adding it to an area; the topic's name stays plain.

## Contents

- [Semantics](#semantics)
- [All actions](#all-actions)
- [Filing: `refs-add`](#filing-refs-add)
- [Nesting: an `area` target is `within`](#nesting-an-area-target-is-within)
- [Reading: `get --depth direct|full`](#reading-get---depth-directfull)
- [Housekeeping](#housekeeping)

## Semantics

- **Prefer existing areas, keep them few.** List them before creating one. Never create
  an area for a single topic; a handful of broad areas ("Home", "Finance", "Wellness",
  "Travel", "Learning", "Family", "Hobbies", "Work", "Career", "People") is the normal
  shape.
- **File specific, read broad.** File each item into the most specific area that fits;
  read with `--depth full` when you want everything the nested sub-areas contribute.
- A member can sit in more than one area when it genuinely belongs to both.
- Every member and sub-area a read returns carries `display`, its human name; read that
  rather than reaching into `target`. A dangling member resolves as
  `{ resolved: false, reason: "missing" }`.
- Deleting an area removes the references it holds (members and sub-area links); the
  members themselves are untouched.

## All actions

```bash
teamyou.sh ty areas list [--include-archived] [--limit N]
teamyou.sh ty areas create <name> [--description <text>] [--archived]
teamyou.sh ty areas get <area_id> [--depth direct|full]
teamyou.sh ty areas update <area_id> [--name <text>] [--description <text>] [--no-description] [--archived] [--no-archived]
teamyou.sh ty areas delete <area_id>
teamyou.sh ty areas refs-add <area_id> --target-type topic|todo|project|area|doc|url [--target-id <id>] [--url <url>] [--title <text>] [--after <ref_id>] [--before <ref_id>]
teamyou.sh ty areas refs-reorder <area_id> <ref_id> [--after <ref_id>] [--before <ref_id>]
teamyou.sh ty areas refs-remove <area_id> <ref_id>
```

## Filing: `refs-add`

```bash
# Find the area first
teamyou.sh ty areas list | jq -r '.areas[] | "\(.id)\t\(.name)"'

# File a topic
teamyou.sh ty areas refs-add AREA_ID --target-type topic --target-id TOPIC_ID

# A project, a todo, a document, a titled url
teamyou.sh ty areas refs-add AREA_ID --target-type project --target-id PROJECT_ID
teamyou.sh ty areas refs-add AREA_ID --target-type todo --target-id TODO_ID
teamyou.sh ty areas refs-add AREA_ID --target-type doc --target-id DOC_ID
teamyou.sh ty areas refs-add AREA_ID --target-type url --url https://example.com/handbook --title "Handbook"

# Place it, instead of appending
teamyou.sh ty areas refs-add AREA_ID --target-type topic --target-id TOPIC_ID --before REF_ID
```

Re-adding an existing target returns 409. `--title` is stored on the reference; a `url`
reference displays under it (or the raw url without one).

## Nesting: an `area` target is `within`

Nest a sub-area by adding it as a member with `--target-type area`. The link means
"within": the sub-area's members roll up into the parent on a full read. A nest that would
close a cycle, or a self-nest, returns 409 `cycle_detected`, never a 500. Position flags do
not apply to an `area` target (it is appended).

```bash
# "Canada Cabin" within "Travel"
teamyou.sh ty areas refs-add TRAVEL_AREA_ID --target-type area --target-id CABIN_AREA_ID

# Un-nest (removal is always cycle-safe)
teamyou.sh ty areas refs-remove TRAVEL_AREA_ID REF_ID
```

## Reading: `get --depth direct|full`

```bash
# Direct members and sub-area links only (the cheap read; the default)
teamyou.sh ty areas get AREA_ID

# Plus rolledUp: members contributed by nested sub-areas, per source, with
# counts { direct, rolledUp } (computed at read time, never stored)
teamyou.sh ty areas get AREA_ID --depth full
```

The response carries `members` (direct, non-area members), `subAreas` (direct `within`
links), and with `--depth full` also `rolledUp` and `counts`.

## Housekeeping

```bash
teamyou.sh ty areas create "Wellness" --description "Health, fitness, sleep"
teamyou.sh ty areas update AREA_ID --name "Health"
teamyou.sh ty areas update AREA_ID --archived
teamyou.sh ty areas list --include-archived
teamyou.sh ty areas refs-reorder AREA_ID REF_ID --after OTHER_REF_ID
teamyou.sh ty areas delete AREA_ID
```
