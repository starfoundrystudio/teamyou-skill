# Commands: `ty proposals`

A proposal is your first pass at what TeamYou should hold about your person (what their
"Get to know you" project asks for), submitted for **them** to review on a TeamYou page.

## Contents

- [Semantics](#semantics)
- [All actions](#all-actions)
- [The body](#the-body)
- [After Add to TeamYou](#after-add-to-teamyou)

## Semantics

- **Submitting saves nothing.** `create` stores the proposal and returns `reviewUrl`. Give
  your person that link. On the page they untick what they don't want, choose for any
  likely duplicate (use what they already have, keep it separate, or leave it out), and
  click Add to TeamYou, which saves everything they kept at once. Send the link, not a list
  of what you proposed: offer "Tell me when you've added it, or ask me to list it here", and
  list it in the chat only if they ask.
- **Only your person approves it, in TeamYou.** No command, API call or tool can approve
  or add a proposal. Wait for them to say they are done, then `get` it.
- **What you leave out is said, not sent.** Tell them in a line, with the review link,
  what you held back (contacts are held back by default). A body with `leftOut` is a 400,
  and it is never stored. If they name something to keep, add it with `update`.
- `update` replaces the playback, the items, or both, while the proposal is in review.
  New items recompute the duplicate flags. Keep each unchanged item's ref: on the review
  page your person's choices on unchanged items are kept, and new or changed items are
  marked. The review link stays the same. An applied, rejected or expired proposal is a 409.
- A proposal expires 7 days after it was submitted if it is not built.

## All actions

```bash
teamyou.sh ty proposals create <file>
teamyou.sh ty proposals get <proposal_id>
teamyou.sh ty proposals update <proposal_id> <file>
```

## The body

`<file>` holds one JSON object: an optional `playback` (what you heard, in your own words,
shown at the top of the page) and `items`, 1 to 100 of them. Items name each other by
`ref`, a slug you choose (lowercase letters, digits and `-`), unique in the proposal.
Every item says where it came from: `source` is `conversation` (they told you) or
`agent_memory` (you already knew).

More than 100? Put the most important in, up to 100, and keep the rest for the next
pass, after this one is built. Tell your person in the chat what you deferred: never drop
an item without saying so, and never split one pass across two proposals.

| `kind`    | Fields                                                                     | Shown under                     |
| --------- | -------------------------------------------------------------------------- | ------------------------------- |
| `area`    | `name`, `parentRef`?                                                       | Areas                           |
| `topic`   | `name`, `description`?, `person`?, `areaRef`?                              | People (person), else Knowledge |
| `detail`  | `topicRef`, `content`                                                      | its topic                       |
| `project` | `name`, `goal`?, `areaRef`?, `tasks`? (`[{ "title", "assigneeAgentId" }]`) | Work                            |
| `link`    | `fromRef`, `toRef` (topics or projects)                                    | on both ends                    |

Two topics linked are related; a link with a project end puts the other end on that
project. File into an area with `areaRef`, never with a link. Topic names must differ
from each other (topic names are unique per person).
Nest an area in another with `parentRef`: that area's ref, or the id (`area_…`) of an
area your person has. Build nests it.

Every task names its owner in `assigneeAgentId`: your agent id or slug for a step you
will do (another of their agents by its id or slug), or `null` for a step your person
does. Never put the owner in the title ("Mat: book the room"): the review page shows the
owner beside each task, and Build assigns it. An unknown or retired agent is a 400.

```json
{
  "playback": "You're launching in spring with Ana running design.",
  "items": [
    { "kind": "area", "ref": "work", "source": "conversation", "name": "Work" },
    {
      "kind": "topic",
      "ref": "ana",
      "source": "conversation",
      "name": "Ana",
      "person": true,
      "areaRef": "work"
    },
    {
      "kind": "detail",
      "ref": "ana-role",
      "source": "conversation",
      "topicRef": "ana",
      "content": "Runs design for the launch."
    },
    {
      "kind": "project",
      "ref": "launch",
      "source": "conversation",
      "name": "Spring launch",
      "areaRef": "work",
      "tasks": [
        { "title": "Draft the brief", "assigneeAgentId": "my-agent" },
        { "title": "Book the room", "assigneeAgentId": null }
      ]
    },
    {
      "kind": "link",
      "ref": "launch-ana",
      "source": "conversation",
      "fromRef": "launch",
      "toRef": "ana"
    }
  ]
}
```

A bad ref, a ref of the wrong kind or a link from an item to itself is a 400 naming the
field (`items.3.areaRef`), and nothing is stored.

## After Add to TeamYou

`get` answers `status: "applied"` and a `result`:

- `ids`: each ref to the id it became, or to the existing row your person pointed it at;
- `created` counts, `reused`, and `skipped` with a reason for each item that was not added;
- `links`: a titled TeamYou page for each created area, topic and project, for when you
  show your person what was added (their project's last step says when).

Adding it ticks the steps the person's review closes; read the project for the next open
step.

```bash
teamyou.sh ty proposals get prop_abc123 | jq '{status: .proposal.status, links: .proposal.result.links}'
```
