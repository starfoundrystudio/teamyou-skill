# Commands: `ty proposals`

A proposal is your first pass at what TeamYou should hold about your person (the people
they work with, what they keep track of, a first project, and the areas these go in),
submitted for **them** to review on a TeamYou page. Only deployments running the
guided-review onboarding preview offer it; everywhere else every call answers 404.

## Contents

- [Semantics](#semantics)
- [All actions](#all-actions)
- [The body](#the-body)
- [After Build](#after-build)

## Semantics

- **Submitting saves nothing.** `create` stores the proposal and returns `reviewUrl`. Give
  your person that link. On the page they untick what they don't want, choose for any
  likely duplicate (use what they already have, keep it separate, or leave it out), and
  click Build, which saves everything they kept at once.
- **Only your person approves it, in TeamYou.** No command, API call or tool can approve
  or build a proposal. Wait for them to say they are done, then `get` it.
- **What you leave out is said, not sent.** Tell them in the chat what you are not saving
  (contact details, health, money, family matters) and ask whether to keep any of it. A
  body with `leftOut` is a 400, and it is never stored. If they name something to keep,
  add it with `update`.
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

| `kind`    | Fields                                                                     | Shown under                   |
| --------- | -------------------------------------------------------------------------- | ----------------------------- |
| `area`    | `name`                                                                     | Areas                         |
| `topic`   | `name`, `description`?, `person`?, `areaRef`?                              | Team (person), else Knowledge |
| `detail`  | `topicRef`, `content`                                                      | its topic                     |
| `project` | `name`, `goal`?, `areaRef`?, `tasks`? (`[{ "title", "assigneeAgentId" }]`) | Work                          |
| `link`    | `fromRef`, `toRef` (topics or projects)                                    | on both ends                  |

Two topics linked are related; a link with a project end puts the other end on that
project. File into an area with `areaRef`, never with a link. Topic names must differ
from each other (topic names are unique per person).

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

## After Build

`get` answers `status: "applied"` and a `result`:

- `ids`: each ref to the id it became, or to the existing row your person pointed it at;
- `created` counts, `reused`, and `skipped` with a reason for each item that was not built;
- `links`: a titled TeamYou page for each created area, topic and project. Give your person
  a few of them to look at.

Building also ticks the approve and save steps of their "Get to know you" project, so
carry on from the next step.

```bash
teamyou.sh ty proposals get prop_abc123 | jq '{status: .proposal.status, links: .proposal.result.links}'
```
