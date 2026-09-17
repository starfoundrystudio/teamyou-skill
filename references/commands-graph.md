# Commands: `ty graph` (topics, details, edges, search)

The knowledge graph. Topics are containers with a name, description and summary; details
are atomic facts inside a topic, each embedded for search; edges link two topics with a
label in each direction. Naming and edge rules are in the conventions reference linked
from `SKILL.md`.

## Contents

- [Topics](#topics)
- [Details](#details)
- [Edges](#edges)
- [Search](#search)
- [Reading search results](#reading-search-results)
- [Response shapes](#response-shapes)

## Topics

```bash
# List all topics
teamyou.sh ty graph topics-list

# Create a topic (1-3 word name, plain and reusable)
teamyou.sh ty graph topics-create "NAME" "DESCRIPTION" [--summary "SUMMARY"]

# Get a topic with all details and its edges
teamyou.sh ty graph topics-get TOPIC_ID

# Update a topic
teamyou.sh ty graph topics-update TOPIC_ID [--name "NAME"] [--description "DESC"] [--summary "SUMMARY"]

# Delete a topic (and its details)
teamyou.sh ty graph topics-delete TOPIC_ID
```

`topics-get` returns `topic.details` and `topic.edges`; each edge carries `linkedTopicId`,
`linkedTopicName`, `label` (from this topic's view) and `direction`.

## Details

```bash
# List details for a topic
teamyou.sh ty graph details-list TOPIC_ID

# Add details (batch, up to 50, one fact each)
teamyou.sh ty graph details-add TOPIC_ID "Detail 1" "Detail 2" "Detail 3"

# Update a detail
teamyou.sh ty graph details-update TOPIC_ID DETAIL_ID "New text"

# Delete a detail
teamyou.sh ty graph details-delete TOPIC_ID DETAIL_ID
```

## Edges

```bash
# List edges (both directions) for a topic
teamyou.sh ty graph edges-list TOPIC_ID

# Create an edge (one row covers both directions)
teamyou.sh ty graph edges-create SOURCE_TOPIC_ID TARGET_TOPIC_ID "enables" --mirror-label "enabled by"

# edges-link is an alias for edges-create
teamyou.sh ty graph edges-link SOURCE_TOPIC_ID TARGET_TOPIC_ID "enables" --mirror-label "enabled by"

# Update edge labels (only label / mirrorLabel are mutable)
teamyou.sh ty graph edges-update EDGE_ID --label "new label" --mirror-label "new inverse"

# Delete an edge
teamyou.sh ty graph edges-delete EDGE_ID
```

Creating the same edge from the other side with swapped labels returns the existing edge,
so re-runs are safe. Self-loops are a 400. The same pair may carry several edges with
different labels.

## Search

```bash
# Search topics (precision is positional and optional: low | medium | high)
teamyou.sh ty graph search-topics "QUERY" [low|medium|high]

# Search details
teamyou.sh ty graph search-details "QUERY" [low|medium|high]
```

Precision: `high` returns fewer, more precise matches; `medium` (the default) balances
relevance and coverage; `low` returns more matches, some less relevant.

## Reading search results

Results are already in relevance order, and rank order is the signal.

- `score` is a fused ranking from vector, full-text, fuzzy-text and recency signals. It is
  comparable **within one response only**: never compare scores across two calls and never
  threshold on an absolute value.
- The legacy `similarity` field exists only for older clients; do not use it as a
  cross-result threshold.
- Topic results may include graph-linked neighbours with empty `methods` and a `linkedVia`
  explanation of the edge that pulled them in.

The same rule applies to `ty agent-drive search`, whose hits also carry `methods`,
`snippet` and `headingPath`.

## Response shapes

The field names to reach for with `jq`. A successful call has no `code` field; a failed
call prints its error JSON (with `code`) to stderr and exits 1.

| Command                                        | Shape                                                                                    |
| ---------------------------------------------- | ---------------------------------------------------------------------------------------- |
| `topics-list`                                  | `{ topics: [Topic] }`                                                                    |
| `topics-create`, `topics-get`, `topics-update` | `{ topic: Topic }`; `topics-get` also fills `topic.details` and `topic.edges`            |
| `details-list`, `details-add`                  | `{ details: [TopicDetail] }`                                                             |
| `edges-list`                                   | `{ edges: [Edge] }`; `edges-create` / `edges-update` return `{ edge: Edge }`             |
| `search-topics`, `search-details`              | `{ results: [...] }`, each with `id`, `score`, `methods`, and the topic or detail fields |
| deletes                                        | `{ success: true }`                                                                      |

A `Topic` has `id`, `name`, `oneSentenceDescription` (the description you passed on
create), `summary`, `createdAt`, `updatedAt`. A `TopicDetail` has `id`, `topicId`,
`detail` (the text), `createdAt`. An `Edge` on `topic.edges` has `id`, `linkedTopicId`,
`linkedTopicName`, `label`, `direction`.

```bash
TOPIC_ID=$("$TY_DIR/scripts/teamyou.sh" ty graph topics-create "Dr Martinez" "Dustin's dentist" | jq -r '.topic.id')
"$TY_DIR/scripts/teamyou.sh" ty graph topics-get "$TOPIC_ID" | jq '{name: .topic.name, details: [.topic.details[].detail]}'
"$TY_DIR/scripts/teamyou.sh" ty graph search-topics "dentist" medium | jq -r '.results[] | "\(.score)\t\(.name)"'
```

After you create a topic and add details, a keyword search for those details will rank
the new topic first. That self-match is not an edge candidate; look at the next results.
