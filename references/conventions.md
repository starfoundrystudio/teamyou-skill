# Conventions: naming, filing, edges, entities, and worked workflows

The long form of the rules summarised in `SKILL.md`, plus the workflows that show them in
sequence. Commands are `"$TY_DIR/scripts/teamyou.sh" ty <noun> <action>`; `TY_DIR` is
resolved once per the "Using the helper" note in `SKILL.md`.

`-h`/`--help` works at both levels — `ty projects -h` and `ty projects create -h` both
print that noun's help and exit `0` without calling the API, so asking a write action for
usage never creates anything. A positional name, title, id or detail that starts with `-`
is refused with a pointer to that help rather than stored as text.

## Contents

- [Topic naming (the Goldilocks rule)](#topic-naming-the-goldilocks-rule)
- [Filing: areas are containers](#filing-areas-are-containers)
- [Details](#details)
- [Topic edge rules](#topic-edge-rules)
- [Named entity rule](#named-entity-rule)
- [Workflow: capturing information](#workflow-capturing-information)
- [Workflow: filing a topic into an area](#workflow-filing-a-topic-into-an-area)
- [Workflow: adding details with edge discovery](#workflow-adding-details-with-edge-discovery)
- [Workflow: adding details with named-entity creation](#workflow-adding-details-with-named-entity-creation)
- [Workflow: enriching context by following edges](#workflow-enriching-context-by-following-edges)
- [Workflow: finding information](#workflow-finding-information)
- [Workflow: a project from a paragraph](#workflow-a-project-from-a-paragraph)
- [Workflow: managing todos](#workflow-managing-todos)

## Topic naming (the Goldilocks rule)

When creating or renaming topics (`ty graph topics-create`, `ty graph topics-update --name`):

- **Length:** 1–3 words. A topic is a reusable bucket, not a sentence.
- **Abstraction:** not too broad ("Life", "Work"), not too specific ("Tuesday Gym
  Session"). "Italian Cooking", "Sprint Planning", "Taxes", "Canada Cabin" are the right
  size.
- **People:** a person's topic is their full name ("Catherine Preisler", "Dr Martinez");
  a family can be "The Zagoris".
- **Prefer existing:** search before creating, and prefer adding details to an existing
  topic over creating a near-duplicate.
- **No prefixes.** Older topics may be named `Area: Topic` from an earlier convention.
  Leave those names as they are and do not add prefixes to new topics; the container is
  the area (below), not the name.

## Filing: areas are containers

An area groups topics, todos, projects, documents and links that belong to one part of
life or work, and can nest inside another area. Filing a topic means adding it to an area
with `ty areas refs-add`, not spelling the area into the name.

- Prefer an existing area. List them with `ty areas list` before creating one.
- Keep areas few and broad ("Home", "Finance", "Wellness", "Travel", "Learning",
  "Family", "Hobbies", "Work", "Career", "People"). Never create an area for a single
  topic.
- A topic can sit in more than one area when it genuinely belongs to both.
- Read broad, file specific: `ty areas get AREA_ID --depth full` rolls up everything the
  nested sub-areas contribute; file each topic into the most specific area that fits.

## Details

- **Atomic:** one fact per detail, not a wall of text. Each detail is embedded for
  semantic search, so a blob of ten facts searches worse than ten details.
- **Batched:** up to 50 details per `details-add` call.

```bash
# Good: several atomic details in one call
"$TY_DIR/scripts/teamyou.sh" ty graph details-add TOPIC_ID "Pasta al dente means firm to bite" "Boil for 8-10 minutes"

# Bad: one blob
"$TY_DIR/scripts/teamyou.sh" ty graph details-add TOPIC_ID "Pasta al dente means firm... [wall of text]"
```

## Topic edge rules

Edges are first-class graph entities. A single edge row covers both directions of one
relationship via `label` (forward) and `mirrorLabel` (inverse); use the `edges-*` commands
to create, list, update and delete them. `ty graph topics-get TOPIC_ID` returns an `edges`
array on the topic with `linkedTopicId`, `linkedTopicName`, `label` (from this topic's
view) and `direction` (`outgoing`, `incoming`, `bidirectional`).

1. **One edge per logical relationship.** One `edges-create` covers both directions. Do
   not store edges as topic details.
2. **Inverse-direction idempotency.** Creating the same edge from the other side with
   swapped labels returns the existing edge; re-runs are safe.
3. **Multiple labels per pair are allowed.** A and B can be linked by `manages` and by
   `mentors`; create separate edges with different labels.
4. **Self-loops are rejected** (400).
5. **New-topic rule.** When creating a topic, decide whether it should connect to existing
   topics and pass an `edges` array to `POST /topics`, or call `edges-create` per
   relationship.
6. **New-detail rule.** When adding details to a topic, decide whether the new detail
   creates or strengthens a relationship to another topic, then create the edge.
7. **Lightweight search trigger.** Extract keywords from the new detail, run
   `ty graph search-topics` (usually `medium`), and evaluate only the best matches.
8. **Strength threshold.** Create an edge only when the relationship is actionable:
   knowing topic A would materially help when working topic B, or the reverse. Skip weak
   or coincidental overlap.
9. **Edge-following for context.** When more context would improve the work, inspect the
   inlined `edges` from `topics-get` and follow the relevant `linkedTopicId`s.
10. **Traversal guardrail.** Default to one hop and the 1–3 most relevant linked topics
    unless the user asks for broader exploration.

Do not write free-text edge details of the form `Edge → Topic Name [TopicID] (label)`; that
is a retired format, and existing ones are handled separately.

## Named entity rule

When adding details, detect named entities (people, companies and organisations, places
and venues, products) and decide whether each deserves its own topic.

1. **De-duplicate per batch.** In a multi-detail add, evaluate each unique entity once.
2. **Search first.** Run `ty graph search-topics` for each candidate and reuse a strong
   match.
3. **Durability test.** Create a topic only when the entity will likely accumulate more
   than one or two facts over time.
4. **Durability signals** (create more readily when present): a recurring relationship
   (`my manager`, `my coach`, `my doctor`, `client`, `vendor`, a family member); repeated
   mentions in the same batch or session; ongoing plans, decisions, dependencies or
   follow-ups tied to the entity.
5. **Avoid sprawl.** Skip one-off mentions, incidental brand references and passing
   entities.
6. **Entity type → topic and filing:**
   - **People** → a topic named with the full name (`Laureen Krueger`), filed in the
     People area.
   - **Companies and organisations** → a topic named for the organisation, filed in the
     most fitting existing area (often Work or Career).
   - **Places and venues** → a topic named for the place when it is a durable anchor;
     otherwise keep it as a detail on the contextual topic (Travel, Hobbies, Work, Home).
   - **Products** → details by default; a topic only when the product is a durable subject
     (ongoing ownership, evaluation, issues, comparisons).
7. **Auto-create for people.** A referenced person with no topic who is likely to
   reappear gets a topic automatically.
8. **Other entity types.** Create when the durability threshold is met; if uncertain and
   a person is present, ask.
9. **Always link after find or create** with `ty graph edges-create`.
10. **Link once per entity per batch.** Do not duplicate edges when several details
    reference the same entity.

## Workflow: capturing information

```bash
# 1. Search for an existing topic
"$TY_DIR/scripts/teamyou.sh" ty graph search-topics "cooking Italian"

# 2. If none fits, create one (plain, reusable name)
TOPIC_ID=$("$TY_DIR/scripts/teamyou.sh" ty graph topics-create "Italian Cooking" "Traditional Italian recipes" | jq -r '.topic.id')

# 3. Add atomic details
"$TY_DIR/scripts/teamyou.sh" ty graph details-add "$TOPIC_ID" \
  "Pasta al dente: firm to bite" \
  "San Marzano tomatoes for best sauce" \
  "Salt pasta water generously"

# 4. Link an actionable relationship (one row, both directions)
"$TY_DIR/scripts/teamyou.sh" ty graph edges-create "$TOPIC_ID" RELATED_TOPIC_ID "informs" --mirror-label "informed by"
```

## Workflow: filing a topic into an area

```bash
# 1. Find the area (prefer existing; keep them few)
"$TY_DIR/scripts/teamyou.sh" ty areas list | jq -r '.areas[] | "\(.id)\t\(.name)"'

# 2. Add the topic as a member
"$TY_DIR/scripts/teamyou.sh" ty areas refs-add AREA_ID --target-type topic --target-id TOPIC_ID

# 3. Read broad when you need everything the area (and its sub-areas) holds
"$TY_DIR/scripts/teamyou.sh" ty areas get AREA_ID --depth full
```

## Workflow: adding details with edge discovery

```bash
# 1. Add the new detail
"$TY_DIR/scripts/teamyou.sh" ty graph details-add TOPIC_ID "Shoes: Size 10"

# 2. Lightweight related-topic discovery from that detail
"$TY_DIR/scripts/teamyou.sh" ty graph search-topics "shoes size 10 pickleball equipment" medium

# 3. If the relationship is actionable, create the edge
"$TY_DIR/scripts/teamyou.sh" ty graph edges-create TOPIC_ID PICKLEBALL_TOPIC_ID "supports gear selection" --mirror-label "informed by fit profile"
```

## Workflow: adding details with named-entity creation

```bash
# 1. Add details that mention an entity
"$TY_DIR/scripts/teamyou.sh" ty graph details-add TOPIC_ID \
  "Shoes: Size 10" \
  "Primary venue: Pacifico Sports Complex"

# 2. Search for an existing topic for the entity
"$TY_DIR/scripts/teamyou.sh" ty graph search-topics "Pacifico Sports Complex pickleball venue" medium

# 3. No strong match and the entity is durable: create once
ENTITY_TOPIC_ID=$("$TY_DIR/scripts/teamyou.sh" ty graph topics-create "Pacifico Sports Complex" "Primary venue for recurring pickleball sessions" | jq -r '.topic.id')

# 4. Link source <-> entity (once per entity per batch)
"$TY_DIR/scripts/teamyou.sh" ty graph edges-create TOPIC_ID "$ENTITY_TOPIC_ID" "plays at" --mirror-label "hosts sessions for"
```

## Workflow: enriching context by following edges

```bash
# 1. Inspect the edges returned inline by topics-get
"$TY_DIR/scripts/teamyou.sh" ty graph topics-get TOPIC_ID | jq '.topic.edges'

# 2. Take the top 1-3 linked topic ids for a one-hop traversal
"$TY_DIR/scripts/teamyou.sh" ty graph topics-get TOPIC_ID | jq -r '.topic.edges[]?.linkedTopicId' | head -n 3

# 3. Fetch each linked topic
"$TY_DIR/scripts/teamyou.sh" ty graph topics-get LINKED_TOPIC_ID
```

Each entry in `.topic.edges` has `id`, `linkedTopicId`, `linkedTopicName`, `label` (already
from this topic's perspective) and `direction`. No string parsing required.

## Workflow: finding information

```bash
"$TY_DIR/scripts/teamyou.sh" ty graph search-details "grandmother's recipe" high
"$TY_DIR/scripts/teamyou.sh" ty graph search-topics "Italian food" medium
"$TY_DIR/scripts/teamyou.sh" ty graph topics-get TOPIC_ID | jq '.topic.details'
```

Results come back in relevance order; rank order is the signal, and `score` is comparable
only within one response (details in the graph commands reference).

## Workflow: a project from a paragraph

"Set up the cabin permit project: call the county, get three quotes, here's the checklist
URL, and here are my notes" becomes one create call, then a document push.

```bash
# 1. One call: project + ordered plan + references (all-or-nothing)
PROJECT_ID=$("$TY_DIR/scripts/teamyou.sh" ty projects create "Cabin permit" \
  --goal "Permit filed" \
  --todo "Call the county about setbacks" \
  --todo "Get three framing quotes" \
  --ref url:https://example.com/permit-checklist | jq -r '.project.id')

# 2. Pasted markdown notes: write the document and link it in one step
"$TY_DIR/scripts/teamyou.sh" ty projects doc-push "$PROJECT_ID" notes.md --title "Permit notes"

# 3. Orientation read: plan, refs, progress and nextAction (computed, never written)
"$TY_DIR/scripts/teamyou.sh" ty projects get "$PROJECT_ID" | jq '.project.nextAction'
```

## Workflow: managing todos

```bash
# Today's high-priority todos
"$TY_DIR/scripts/teamyou.sh" ty todos list --status todo --priority high --order-by dueDate

# Create with a due date
"$TY_DIR/scripts/teamyou.sh" ty todos create "Review PR" \
  --description "Check TeamYou API skill PR" \
  --priority high \
  --due-date "2026-01-31T17:00:00Z"

# Complete, then archive
"$TY_DIR/scripts/teamyou.sh" ty todos complete TODO_ID
"$TY_DIR/scripts/teamyou.sh" ty todos update TODO_ID --archived
```
