# Commands: `ty agent-drive` (TY Agent Drive)

**TY Agent Drive** is document and file storage for agents (markdown today), called "Agent
Drive" in the TeamYou app and unrelated to Google Drive. Write a `.md` and the user can read
it in TeamYou (web and mobile) at the returned `documentUrl` (`/agent-drive/{id}`).
Re-pushing the same `--path` replaces that document (whole-document replace).

## Contents

- [All actions](#all-actions)
- [Five behaviours to know before scripting against it](#five-behaviours-to-know-before-scripting-against-it)
- [Sharing mechanics](#sharing-mechanics)
- [Documents shared with your user](#documents-shared-with-your-user)
- [Examples](#examples)
- [Reading search results](#reading-search-results)

## All actions

```bash
teamyou.sh ty agent-drive list [--scope mine|shared|all|accessed] [--prefix <path>] [--archived] [--limit N] [--offset N]
teamyou.sh ty agent-drive push <file> [--path <path>] [--title <text>]
teamyou.sh ty agent-drive pull <id> [--out <file>]
teamyou.sh ty agent-drive delete <id>
teamyou.sh ty agent-drive share <path-or-id> [--audience public|authenticated]
teamyou.sh ty agent-drive unshare <path-or-id>
teamyou.sh ty agent-drive grant <path-or-id> --email <address>
teamyou.sh ty agent-drive ungrant <path-or-id> --email <address>
teamyou.sh ty agent-drive restore <id>
teamyou.sh ty agent-drive search <query> [precision] [--scope mine|shared|all] [--path-prefix <prefix>] [--limit N]
```

## Five behaviours to know before scripting against it

1. **Documents are private by default, and sharing is a separate, deliberate request.**
   `documentUrl` is the document's one canonical URL: its private address and, once
   shared, its share URL. Writing never changes exposure; the write API neither accepts
   nor honours a visibility field, so a document cannot be published as a side effect of
   saving it. Read the current state off `visibility` on any list or read response. A
   shared document can also be fetched as raw markdown at `/agent-drive/{id}/raw`; that is
   how a non-TeamYou agent reads one, and `share` returns that URL for the purpose.
2. **Re-pushing unchanged content is free and silent.** If the file is byte-identical to
   what is stored, the write returns `200` with `"unchanged": true`, nothing is written,
   and the document keeps its place in the list. A real change returns `201` with
   `"unchanged": false`. Sync loops can push on every flush without churning the user's
   Agent Drive.
3. **Delete is recoverable, and reviving never re-shares.** Delete archives the document;
   it then behaves as if it never existed (`pull` and a second `delete` both 404) until
   you `restore` it. Find deleted documents with `list --archived`. Both revival paths,
   `restore` and re-pushing the same `--path`, reset visibility to **private**, because
   deleting is how a user pulls a document off the internet and bringing it back must not
   silently re-expose it.
4. **Agent Drive is searchable.** `search` finds content anywhere in a document, not just
   its opening, and matches on meaning as well as exact words. **Search before you push to
   a path you might already own**: `list` shows only paths you can guess, `search` shows
   what is actually there.
5. **Other people can share documents with your user, and you read as them.** See
   "Documents shared with your user" below.

## Sharing mechanics

Sharing is a state, not a link you generate, and it is the user's decision. All three
share forms need the `share` scope (the "Share on your behalf" permission in Settings) on
your key.

- `share` makes the document readable by **anyone with the link** (default audience
  `public`), or by anyone signed into TeamYou with `--audience authenticated`.
- `grant --email` shares it with **one named person**: the narrowest form, and the one to
  prefer when the user names a recipient. `grant` does not tell you whether the address
  already has a TeamYou account; if not, the person is invited and gets access when they
  sign up with it. Either way you get `shared: true`, so do not report whether they are
  "a user".
- `unshare` and `ungrant --email` are the undos; the owner can also revoke anything in the
  web share dialog. `share`/`unshare` flip who the document's own address works for; there
  is no second URL and nothing to rotate, so re-sharing later re-enables **the same URL**
  and anyone who kept it gets back in. Say so if a user asks you to "revoke" a public
  share. A person grant names an account, so `ungrant` actually removes that person.
- Share when the user asks, and tell them what you did and with whom. Never publish a
  document on your own initiative, and never as a convenience for yourself.
- A 403 on any of these means the key does not hold the `share` scope: tell the user to
  grant it in Settings rather than retrying, and never work around it by pasting the
  content somewhere public.

## Documents shared with your user

`list` and `search` take `--scope mine|shared|all`. The default is `mine`, so nothing you
already do changes. `--scope shared` shows **only** what has been shared with your user;
`--scope all` shows both.

- A shared-in document is **not yours**. Never `push` to its path: you would create a
  document of your own at that path, not edit theirs. Do not treat it as your own memory;
  the owner can revoke at any moment, and it then disappears from every list and search
  immediately.
- Rows and hits from that corpus carry `sharedBy` (who owns it), and search hits carry
  `source: "drive-shared"` rather than `"drive"`.
- The `path` on a shared-in document is its path in **their** Agent Drive.

## Examples

```bash
# Write (create or replace-by-path) from a local .md file.
# --path defaults to the file's basename; --title defaults to the path.
teamyou.sh ty agent-drive push notes.md --path "notes/standup.md" --title "Standup notes"

# List your documents (metadata); deleted ones instead; only shared-in; both
teamyou.sh ty agent-drive list
teamyou.sh ty agent-drive list --archived
teamyou.sh ty agent-drive list --scope shared
teamyou.sh ty agent-drive list --scope all

# Read a document, to a file or to stdout
teamyou.sh ty agent-drive pull DOC_ID --out copy.md
teamyou.sh ty agent-drive pull DOC_ID

# Delete (archived, recoverable) and bring back
teamyou.sh ty agent-drive delete DOC_ID
teamyou.sh ty agent-drive restore DOC_ID

# Share by path or id; default audience is public (anyone with the link)
teamyou.sh ty agent-drive share "notes/standup.md"
teamyou.sh ty agent-drive share DOC_ID --audience authenticated
teamyou.sh ty agent-drive unshare "notes/standup.md"

# Share with ONE person by email, and remove that access (idempotent)
teamyou.sh ty agent-drive grant "notes/standup.md" --email dana@example.com
teamyou.sh ty agent-drive ungrant DOC_ID --email dana@example.com

# Search (semantic + keyword + fuzzy, fused into one ranked list)
teamyou.sh ty agent-drive search "what blocked the migration"
teamyou.sh ty agent-drive search "standup" --path-prefix "memory/" --limit 5
teamyou.sh ty agent-drive search "aisle seats" high
teamyou.sh ty agent-drive search "migration plan" --scope shared
teamyou.sh ty agent-drive search "migration plan" --scope all
```

## Reading search results

- `score` is a fused relevance score, comparable **within one response only**. Rank order
  is the signal; never threshold on an absolute value or compare across calls.
- `methods` names the arms that matched (`vector`, `fts`, `trigram`). A hit found by
  several arms is stronger than one found by a single arm.
- `snippet` and `headingPath` describe the part of the document that matched, so you
  usually do not need to `pull` the whole document to judge relevance.
- `chunkIndex: 0` means the title or path matched, not the body: a weaker signal about
  the contents.
- `source` is `drive` for your own documents and `drive-shared` for one somebody granted
  your user; check it before acting on a hit as if it were yours.
- Prefer `--path-prefix` to scope a search to your own namespace (for example
  `memory/`). It is cheaper for the user and keeps you out of documents another agent
  owns.
- A document you just pushed is indexed in the background; allow a few seconds before
  expecting it in results. Deleted documents never appear.
