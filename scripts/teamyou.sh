#!/bin/bash
# TeamYou API helper script
# Handles authentication and common operations with the TeamYou API
# CLI pattern: teamyou.sh <provider> <service> <action> [args]

set -e

BASE_URL="${TEAMYOU_API_URL:-https://www.teamyou.com/api/external/v1}"
SUPPORTED_ACTION_TYPES=("check_todos" "openclaw_command" "custom_webhook")

# Distinct exit code for a `403 client_update_nudge` (the capability-aware nag,
# TYDEV-975/987) — kept OUT of the generic error code (1) so an agent can branch on
# it: this single call did not run; you must upgrade OR ack-and-retry (see SKILL.md).
# 75 = sysexits EX_TEMPFAIL ("temporary failure, retry after action").
EXIT_UPDATE_NUDGE=75

# Skill identity headers. SKILL_VERSION/SKILL_VARIANT/SKILL_VERSION_GUID are
# build-time tokens that the packaging build (scripts/build-teamyou-skill-variant.mjs)
# substitutes with concrete values; the unbuilt source keeps the literal {{...}}
# tokens, which the header guard in api_request() detects and omits so we never
# send a raw token. SKILL_VERSION_GUID is the un-fakeable per-version anchor
# (TYDEV-984); it is also omitted when empty (a build that did not mint one).
SKILL_CLIENT="ty-skill"
SKILL_VERSION="3.2.1"
SKILL_VARIANT="public"
SKILL_VERSION_GUID="vg_zdh0Z1zwyRpM"

# Get API key from environment or ~/.teamyou_key
get_api_key() {
  if [[ -n "$TEAMYOU_API_KEY" ]]; then
    printf '%s' "$TEAMYOU_API_KEY"
  elif [[ -f "$HOME/.teamyou_key" ]]; then
    tr -d '\n\r' < "$HOME/.teamyou_key"
  else
    echo "Error: No API key found. Set TEAMYOU_API_KEY env var or create ~/.teamyou_key" >&2
    exit 1
  fi
}

# The noun currently dispatching, e.g. "ty projects". Set once per dispatcher by
# ty_dispatch_begin so an argument error can point at the right help without every
# action repeating the noun (TYDEV-1184).
TY_HELP_CONTEXT="ty"

# Shared front door for every noun dispatcher (TYDEV-1184).
#
# Answers a help request at BOTH levels — `ty <noun>` with no action at all, and
# `ty <noun> <action> -h|--help` — BEFORE the action function runs, so asking a
# write action for help can never read a positional or reach api_request. Until
# this existed, `ty projects create -h` took "-h" as the project NAME and created
# a project called "-h".
#
# Only the argument IMMEDIATELY after the action counts as a help request. Scanning
# the whole argv would let a legitimate flag VALUE of "-h" (`--title -h`) silently
# turn a write into a help screen; the leading-dash backstop in require_value
# covers the remaining positional cases.
#
# Returns 0 when it printed help (the dispatcher should return), 1 to carry on.
ty_dispatch_begin() {
  TY_HELP_CONTEXT=$1
  local help_fn=$2
  shift 2

  if [[ -z "${1:-}" ]]; then
    "$help_fn"
    return 0
  fi

  case "${2:-}" in
    -h|--help)
      "$help_fn"
      return 0
      ;;
  esac

  return 1
}

require_value() {
  local option_name=$1
  local option_value=$2
  if [[ -z "$option_value" ]]; then
    echo "Error: $option_name requires a value" >&2
    exit 1
  fi
  # Backstop for the same class of bug ty_dispatch_begin fixes (TYDEV-1184): a
  # value that starts with "-" is a mistyped or misplaced flag, not content.
  # Refusing it beats storing it — a name written to the API is a record someone
  # has to find and delete. No positional or option this script accepts is
  # legitimately dash-leading (no negative numbers, no "-" stdin marker: every
  # file argument is checked with -f), so this rejects only mistakes.
  case "$option_value" in
    -*)
      echo "Error: \"$option_name\" looks like a flag, not a value: '$option_value'" >&2
      echo "Run 'teamyou.sh $TY_HELP_CONTEXT -h' for usage" >&2
      exit 1
      ;;
  esac
}

validate_action_type() {
  local action_type=$1
  local supported=false

  for current in "${SUPPORTED_ACTION_TYPES[@]}"; do
    if [[ "$current" == "$action_type" ]]; then
      supported=true
      break
    fi
  done

  if [[ "$supported" != true ]]; then
    echo "Error: Unsupported action type '$action_type'. Supported: ${SUPPORTED_ACTION_TYPES[*]}" >&2
    exit 1
  fi
}

validate_config_json() {
  local raw_json=$1

  if ! echo "$raw_json" | jq -e 'if type == "object" then . else error("config must be object") end' >/dev/null 2>&1; then
    echo "Error: --config-json must be valid JSON object" >&2
    exit 1
  fi
}

# Surface a `403 client_update_nudge` (TYDEV-975/987) WITHOUT falling to the generic
# stderr+exit-1 path — that path is invisible to an agent capturing `$(... | jq)`.
# Per the B27 nag-content principle every surface independently carries (a) how to
# upgrade, (b) how to ack/defer, and (c) the COST of acking through:
#   - STDOUT: the verbatim 403 body (the source of truth) plus the ONE derived field
#     `ack_command` — the exact CLI to deliberately defer this single call. Emitting
#     it on stdout is what makes the nudge visible to `$(teamyou.sh ... | jq ...)`.
#   - STDERR: a readable `[TeamYou] ACTION NEEDED` projection of the same facts.
# It does NOT auto-ack and does NOT retry — acking + re-running are the agent's
# deliberate decisions (see SKILL.md "Client Update Nudge"). Caller exits
# $EXIT_UPDATE_NUDGE afterward.
emit_update_nudge() {
  local body=$1

  # stdout: 403 body + derived ack_command (= "<this script> ty agent ack <token>").
  # `$0` is the script as invoked, so the command is directly runnable. Falls back to
  # the raw body if jq cannot add the field, so the agent never loses the nudge.
  printf '%s' "$body" \
    | jq --arg cmd "$0 ty agent ack" \
        '. + {ack_command: ($cmd + " " + (.ack_token // ""))}' \
    2>/dev/null \
    || printf '%s\n' "$body"

  # stderr: readable projection of the same facts (not richer than the body). Capture
  # jq's stdout into a var first, THEN write it to fd2 — redirecting jq directly with
  # `2>/dev/null >&2` would point its stdout at the just-silenced /dev/null. Fall back
  # to a one-line marker if the body cannot be parsed, so stderr is never silent.
  local rendered=""
  rendered=$(printf '%s' "$body" | jq -r '
    "[TeamYou] ACTION NEEDED: a newer TeamYou skill version is available.",
    "  running \(.verified_version // "?") -> latest \(.required_version // "?")",
    "  Upgrade (ends these reminders): \(.upgrade_url // "?")",
    "  Or defer THIS one call (deliberate, escalating): \($cmd) \(.ack_token // "")",
    "  Deferred \(.nag_acks_so_far // 0) time(s) so far; reminder returns about every \(.nag_interval // "?") calls and gets more frequent the longer you stay behind."
  ' --arg cmd "$0 ty agent ack" 2>/dev/null) || rendered=""
  if [[ -n "$rendered" ]]; then
    printf '%s\n' "$rendered" >&2
  else
    printf '[TeamYou] ACTION NEEDED: a newer TeamYou skill version is available (could not parse nudge body).\n' >&2
  fi
}

# Make an authenticated API request.
#
# This is the single transport chokepoint for the whole skill, so the UTF-8
# rules below apply to every call site at once (TYDEV-1017).
api_request() {
  local method=$1
  local path=$2
  local data=$3

  local api_key
  api_key=$(get_api_key)

  local curl_args=(
    -s -w "\n%{http_code}"
    -X "$method"
    # The URL is an argv argument and carries the same non-ASCII hazard the body
    # does (see the STDIN note below). Every path/query the callers build today is
    # ASCII; anything non-ASCII must be percent-encoded BEFORE it reaches here.
    "$BASE_URL$path"
    -H "Authorization: Bearer $api_key"
    -H "Content-Type: application/json"
    -H "X-TeamYou-Client: $SKILL_CLIENT"
  )

  # Only send version/variant once the build has substituted the tokens. The
  # unbuilt source still holds the literal {{...}}, which we must not transmit.
  case "$SKILL_VERSION" in
    *'{{'*) ;;
    *) curl_args+=(-H "X-TeamYou-Version: $SKILL_VERSION") ;;
  esac
  case "$SKILL_VARIANT" in
    *'{{'*) ;;
    *) curl_args+=(-H "X-TeamYou-Skill-Variant: $SKILL_VARIANT") ;;
  esac
  # Per-version GUID — the verified anchor (TYDEV-984). Omit when empty (a build
  # that minted no GUID) or still an unsubstituted {{...}} token.
  case "$SKILL_VERSION_GUID" in
    ''|*'{{'*) ;;
    *) curl_args+=(-H "X-TeamYou-Version-Guid: $SKILL_VERSION_GUID") ;;
  esac

  # Hand the body to curl on STDIN, never as argv (TYDEV-1017).
  #
  # On Windows, Git Bash/MSYS invokes a NATIVE curl.exe, so argv crosses a Win32
  # boundary that re-encodes the string into the process ANSI code page. Every
  # multibyte character either collapses to one unmappable byte the server then
  # decodes as U+FFFD (em dash -> CP1252 0x97) or, when the code page has no
  # equivalent at all, is replaced outright by "?" (CJK, emoji) — silent, total
  # loss of the original character. A pipe is a raw byte stream with no such
  # boundary. POSIX argv is byte-transparent either way, so this is correct on
  # macOS/Linux too, just not load-bearing there.
  #
  # --data-binary, not -d: in the `@` (file/stdin) form, `-d` strips CR and LF
  # out of what it reads. jq escapes newlines inside JSON strings, so nothing
  # depends on that today, but --data-binary is byte-exact and leaves no trap
  # for a future caller.
  #
  # curl cannot re-read STDIN, so do NOT add -L/--location or --retry to
  # curl_args while the body arrives this way — a redirect or a retry would
  # resend an empty body. Use a temp file with `--data-binary @file` if that
  # ever becomes a requirement.
  local response
  if [[ -n "$data" ]]; then
    curl_args+=(--data-binary @-)
    response=$(printf '%s' "$data" | curl "${curl_args[@]}")
  else
    response=$(curl "${curl_args[@]}")
  fi

  local http_code
  http_code=$(echo "$response" | tail -n1)
  local body
  body=$(echo "$response" | sed '$d')

  if [[ "$http_code" -ge 400 ]]; then
    # The capability-aware nag (TYDEV-975/987) is a 403 whose `code` is
    # `client_update_nudge`. It must NOT use the generic stderr+exit-1 path below
    # (invisible to `$(... | jq)`): emit the 403 facts + a derived ack_command on
    # STDOUT, a readable nudge on stderr, and a DISTINCT exit code so the agent can
    # branch and ack-or-upgrade. Never auto-ack (that defeats the capability probe).
    if echo "$body" | jq -e 'type == "object" and .code == "client_update_nudge"' >/dev/null 2>&1; then
      emit_update_nudge "$body"
      exit "$EXIT_UPDATE_NUDGE"
    fi
    # When the API returns a machine-readable `code` (e.g. agent_not_registered
    # or skill_update_required from the registration gate), surface the FULL body
    # so the agent can self-heal — it carries registerUrl / install_url and the
    # exact code to act on. Otherwise just print the human-readable error.
    if echo "$body" | jq -e 'type == "object" and has("code")' >/dev/null 2>&1; then
      echo "$body" | jq '.' >&2
    else
      echo "$body" | jq -r '.error // .' >&2
    fi
    exit 1
  fi

  # Surface the server's advisory skill-update notice (TYDEV-865) on a SECOND
  # channel — stderr — so it survives stdout piping/filtering such as `| jq`,
  # which drops the top-level agent_ecosystem_notice field. We print the
  # recommended_action plus the install_url when present (TYDEV-971), behind a
  # non-JSON [TeamYou] marker, keeping stdout pure JSON. The jq filter guards
  # every level (object body, object notice, string action) and collapses any
  # whitespace runs so the marker is always a single stderr line. Best-effort and
  # non-fatal: a missing/odd notice or jq hiccup must never fail an
  # otherwise-successful request (exit stays 0).
  local notice=""
  notice=$(printf '%s' "$body" | jq -r '
    if type == "object" and (.agent_ecosystem_notice | type) == "object"
    then .agent_ecosystem_notice else empty end
    | if (.recommended_action | type) == "string"
      then (.recommended_action | gsub("[[:space:]]+"; " "))
           + ( if (.install_url | type) == "string"
               then " (update: " + .install_url + ")" else "" end )
      else empty end
  ' 2>/dev/null) || notice=""
  if [[ -n "$notice" ]]; then
    printf '[TeamYou] %s\n' "$notice" >&2
  fi

  echo "$body"
}

# ============================================================================
# ty graph — Topics, Details, Edges, Search
# ============================================================================

topics_list() {
  api_request GET /topics
}

topics_create() {
  local name="" description="" summary=""

  while [[ $# -gt 0 ]]; do
    case $1 in
      --summary) summary=$2; shift 2 ;;
      *)
        if [[ -z "$name" ]]; then
          name=$1; shift
        elif [[ -z "$description" ]]; then
          description=$1; shift
        else
          echo "Unknown option: $1" >&2; exit 1
        fi
        ;;
    esac
  done

  require_value "name" "$name"

  local data
  data=$(jq -n \
    --arg name "$name" \
    --arg desc "$description" \
    --arg summary "$summary" \
    '{name: $name, oneSentenceDescription: $desc}
    | if $summary != "" then . + {summary: $summary} else . end')

  api_request POST /topics "$data"
}

topics_get() {
  local topic_id=$1
  require_value "topic_id" "$topic_id"
  api_request GET "/topics/$topic_id"
}

topics_update() {
  local topic_id=$1
  shift || true
  require_value "topic_id" "$topic_id"

  local name="" description="" summary=""

  while [[ $# -gt 0 ]]; do
    case $1 in
      --name) name=$2; shift 2 ;;
      --description) description=$2; shift 2 ;;
      --summary) summary=$2; shift 2 ;;
      *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
  done

  local data
  data=$(jq -n \
    --arg name "$name" \
    --arg desc "$description" \
    --arg summary "$summary" \
    '{}
    | if $name != "" then . + {name: $name} else . end
    | if $desc != "" then . + {oneSentenceDescription: $desc} else . end
    | if $summary != "" then . + {summary: $summary} else . end')

  api_request PUT "/topics/$topic_id" "$data"
}

topics_delete() {
  local topic_id=$1
  require_value "topic_id" "$topic_id"
  api_request DELETE "/topics/$topic_id"
}

details_list() {
  local topic_id=$1
  require_value "topic_id" "$topic_id"
  api_request GET "/topics/$topic_id/details"
}

details_add() {
  local topic_id=$1
  shift || true
  require_value "topic_id" "$topic_id"
  local details=("$@")

  # details-add takes no flags at all, so every remaining argument is detail
  # text. A dash-leading one is a mistyped flag, never content (TYDEV-1184).
  local detail
  for detail in "${details[@]}"; do
    require_value "detail" "$detail"
  done

  local data
  data=$(jq -n --args '$ARGS.positional | map({detail: .})' "${details[@]}" | jq '{details: .}')

  api_request POST "/topics/$topic_id/details" "$data"
}

details_update() {
  local topic_id=$1
  local detail_id=$2
  local text=$3
  require_value "topic_id" "$topic_id"
  require_value "detail_id" "$detail_id"
  require_value "detail" "$text"

  local data
  data=$(jq -n --arg text "$text" '{detail: $text}')

  api_request PUT "/topics/$topic_id/details/$detail_id" "$data"
}

details_delete() {
  local topic_id=$1
  local detail_id=$2
  require_value "topic_id" "$topic_id"
  require_value "detail_id" "$detail_id"
  api_request DELETE "/topics/$topic_id/details/$detail_id"
}

# List edges for a topic (both directions, all labels).
# Usage:
#   edges-list TOPIC_ID
edges_list() {
  local topic_id=$1
  require_value "topic_id" "$topic_id"
  api_request GET "/edges?topicId=$topic_id"
}

# Create an edge between two topics.
# Usage:
#   edges-create SOURCE_TOPIC_ID TARGET_TOPIC_ID "label" [--mirror-label "inverse label"]
edges_create() {
  if [[ $# -lt 3 ]]; then
    echo "Usage: teamyou.sh ty graph edges-create <source_topic_id> <target_topic_id> <label> [--mirror-label <text>]" >&2
    exit 1
  fi

  local source_topic_id=$1
  local target_topic_id=$2
  local label=$3
  shift 3

  require_value "source_topic_id" "$source_topic_id"
  require_value "target_topic_id" "$target_topic_id"
  require_value "label" "$label"

  if [[ "$source_topic_id" == "$target_topic_id" ]]; then
    echo "Error: source_topic_id and target_topic_id must be different" >&2
    exit 1
  fi

  local mirror_label="$label"

  while [[ $# -gt 0 ]]; do
    case $1 in
      --mirror-label)
        require_value "--mirror-label" "${2:-}"
        mirror_label=$2
        shift 2
        ;;
      *)
        echo "Unknown option: $1" >&2
        exit 1
        ;;
    esac
  done

  local data
  data=$(jq -n \
    --arg sourceTopicId "$source_topic_id" \
    --arg targetTopicId "$target_topic_id" \
    --arg label "$label" \
    --arg mirrorLabel "$mirror_label" \
    '{
      sourceTopicId: $sourceTopicId,
      targetTopicId: $targetTopicId,
      label: $label,
      mirrorLabel: $mirrorLabel
    }')

  api_request POST "/edges" "$data"
}

# Update edge labels (only label and/or mirrorLabel are mutable).
# Usage:
#   edges-update EDGE_ID [--label <text>] [--mirror-label <text>]
edges_update() {
  local edge_id=$1
  shift
  require_value "edge_id" "$edge_id"

  local label=""
  local mirror_label=""
  local has_label=false
  local has_mirror=false

  while [[ $# -gt 0 ]]; do
    case $1 in
      --label)
        require_value "--label" "${2:-}"
        label=$2
        has_label=true
        shift 2
        ;;
      --mirror-label)
        require_value "--mirror-label" "${2:-}"
        mirror_label=$2
        has_mirror=true
        shift 2
        ;;
      *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
  done

  if [[ "$has_label" != true && "$has_mirror" != true ]]; then
    echo "Error: at least one of --label or --mirror-label must be provided" >&2
    exit 1
  fi

  local data
  data=$(jq -n \
    --arg label "$label" \
    --arg mirrorLabel "$mirror_label" \
    --argjson hasLabel "$has_label" \
    --argjson hasMirror "$has_mirror" \
    '{}
    | if $hasLabel then . + {label: $label} else . end
    | if $hasMirror then . + {mirrorLabel: $mirrorLabel} else . end')

  api_request PATCH "/edges/$edge_id" "$data"
}

# Delete an edge.
# Usage:
#   edges-delete EDGE_ID
edges_delete() {
  local edge_id=$1
  require_value "edge_id" "$edge_id"
  api_request DELETE "/edges/$edge_id"
}

# Backward-compatible alias for edges-create.
# The new edges table makes a single row cover both directions, so a single
# POST /edges call replaces what previously took two mirrored detail records.
edges_link() {
  edges_create "$@"
}

search_topics() {
  local query=$1
  local precision=${2:-medium}
  require_value "query" "$query"

  local data
  data=$(jq -n --arg query "$query" --arg precision "$precision" '{query: $query, precision: $precision}')

  api_request POST /search/topics "$data"
}

search_details() {
  local query=$1
  local precision=${2:-medium}
  require_value "query" "$query"

  local data
  data=$(jq -n --arg query "$query" --arg precision "$precision" '{query: $query, precision: $precision}')

  api_request POST /search/details "$data"
}

dispatch_ty_graph() {
  ty_dispatch_begin "ty graph" show_ty_graph_help "$@" && return 0
  local action=$1
  shift

  case "$action" in
    topics-list) topics_list "$@" ;;
    topics-create) topics_create "$@" ;;
    topics-get) topics_get "$@" ;;
    topics-update) topics_update "$@" ;;
    topics-delete) topics_delete "$@" ;;
    details-list) details_list "$@" ;;
    details-add) details_add "$@" ;;
    edges-link) edges_link "$@" ;;
    edges-create) edges_create "$@" ;;
    edges-list) edges_list "$@" ;;
    edges-update) edges_update "$@" ;;
    edges-delete) edges_delete "$@" ;;
    details-update) details_update "$@" ;;
    details-delete) details_delete "$@" ;;
    search-topics) search_topics "$@" ;;
    search-details) search_details "$@" ;;
    -h|--help) show_ty_graph_help ;;
    *) echo "Unknown ty graph action: $action" >&2; echo "Run 'teamyou.sh ty graph -h' for usage" >&2; exit 1 ;;
  esac
}

# ============================================================================
# ty todos — Todo management
# ============================================================================

todos_list() {
  local params=""

  while [[ $# -gt 0 ]]; do
    case $1 in
      --status) params="${params}&status=$2"; shift 2 ;;
      --archived) params="${params}&archived=true"; shift ;;
      --priority) params="${params}&priority=$2"; shift 2 ;;
      --order-by) params="${params}&orderBy=$2"; shift 2 ;;
      --limit) params="${params}&limit=$2"; shift 2 ;;
      *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
  done

  params="${params#&}"
  if [[ -n "$params" ]]; then
    params="?$params"
  fi

  api_request GET "/todos$params"
}

todos_create() {
  local title=$1
  shift || true
  require_value "title" "$title"

  local description="" status="" priority="" due_date="" topic_id="" project_id="" after="" before=""

  while [[ $# -gt 0 ]]; do
    case $1 in
      --description) description=$2; shift 2 ;;
      --status) status=$2; shift 2 ;;
      --priority) priority=$2; shift 2 ;;
      --due-date) due_date=$2; shift 2 ;;
      --topic-id)
        if [[ $# -lt 2 || "$2" == -* ]]; then
          echo "Error: --topic-id requires a value" >&2
          exit 1
        fi
        topic_id=$2
        shift 2
        ;;
      --project-id)
        if [[ $# -lt 2 || "$2" == -* ]]; then
          echo "Error: --project-id requires a value" >&2
          exit 1
        fi
        project_id=$2
        shift 2
        ;;
      --after) after=$2; shift 2 ;;
      --before) before=$2; shift 2 ;;
      *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
  done

  local data
  data=$(jq -n \
    --arg title "$title" \
    --arg desc "$description" \
    --arg status "$status" \
    --arg priority "$priority" \
    --arg due "$due_date" \
    --arg topic "$topic_id" \
    --arg project "$project_id" \
    --arg after "$after" \
    --arg before "$before" \
    '{title: $title}
    | if $desc != "" then . + {description: $desc} else . end
    | if $status != "" then . + {status: $status} else . end
    | if $priority != "" then . + {priority: $priority} else . end
    | if $due != "" then . + {dueDate: $due} else . end
    | if $topic != "" then . + {topicId: $topic} else . end
    | if $project != "" then . + {projectId: $project} else . end
    | if ($after != "" or $before != "") then . + {position: (
        {}
        | if $after != "" then . + {after: $after} else . end
        | if $before != "" then . + {before: $before} else . end
      )} else . end')

  api_request POST /todos "$data"
}

todos_get() {
  local todo_id=$1
  require_value "todo_id" "$todo_id"
  api_request GET "/todos/$todo_id"
}

todos_update() {
  local todo_id=$1
  shift || true
  require_value "todo_id" "$todo_id"

  local title="" description="" status="" priority="" due_date="" archived="" topic_id="" clear_topic=""
  local project_id="" clear_project="" after="" before=""

  while [[ $# -gt 0 ]]; do
    case $1 in
      --title) title=$2; shift 2 ;;
      --description) description=$2; shift 2 ;;
      --status) status=$2; shift 2 ;;
      --priority) priority=$2; shift 2 ;;
      --due-date) due_date=$2; shift 2 ;;
      --archived) archived="true"; shift ;;
      --topic-id)
        if [[ $# -lt 2 || "$2" == -* ]]; then
          echo "Error: --topic-id requires a value" >&2
          exit 1
        fi
        topic_id=$2
        shift 2
        ;;
      --no-topic) clear_topic="true"; shift ;;
      --project-id)
        if [[ $# -lt 2 || "$2" == -* ]]; then
          echo "Error: --project-id requires a value" >&2
          exit 1
        fi
        project_id=$2
        shift 2
        ;;
      --no-project) clear_project="true"; shift ;;
      --after) after=$2; shift 2 ;;
      --before) before=$2; shift 2 ;;
      *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
  done

  local data
  data=$(jq -n \
    --arg title "$title" \
    --arg desc "$description" \
    --arg status "$status" \
    --arg priority "$priority" \
    --arg due "$due_date" \
    --arg archived "$archived" \
    --arg topic "$topic_id" \
    --arg clearTopic "$clear_topic" \
    --arg project "$project_id" \
    --arg clearProject "$clear_project" \
    --arg after "$after" \
    --arg before "$before" \
    '{}
    | if $title != "" then . + {title: $title} else . end
    | if $desc != "" then . + {description: $desc} else . end
    | if $status != "" then . + {status: $status} else . end
    | if $priority != "" then . + {priority: $priority} else . end
    | if $due != "" then . + {dueDate: $due} else . end
    | if $archived == "true" then . + {isArchived: true} else . end
    | if $topic != "" then . + {topicId: $topic}
      elif $clearTopic == "true" then . + {topicId: null}
      else . end
    | if $project != "" then . + {projectId: $project}
      elif $clearProject == "true" then . + {projectId: null}
      else . end
    | if ($after != "" or $before != "") then . + {position: (
        {}
        | if $after != "" then . + {after: $after} else . end
        | if $before != "" then . + {before: $before} else . end
      )} else . end')

  api_request PUT "/todos/$todo_id" "$data"
}

todos_delete() {
  local todo_id=$1
  require_value "todo_id" "$todo_id"
  api_request DELETE "/todos/$todo_id"
}

todos_complete() {
  local todo_id=$1
  require_value "todo_id" "$todo_id"
  api_request POST "/todos/$todo_id/complete"
}

dispatch_ty_todos() {
  ty_dispatch_begin "ty todos" show_ty_todos_help "$@" && return 0
  local action=$1
  shift

  case "$action" in
    list) todos_list "$@" ;;
    create) todos_create "$@" ;;
    get) todos_get "$@" ;;
    update) todos_update "$@" ;;
    delete) todos_delete "$@" ;;
    complete) todos_complete "$@" ;;
    -h|--help) show_ty_todos_help ;;
    *) echo "Unknown ty todos action: $action" >&2; echo "Run 'teamyou.sh ty todos -h' for usage" >&2; exit 1 ;;
  esac
}

# ============================================================================
# ty projects — Projects, plans, and references (TYDEV-1023)
# ============================================================================

projects_list() {
  local params=""

  while [[ $# -gt 0 ]]; do
    case $1 in
      --status) params="${params}&status=$2"; shift 2 ;;
      --limit) params="${params}&limit=$2"; shift 2 ;;
      *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
  done

  params="${params#&}"
  if [[ -n "$params" ]]; then
    params="?$params"
  fi

  api_request GET "/projects$params"
}

# Create a project, optionally carrying its plan and references in the SAME
# call. The API writes everything in one transaction, so a failure anywhere
# creates nothing - there is no half-built project to clean up.
#
# --todo and --ref are repeatable and FLAG ORDER IS THE ORDER; there are no
# per-item positions. --ref takes <type>:<value>, e.g. topic:abc123 or
# url:https://example.com; it cannot point at a --todo from the same call
# because those ids do not exist yet (add those with refs-add afterwards).
#
# --from-json <file> is a client-side convenience only: the file is merged OVER
# the flag-built body and posted as the same JSON, which is how per-todo
# status/priority/dueDate/topicId are reached without a flag for each. The API
# gains no file surface.
#
# Create-only: there is no upsert or dedupe, so running this twice makes two
# projects.
projects_create() {
  local name=$1
  shift
  require_value "name" "$name"

  local goal="" status="" waiting_on="" notes="" due_date="" from_json=""
  local todos_json="[]" refs_json="[]"
  local ref_spec ref_type ref_value

  while [[ $# -gt 0 ]]; do
    case $1 in
      --goal) goal=$2; shift 2 ;;
      --status) status=$2; shift 2 ;;
      --waiting-on) waiting_on=$2; shift 2 ;;
      --notes) notes=$2; shift 2 ;;
      --due-date) due_date=$2; shift 2 ;;
      --todo)
        todos_json=$(jq -c --arg title "$2" '. + [{title: $title}]' <<<"$todos_json")
        shift 2 ;;
      --ref)
        ref_spec=$2
        if [[ "$ref_spec" != *:* ]]; then
          echo "Error: --ref must be <type>:<value>, e.g. topic:abc123 or url:https://example.com" >&2
          exit 1
        fi
        ref_type=${ref_spec%%:*}
        ref_value=${ref_spec#*:}
        if [[ -z "$ref_value" ]]; then
          echo "Error: --ref value is empty in '$ref_spec'" >&2
          exit 1
        fi
        case "$ref_type" in
          topic|todo|project|doc)
            refs_json=$(jq -c --arg tt "$ref_type" --arg id "$ref_value" \
              '. + [{targetType: $tt, targetId: $id}]' <<<"$refs_json") ;;
          url)
            refs_json=$(jq -c --arg url "$ref_value" \
              '. + [{targetType: "url", url: $url}]' <<<"$refs_json") ;;
          *)
            echo "Error: unknown --ref type '$ref_type'. Accepted: topic, todo, project, doc, url" >&2
            exit 1 ;;
        esac
        shift 2 ;;
      --from-json) from_json=$2; shift 2 ;;
      *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
  done

  local data
  data=$(jq -n \
    --arg name "$name" \
    --arg goal "$goal" \
    --arg status "$status" \
    --arg waiting "$waiting_on" \
    --arg notes "$notes" \
    --arg dueDate "$due_date" \
    --argjson todos "$todos_json" \
    --argjson refs "$refs_json" \
    '{name: $name}
    | if $goal != "" then . + {goal: $goal} else . end
    | if $status != "" then . + {status: $status} else . end
    | if $waiting != "" then . + {waitingOn: $waiting} else . end
    | if $notes != "" then . + {notes: $notes} else . end
    | if $dueDate != "" then . + {dueDate: $dueDate} else . end
    | if ($todos | length) > 0 then . + {todos: $todos} else . end
    | if ($refs | length) > 0 then . + {refs: $refs} else . end')

  if [[ -n "$from_json" ]]; then
    if [[ ! -f "$from_json" ]]; then
      echo "Error: file not found: $from_json" >&2
      exit 1
    fi
    # The file wins: `*` merges objects recursively and REPLACES arrays, so a
    # file that carries todos/refs supersedes the flag-built ones outright
    # rather than appending to them.
    data=$(printf '%s' "$data" | jq --slurpfile extra "$from_json" '. * $extra[0]')
  fi

  api_request POST /projects "$data"
}

projects_get() {
  local project_id=$1
  require_value "project_id" "$project_id"
  api_request GET "/projects/$project_id"
}

projects_update() {
  local project_id=$1
  shift
  require_value "project_id" "$project_id"

  local name="" goal="" status="" waiting_on="" notes="" due_date=""
  local clear_goal="" clear_waiting="" clear_notes="" clear_due_date=""

  while [[ $# -gt 0 ]]; do
    case $1 in
      --name) name=$2; shift 2 ;;
      --goal) goal=$2; shift 2 ;;
      --status) status=$2; shift 2 ;;
      --waiting-on) waiting_on=$2; shift 2 ;;
      --notes) notes=$2; shift 2 ;;
      --due-date) due_date=$2; shift 2 ;;
      --no-goal) clear_goal="true"; shift ;;
      --no-waiting-on) clear_waiting="true"; shift ;;
      --no-notes) clear_notes="true"; shift ;;
      --no-due-date) clear_due_date="true"; shift ;;
      *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
  done

  local data
  data=$(jq -n \
    --arg name "$name" \
    --arg goal "$goal" \
    --arg status "$status" \
    --arg waiting "$waiting_on" \
    --arg notes "$notes" \
    --arg dueDate "$due_date" \
    --arg clearGoal "$clear_goal" \
    --arg clearWaiting "$clear_waiting" \
    --arg clearNotes "$clear_notes" \
    --arg clearDueDate "$clear_due_date" \
    '{}
    | if $name != "" then . + {name: $name} else . end
    | if $goal != "" then . + {goal: $goal}
      elif $clearGoal == "true" then . + {goal: null}
      else . end
    | if $status != "" then . + {status: $status} else . end
    | if $waiting != "" then . + {waitingOn: $waiting}
      elif $clearWaiting == "true" then . + {waitingOn: null}
      else . end
    | if $notes != "" then . + {notes: $notes}
      elif $clearNotes == "true" then . + {notes: null}
      else . end
    | if $dueDate != "" then . + {dueDate: $dueDate}
      elif $clearDueDate == "true" then . + {dueDate: null}
      else . end')

  api_request PUT "/projects/$project_id" "$data"
}

projects_delete() {
  local project_id=$1
  require_value "project_id" "$project_id"
  api_request DELETE "/projects/$project_id"
}

projects_refs_add() {
  local project_id=$1
  shift
  require_value "project_id" "$project_id"

  local target_type="" target_id="" url="" title="" after="" before=""

  while [[ $# -gt 0 ]]; do
    case $1 in
      --target-type) target_type=$2; shift 2 ;;
      --target-id) target_id=$2; shift 2 ;;
      --url) url=$2; shift 2 ;;
      --title) title=$2; shift 2 ;;
      --after) after=$2; shift 2 ;;
      --before) before=$2; shift 2 ;;
      *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
  done

  require_value "--target-type" "$target_type"

  local data
  data=$(jq -n \
    --arg tt "$target_type" \
    --arg tid "$target_id" \
    --arg url "$url" \
    --arg title "$title" \
    --arg after "$after" \
    --arg before "$before" \
    '{target: (
        {targetType: $tt}
        | if $tt == "url" then . + {url: $url} else . + {targetId: $tid} end
        | if $title != "" then . + {title: $title} else . end
      )}
    | if ($after != "" or $before != "") then . + {position: (
        {}
        | if $after != "" then . + {after: $after} else . end
        | if $before != "" then . + {before: $before} else . end
      )} else . end')

  api_request POST "/projects/$project_id/refs" "$data"
}

# Write a markdown document from a local file and link it to a project in one
# call.
#
# Document paths are GLOBAL per user, not scoped to a project: re-pushing a path
# replaces that one document everywhere it is referenced. A bare basename would
# therefore make two projects pushing "notes.md" share (and silently overwrite)
# a single document, so the default path is namespaced by project id:
# projects/<project_id>/<basename>. --path overrides it verbatim -- pass the
# same --path from two projects only when you WANT one shared document.
#
# Document title defaults to the file's basename (or, when --path is given, to
# that path). --ref-title sets an optional label on the reference itself.
projects_doc_push() {
  local project_id=$1
  local file=${2:-}
  shift 2 || true
  require_value "project_id" "$project_id"
  require_value "file" "$file"

  local path="" title="" ref_title="" after="" before=""

  while [[ $# -gt 0 ]]; do
    case $1 in
      --path) path=$2; shift 2 ;;
      --title) title=$2; shift 2 ;;
      --ref-title) ref_title=$2; shift 2 ;;
      --after) after=$2; shift 2 ;;
      --before) before=$2; shift 2 ;;
      *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
  done

  if [[ ! -f "$file" ]]; then
    echo "Error: file not found: $file" >&2
    exit 1
  fi
  local base
  base=$(basename "$file")
  if [[ -z "$path" ]]; then
    # Namespace the default so same-named files pushed from different projects
    # do not collide on one global document (see the note above).
    path="projects/$project_id/$base"
    if [[ -z "$title" ]]; then title="$base"; fi
  fi
  if [[ -z "$title" ]]; then title="$path"; fi

  # --rawfile reads the file verbatim (preserving trailing newlines) so the
  # stored content byte-matches the local file; command substitution would
  # strip trailing newlines and break a doc-push / drive pull round trip.
  local data
  data=$(jq -n \
    --arg title "$title" \
    --arg path "$path" \
    --rawfile content "$file" \
    --arg refTitle "$ref_title" \
    --arg after "$after" \
    --arg before "$before" \
    '{document: {title: $title, path: $path, content: $content}}
    | if $refTitle != "" then . + {title: $refTitle} else . end
    | if ($after != "" or $before != "") then . + {position: (
        {}
        | if $after != "" then . + {after: $after} else . end
        | if $before != "" then . + {before: $before} else . end
      )} else . end')

  api_request POST "/projects/$project_id/documents" "$data"
}

projects_refs_remove() {
  local project_id=$1
  local ref_id=$2
  require_value "project_id" "$project_id"
  require_value "ref_id" "$ref_id"
  api_request DELETE "/projects/$project_id/refs/$ref_id"
}

projects_refs_reorder() {
  local project_id=$1
  local ref_id=$2
  shift 2 || true
  require_value "project_id" "$project_id"
  require_value "ref_id" "$ref_id"

  local after="" before=""

  while [[ $# -gt 0 ]]; do
    case $1 in
      --after) after=$2; shift 2 ;;
      --before) before=$2; shift 2 ;;
      *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
  done

  local data
  data=$(jq -n \
    --arg after "$after" \
    --arg before "$before" \
    '{}
    | if $after != "" then . + {after: $after} else . end
    | if $before != "" then . + {before: $before} else . end')

  api_request PATCH "/projects/$project_id/refs/$ref_id" "$data"
}

dispatch_ty_projects() {
  ty_dispatch_begin "ty projects" show_ty_projects_help "$@" && return 0
  local action=$1
  shift

  case "$action" in
    list) projects_list "$@" ;;
    create) projects_create "$@" ;;
    get) projects_get "$@" ;;
    update) projects_update "$@" ;;
    delete) projects_delete "$@" ;;
    refs-add) projects_refs_add "$@" ;;
    doc-push) projects_doc_push "$@" ;;
    refs-remove) projects_refs_remove "$@" ;;
    refs-reorder) projects_refs_reorder "$@" ;;
    -h|--help) show_ty_projects_help ;;
    *) echo "Unknown ty projects action: $action" >&2; echo "Run 'teamyou.sh ty projects -h' for usage" >&2; exit 1 ;;
  esac
}

# ============================================================================
# ty areas — Cross-pillar contexts, membership, and rollup (TYDEV-1024)
# ============================================================================

areas_list() {
  local params=""

  while [[ $# -gt 0 ]]; do
    case $1 in
      --include-archived) params="${params}&includeArchived=true"; shift ;;
      --limit) params="${params}&limit=$2"; shift 2 ;;
      *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
  done

  params="${params#&}"
  if [[ -n "$params" ]]; then
    params="?$params"
  fi

  api_request GET "/areas$params"
}

areas_create() {
  local name=$1
  shift
  require_value "name" "$name"

  local description="" archived=""

  while [[ $# -gt 0 ]]; do
    case $1 in
      --description) description=$2; shift 2 ;;
      --archived) archived="true"; shift ;;
      *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
  done

  local data
  data=$(jq -n \
    --arg name "$name" \
    --arg description "$description" \
    --arg archived "$archived" \
    '{name: $name}
    | if $description != "" then . + {description: $description} else . end
    | if $archived == "true" then . + {isArchived: true} else . end')

  api_request POST /areas "$data"
}

areas_get() {
  local area_id=$1
  shift || true
  require_value "area_id" "$area_id"

  local depth=""

  while [[ $# -gt 0 ]]; do
    case $1 in
      --depth) depth=$2; shift 2 ;;
      *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
  done

  local params=""
  if [[ -n "$depth" ]]; then
    params="?depth=$depth"
  fi

  api_request GET "/areas/$area_id$params"
}

areas_update() {
  local area_id=$1
  shift
  require_value "area_id" "$area_id"

  local name="" description="" clear_description="" archived="" no_archived=""

  while [[ $# -gt 0 ]]; do
    case $1 in
      --name) name=$2; shift 2 ;;
      --description) description=$2; shift 2 ;;
      --no-description) clear_description="true"; shift ;;
      --archived) archived="true"; shift ;;
      --no-archived) no_archived="true"; shift ;;
      *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
  done

  local data
  data=$(jq -n \
    --arg name "$name" \
    --arg description "$description" \
    --arg clearDescription "$clear_description" \
    --arg archived "$archived" \
    --arg noArchived "$no_archived" \
    '{}
    | if $name != "" then . + {name: $name} else . end
    | if $description != "" then . + {description: $description}
      elif $clearDescription == "true" then . + {description: null}
      else . end
    | if $archived == "true" then . + {isArchived: true}
      elif $noArchived == "true" then . + {isArchived: false}
      else . end')

  api_request PUT "/areas/$area_id" "$data"
}

areas_delete() {
  local area_id=$1
  require_value "area_id" "$area_id"
  api_request DELETE "/areas/$area_id"
}

areas_refs_add() {
  local area_id=$1
  shift
  require_value "area_id" "$area_id"

  local target_type="" target_id="" url="" title="" after="" before=""

  while [[ $# -gt 0 ]]; do
    case $1 in
      --target-type) target_type=$2; shift 2 ;;
      --target-id) target_id=$2; shift 2 ;;
      --url) url=$2; shift 2 ;;
      --title) title=$2; shift 2 ;;
      --after) after=$2; shift 2 ;;
      --before) before=$2; shift 2 ;;
      *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
  done

  require_value "--target-type" "$target_type"

  local data
  data=$(jq -n \
    --arg tt "$target_type" \
    --arg tid "$target_id" \
    --arg url "$url" \
    --arg title "$title" \
    --arg after "$after" \
    --arg before "$before" \
    '{target: (
        {targetType: $tt}
        | if $tt == "url" then . + {url: $url} else . + {targetId: $tid} end
        | if $title != "" then . + {title: $title} else . end
      )}
    | if ($after != "" or $before != "") then . + {position: (
        {}
        | if $after != "" then . + {after: $after} else . end
        | if $before != "" then . + {before: $before} else . end
      )} else . end')

  api_request POST "/areas/$area_id/refs" "$data"
}

areas_refs_remove() {
  local area_id=$1
  local ref_id=$2
  require_value "area_id" "$area_id"
  require_value "ref_id" "$ref_id"
  api_request DELETE "/areas/$area_id/refs/$ref_id"
}

areas_refs_reorder() {
  local area_id=$1
  local ref_id=$2
  shift 2 || true
  require_value "area_id" "$area_id"
  require_value "ref_id" "$ref_id"

  local after="" before=""

  while [[ $# -gt 0 ]]; do
    case $1 in
      --after) after=$2; shift 2 ;;
      --before) before=$2; shift 2 ;;
      *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
  done

  local data
  data=$(jq -n \
    --arg after "$after" \
    --arg before "$before" \
    '{}
    | if $after != "" then . + {after: $after} else . end
    | if $before != "" then . + {before: $before} else . end')

  api_request PATCH "/areas/$area_id/refs/$ref_id" "$data"
}

dispatch_ty_areas() {
  ty_dispatch_begin "ty areas" show_ty_areas_help "$@" && return 0
  local action=$1
  shift

  case "$action" in
    list) areas_list "$@" ;;
    create) areas_create "$@" ;;
    get) areas_get "$@" ;;
    update) areas_update "$@" ;;
    delete) areas_delete "$@" ;;
    refs-add) areas_refs_add "$@" ;;
    refs-remove) areas_refs_remove "$@" ;;
    refs-reorder) areas_refs_reorder "$@" ;;
    -h|--help) show_ty_areas_help ;;
    *) echo "Unknown ty areas action: $action" >&2; echo "Run 'teamyou.sh ty areas -h' for usage" >&2; exit 1 ;;
  esac
}

# ============================================================================
# ty agent — Agent registration & identity
# ============================================================================

# Register (or refresh) this agent's identity record. Idempotent on the slug:
# re-running with the same slug updates the same agent and attaches a rotated
# key to it. The record is display-only — the API key remains the auth boundary.
agent_register() {
  local slug="${TEAMYOU_AGENT_SLUG:-}"
  local openclaw_instance_id="${TEAMYOU_OPENCLAW_INSTANCE_ID:-}"
  local slug_explicit="false"
  local kind=""
  local display_name=""
  local model=""
  local data=""

  while [[ $# -gt 0 ]]; do
    case $1 in
      --slug) slug=$2; slug_explicit="true"; shift 2 ;;
      --openclaw-instance-id) openclaw_instance_id=$2; shift 2 ;;
      --kind) kind=$2; shift 2 ;;
      --name) display_name=$2; shift 2 ;;
      --model) model=$2; shift 2 ;;
      *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
  done

  if [[ -n "$openclaw_instance_id" ]]; then
    if [[ "$slug_explicit" == "true" || -n "$kind" || -n "$display_name" ]]; then
      echo "--openclaw-instance-id cannot be combined with --slug, --kind, or --name" >&2
      exit 1
    fi

    data=$(jq -n \
      --arg instance_id "$openclaw_instance_id" \
      --arg model "$model" \
      '{openclawInstanceId: $instance_id}
      | if $model != "" then . + {model: $model} else . end')

    api_request POST /agents/register "$data"
    return
  fi

  require_value "--slug (or TEAMYOU_AGENT_SLUG)" "$slug"

  data=$(jq -n \
    --arg slug "$slug" \
    --arg kind "$kind" \
    --arg name "$display_name" \
    --arg model "$model" \
    '{slug: $slug}
    | if $kind != "" then . + {kind: $kind} else . end
    | if $name != "" then . + {displayName: $name} else . end
    | if $model != "" then . + {model: $model} else . end')

  api_request POST /agents/register "$data"
}

# Show this key's registered agent (status + last-seen manifest), or null.
agent_whoami() {
  api_request GET /agents/me
}

# Acknowledge a client_update_nudge: consume the one-time token to relent THIS one
# call for this key (TYDEV-975/987). The token comes from the nudge body's
# `ack_token` (also embedded in `ack_command`). A deliberate defer — it is logged,
# escalates, and is visible to the owner; prefer upgrading. The ack endpoint is bare
# `requireApiKey` (not nag-gated) so this call is never itself re-nagged. After it
# succeeds, re-run your original command.
agent_ack() {
  local token=$1
  require_value "ack token" "$token"
  api_request GET "/agents/ack?token=$token"
}

dispatch_ty_agent() {
  ty_dispatch_begin "ty agent" show_ty_agent_help "$@" && return 0
  local action=$1
  shift

  case "$action" in
    register) agent_register "$@" ;;
    whoami) agent_whoami "$@" ;;
    ack) agent_ack "$@" ;;
    -h|--help) show_ty_agent_help ;;
    *) echo "Unknown ty agent action: $action" >&2; echo "Run 'teamyou.sh ty agent -h' for usage" >&2; exit 1 ;;
  esac
}

# ============================================================================
# ty agent-drive — TY Agent Drive documents, markdown today
# (list/read/write/delete/restore/share). Delete is recoverable: it archives the
# document, 'list --archived' finds it and 'restore' brings it back.
# Sharing is document STATE, not a generated link: /agent-drive/{id} is the
# document's only URL, and 'share' changes who that address works for.
# "AgentCloudDrive"/"ACD" is the March 2026 standalone prototype codename.
# ============================================================================

# Percent-encode one query-string value. A folder prefix is a path, and a path
# may legitimately contain spaces, `&`, `#` or `+`, any of which would truncate
# or corrupt the parameter if pasted in raw. jq is already required by this
# script, so this costs no new dependency.
url_encode() {
  jq -rn --arg value "$1" '$value | @uri'
}

# List documents (metadata only), newest-updated first.
#
# --scope selects WHICH documents: mine (default) = only your own; shared = ONLY
# documents other people have shared with you, each row carrying sharedBy; all =
# both; accessed = your LIBRARY, the cross-user documents you or your agents have
# actually opened, each row carrying an accessed object. A selector rather than an
# --include-shared flag, because "list what is shared with me" is a question worth
# being able to ask directly - with a flag you can only widen and then filter the
# answer yourself.
#
# Omitting --scope lists exactly what this command listed before the flag
# existed, so a sync loop never starts sweeping up other people's documents by
# accident. A shared-in document is NOT yours: do not push to its path, and
# expect it to vanish the moment its owner revokes.
#
# --scope accessed is a HISTORY, not discovery: nothing can list public documents
# at large, and a row exists only because you or one of your agents opened that
# exact document. Every row is re-checked on the request, so an entry whose access
# has been revoked is simply absent - trust pagination.hasMore rather than the
# number of rows you got back. It is not searchable yet; 'agent-drive search --scope
# accessed' is rejected rather than silently answering nothing.
#
# --archived lists ONLY deleted (recoverable) documents; the default lists only
# live ones. There is no "both" - hiding tombstones by default is the point.
#
# --prefix scopes the listing to a folder and also returns that folder's
# immediate child folders. Folders are DERIVED from document paths - there is no
# folder to create, rename or delete, so there are no such actions here. Both
# --prefix and the folders array apply to YOUR OWN documents: paths are unique
# per owner, so shared-in documents have no place in your folder tree and any
# scope that includes them comes back with folders empty.
#
# The endpoint is paged (default 100, max 200); the response carries a
# pagination object with hasMore so a truncated first page is visible.
drive_list() {
  local params=""

  while [[ $# -gt 0 ]]; do
    case $1 in
      --archived) params="${params}&archived=true"; shift ;;
      --scope) params="${params}&scope=$(url_encode "$2")"; shift 2 ;;
      --prefix) params="${params}&pathPrefix=$(url_encode "$2")"; shift 2 ;;
      --limit) params="${params}&limit=$2"; shift 2 ;;
      --offset) params="${params}&offset=$2"; shift 2 ;;
      *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
  done

  params="${params#&}"
  if [[ -n "$params" ]]; then
    params="?$params"
  fi

  api_request GET "/agent-drive$params"
}

# Read a document's markdown. With --out FILE, write the content to FILE;
# otherwise print the content to stdout.
drive_pull() {
  local doc_id=$1
  shift
  local out=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --out) out=$2; shift 2 ;;
      *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
  done
  require_value "document id" "$doc_id"

  local response
  response=$(api_request GET "/agent-drive/$doc_id")
  # Pipe jq output straight to the sink: a "$(...)" capture strips trailing
  # newlines, which would make a pull/push round-trip non-byte-identical. jq -j
  # emits the raw content with no added trailing newline.
  if [[ -n "$out" ]]; then
    printf '%s' "$response" | jq -j '.document.content // ""' > "$out"
    echo "Wrote $out" >&2
  else
    printf '%s' "$response" | jq -j '.document.content // ""'
  fi
}

# Write (create or replace-by-path) a markdown document from a local file.
# Path defaults to the file's basename; title defaults to the path.
drive_push() {
  local file=$1
  shift
  local path="" title=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --path) path=$2; shift 2 ;;
      --title) title=$2; shift 2 ;;
      *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
  done
  require_value "file" "$file"
  if [[ ! -f "$file" ]]; then
    echo "Error: file not found: $file" >&2
    exit 1
  fi
  if [[ -z "$path" ]]; then path=$(basename "$file"); fi
  if [[ -z "$title" ]]; then title="$path"; fi

  # --rawfile reads the file verbatim (preserving trailing newlines) so the
  # stored content byte-matches the local file; command substitution would
  # strip trailing newlines.
  local data
  data=$(jq -n \
    --arg title "$title" \
    --arg path "$path" \
    --rawfile content "$file" \
    '{title: $title, path: $path, content: $content}')

  api_request POST /agent-drive "$data"
}

# Delete a document by id. The content is archived, not destroyed: find it again
# with 'agent-drive list --archived' and bring it back with 'agent-drive restore'.
drive_delete() {
  local doc_id=$1
  require_value "document id" "$doc_id"
  if [[ $# -gt 1 ]]; then
    echo "Error: unexpected extra arguments: ${*:2}" >&2
    exit 1
  fi
  api_request DELETE "/agent-drive/$doc_id"
}

# Hybrid search over the drive: semantic + full-text + fuzzy, fused into one
# ranked list, one result per document.
#
# Search runs over CHUNKS, so content anywhere in a document is findable, not
# just its opening. Each hit names the chunk that matched (snippet, headingPath,
# chunkIndex); chunkIndex 0 means the TITLE or PATH matched, not the body.
#
# 'score' is comparable WITHIN one response only - never across two calls.
#
# Precision is positional and optional (low|medium|high, default medium), the
# same shape 'graph search-topics' uses.
#
# --scope mine|shared|all picks the corpus, the same selector 'agent-drive list' takes.
# Default mine. Use --scope shared to answer "what did somebody share with me
# about X" without your own drive crowding the results; hits come back with
# source "drive-shared" and a sharedBy naming the owner. Access is re-checked on
# every request, so a revoked document is gone from the very next search.
drive_search() {
  local query=${1:-}
  if [[ $# -gt 0 ]]; then shift; fi

  local precision="medium" path_prefix="" limit="" scope=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --path-prefix) path_prefix=$2; shift 2 ;;
      --scope) scope=$2; shift 2 ;;
      --limit) limit=$2; shift 2 ;;
      low|medium|high) precision=$1; shift ;;
      *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
  done
  require_value "query" "$query"

  # tonumber on limit so the body sends a JSON number; the API rejects a string.
  #
  # --scope is omitted from the body entirely when unset rather than sent as
  # "mine": the server's default IS mine, and an absent field cannot disagree
  # with it. It also means an older CLI and this one send byte-identical bodies
  # for the same command.
  local data
  data=$(jq -n \
    --arg query "$query" \
    --arg precision "$precision" \
    --arg prefix "$path_prefix" \
    --arg limit "$limit" \
    --arg scope "$scope" \
    '{query: $query, precision: $precision}
    | if $prefix != "" then . + {pathPrefix: $prefix} else . end
    | if $scope != "" then . + {scope: $scope} else . end
    | if $limit != "" then . + {limit: ($limit | tonumber)} else . end')

  api_request POST /search/documents "$data"
}

# Resolve a document PATH to its id, echoing the id on stdout.
#
# Every other drive action takes an id, but 'share' is the one an agent reaches
# for right after writing a document by path - and making it re-read the id out
# of an earlier response is exactly the friction that produces "share the wrong
# document" bugs. So share/unshare accept either.
#
# The discriminator is the 'doc_' prefix the API mints; anything else is treated
# as a path. That is a real prefix, not a heuristic - a path is a filename, and a
# filename that happens to start with "doc_" would collide, which is why the
# lookup below reports honestly rather than guessing when it finds nothing.
#
# The listing is scoped to the path's PARENT folder (pathPrefix is a folder
# prefix - it cannot address a single document) and paged through, because a
# folder can hold more documents than one page returns and a silent first-page
# miss would look identical to "no such document".
resolve_document_id() {
  local wanted=$1
  case "$wanted" in
    doc_*) printf '%s' "$wanted"; return 0 ;;
  esac

  # Parent folder of the path, or "" for a document at the drive root. Uses a
  # parameter expansion rather than dirname, which returns "." for a bare name.
  local folder=""
  case "$wanted" in
    */*) folder="${wanted%/*}/" ;;
  esac

  local offset=0 limit=200 response found has_more
  while :; do
    response=$(api_request GET "/agent-drive?pathPrefix=$(url_encode "$folder")&limit=$limit&offset=$offset")

    # Case-insensitive compare: paths are matched case-insensitively by the API
    # and stored case-preserving, so an exact string compare would miss the very
    # document the caller just wrote under a different capitalization.
    found=$(printf '%s' "$response" | jq -r --arg want "$wanted" \
      'first(.documents[]? | select((.path | ascii_downcase) == ($want | ascii_downcase)) | .id) // ""')
    if [[ -n "$found" ]]; then
      printf '%s' "$found"
      return 0
    fi

    has_more=$(printf '%s' "$response" | jq -r '.pagination.hasMore // false')
    if [[ "$has_more" != "true" ]]; then break; fi
    offset=$((offset + limit))
  done

  echo "Error: no document found at path: $wanted" >&2
  echo "Pass the document id (doc_...) if you have it - 'agent-drive list' shows both." >&2
  exit 1
}

# Set who can open a document: --audience public (anyone with the link) or
# authenticated (anyone signed into TeamYou). Default is public - it is what
# "share this" means to the person asking, and the alternative is narrower.
#
# Requires the share scope, which is never granted by default: a 403 here
# means the key's owner has not ticked that box in Settings, not that the command
# is wrong. Say so rather than retrying.
#
# Prints the document URL and the raw-markdown URL. Hand the raw one to another
# agent; hand the other one to a person.
drive_share() {
  local target=${1:-}
  if [[ $# -gt 0 ]]; then shift; fi
  local audience="public"
  while [[ $# -gt 0 ]]; do
    case $1 in
      --audience) audience=$2; shift 2 ;;
      *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
  done
  require_value "document path or id" "$target"

  case "$audience" in
    public|authenticated) ;;
    *) echo "Error: --audience must be public or authenticated (got: $audience)" >&2
       echo "To stop sharing, use 'agent-drive unshare'." >&2
       exit 1 ;;
  esac

  local doc_id
  doc_id=$(resolve_document_id "$target")

  local data
  data=$(jq -n --arg visibility "$audience" '{visibility: $visibility}')
  api_request PUT "/agent-drive/$doc_id/visibility" "$data"
}

# Stop sharing: set the document back to private. This IS the revoke, and it is
# immediate - the URL stops working for everyone but the owner.
#
# Worth telling a user who asks: re-sharing later re-enables THE SAME URL, so
# anyone who kept the link gets back in. There is no secret to rotate, because
# the id was never secret. Google Docs behaves identically.
drive_unshare() {
  local target=${1:-}
  require_value "document path or id" "$target"
  if [[ $# -gt 1 ]]; then
    echo "Error: unexpected extra arguments: ${*:2}" >&2
    exit 1
  fi

  local doc_id
  doc_id=$(resolve_document_id "$target")

  api_request PUT "/agent-drive/$doc_id/visibility" '{"visibility":"private"}'
}

# Restore a deleted document by id.
drive_restore() {
  local doc_id=$1
  require_value "document id" "$doc_id"
  if [[ $# -gt 1 ]]; then
    echo "Error: unexpected extra arguments: ${*:2}" >&2
    exit 1
  fi
  api_request POST "/agent-drive/$doc_id/restore"
}

# Share a document with ONE person by email - the third kind of share, narrower
# than 'agent-drive share' (which opens it to the link or to all signed-in users). If
# the address has a TeamYou account they get access now; if not, an invite is
# stored and binds when they sign up with that verified address. The reply is the
# same {shared:true} either way ON PURPOSE - this is never a way to check whether
# an address has an account. Requires the share scope (a 403 means the key's
# owner has not ticked that box in Settings). Undo with 'agent-drive ungrant'.
#
# Accepts a path OR an id for the same reason share does: it is reached for right
# after writing a document by path.
drive_grant() {
  drive_grant_request POST "$@"
}

# Remove one person's access, by the same email you granted it with. Immediate,
# and idempotent: revoked:false just means nobody was shared on that address, so
# retrying is safe. Requires the share scope.
drive_ungrant() {
  drive_grant_request DELETE "$@"
}

# Shared body for grant/ungrant: <path-or-id> --email <address>. POST creates the
# grant, DELETE revokes it - one path, two verbs, exactly like share/unshare.
drive_grant_request() {
  local method=$1
  shift
  local target=${1:-}
  if [[ $# -gt 0 ]]; then shift; fi
  local email=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --email) email=$2; shift 2 ;;
      *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
  done
  require_value "document path or id" "$target"
  require_value "--email <address>" "$email"

  local doc_id
  doc_id=$(resolve_document_id "$target")

  local data
  data=$(jq -n --arg email "$email" '{email: $email}')
  api_request "$method" "/agent-drive/$doc_id/grants" "$data"
}

dispatch_ty_agent_drive() {
  ty_dispatch_begin "ty agent-drive" show_ty_agent_drive_help "$@" && return 0
  local action=$1
  shift

  case "$action" in
    list) drive_list "$@" ;;
    pull) drive_pull "$@" ;;
    push) drive_push "$@" ;;
    delete) drive_delete "$@" ;;
    restore) drive_restore "$@" ;;
    search) drive_search "$@" ;;
    share) drive_share "$@" ;;
    unshare) drive_unshare "$@" ;;
    grant) drive_grant "$@" ;;
    ungrant) drive_ungrant "$@" ;;
    -h|--help) show_ty_agent_drive_help ;;
    *) echo "Unknown ty agent-drive action: $action" >&2; echo "Run 'teamyou.sh ty agent-drive -h' for usage" >&2; exit 1 ;;
  esac
}

# ============================================================================
# ty routines — Heartbeat and Scheduled Actions (feature-flagged)
# ============================================================================


# ============================================================================
# ty instructions — Async agent instruction queue (feature-flagged)
# ============================================================================


# ============================================================================
# Provider dispatchers
# ============================================================================

dispatch_ty() {
  if [[ -z "${1:-}" ]]; then show_ty_help; return 0; fi
  local service=$1
  shift

  case "$service" in
    graph) dispatch_ty_graph "$@" ;;
    todos) dispatch_ty_todos "$@" ;;
    projects) dispatch_ty_projects "$@" ;;
    areas) dispatch_ty_areas "$@" ;;
    agent) dispatch_ty_agent "$@" ;;
    agent-drive) dispatch_ty_agent_drive "$@" ;;
    # The retired noun (TYDEV-1119), kept working for agents already in the
    # field. Hidden: it is absent from every help table, so nothing teaches it
    # to a new agent. The warning goes to STDERR and the dispatch is the same
    # function, so a script doing `teamyou.sh ty drive list | jq` sees exactly
    # the bytes it saw before on stdout - the one thing that must not change,
    # since a deprecation notice mixed into JSON breaks the caller it warns.
    drive)
      echo "[TeamYou] 'ty drive' is deprecated; use 'ty agent-drive' instead." >&2
      dispatch_ty_agent_drive "$@"
      ;;
    -h|--help) show_ty_help ;;
    *) echo "Unknown ty service: $service" >&2; echo "Run 'teamyou.sh ty -h' for usage" >&2; exit 1 ;;
  esac
}

# ============================================================================
# Help text
# ============================================================================

show_help() {
  cat <<'EOF'
TeamYou API helper

Usage: teamyou.sh <provider> <service> <action> [arguments]

Providers:
  ty        TeamYou native services (graph, todos)
EOF

  cat <<'EOF'

Run 'teamyou.sh <provider> -h' for provider-specific help.

Environment:
  TEAMYOU_API_KEY  - API key (or create ~/.teamyou_key)
  TEAMYOU_API_URL  - API base URL (default: https://www.teamyou.com/api/external/v1)

Examples:
  teamyou.sh ty graph topics-list
  teamyou.sh ty graph topics-create "Learning: Italian Cooking" "Recipes and techniques from Italy"
  teamyou.sh ty graph edges-create SOURCE_ID TARGET_ID "enables" --mirror-label "enabled by"
  teamyou.sh ty todos list --status todo --priority high
EOF

}

show_ty_help() {
  cat <<'EOF'
TeamYou (ty) services

Usage: teamyou.sh ty <service> <action> [arguments]

Services:
  graph          Topics, details, edges, and semantic search
  todos          Task management
  projects       Projects, plans, and references
  areas          Cross-pillar contexts (membership + rollup)
  agent          Agent registration and identity
  agent-drive    TY Agent Drive - document/file storage (markdown today)
EOF



  cat <<'EOF'

Run 'teamyou.sh ty <service> -h' for service-specific help.
EOF
}

# GENERATED-FROM-OPENAPI:graph:start
show_ty_graph_help() {
  cat <<'EOF'
TeamYou Graph (ty graph)

Usage: teamyou.sh ty graph <action> [arguments]

Topics:
  topics-list
  topics-create <name> <description> [--summary <text>]
  topics-get <topic_id>
  topics-update <topic_id> [--name <text>] [--description <text>] [--summary <text>]
  topics-delete <topic_id>

Details:
  details-list <topic_id>
  details-add <topic_id> <detail1> [detail2] [detail3] ...
  details-update <topic_id> <detail_id> <text>
  details-delete <topic_id> <detail_id>

Edges:
  edges-list <topic_id>
  edges-create <source_topic_id> <target_topic_id> <label> [--mirror-label <text>]
  edges-link <source_topic_id> <target_topic_id> <label> [--mirror-label <text>]   # alias for edges-create
  edges-update <edge_id> [--label <text>] [--mirror-label <text>]
  edges-delete <edge_id>

Search:
  search-topics <query> [precision]
  search-details <query> [precision]
EOF
}
# GENERATED-FROM-OPENAPI:graph:end

# GENERATED-FROM-OPENAPI:todos:start
show_ty_todos_help() {
  cat <<'EOF'
TeamYou Todos (ty todos)

Usage: teamyou.sh ty todos <action> [arguments]

Actions:
  list [--status todo|done] [--archived] [--priority high|medium|low|none] [--order-by createdAt|updatedAt|dueDate|priority] [--limit N]
  create <title> [--description <text>] [--status todo|done] [--priority high|medium|low|none] [--due-date <ISO8601>] [--topic-id <id>] [--project-id <id>] [--after <todo_id>] [--before <todo_id>]
  get <todo_id>
  update <todo_id> [--title <text>] [--description <text>] [--status todo|done] [--priority PRIORITY] [--due-date <ISO8601>] [--archived] [--topic-id <id>] [--no-topic] [--project-id <id>] [--no-project] [--after <todo_id>] [--before <todo_id>]
  delete <todo_id>
  complete <todo_id>
EOF
}
# GENERATED-FROM-OPENAPI:todos:end

# GENERATED-FROM-OPENAPI:projects:start
show_ty_projects_help() {
  cat <<'EOF'
TeamYou Projects (ty projects)

Usage: teamyou.sh ty projects <action> [arguments]

Actions:
  list [--status active|waiting|done|archived] [--limit N]
  create <name> [--goal <text>] [--status active|waiting|done|archived] [--waiting-on <text>] [--notes <text>] [--due-date <YYYY-MM-DD>] [--todo <title>]... [--ref <type>:<value>]... [--from-json <file>]
  get <project_id>
  update <project_id> [--name <text>] [--goal <text>] [--status active|waiting|done|archived] [--waiting-on <text>] [--notes <text>] [--due-date <YYYY-MM-DD>] [--no-goal] [--no-waiting-on] [--no-notes] [--no-due-date]
  delete <project_id>
  refs-add <project_id> --target-type topic|todo|project|doc|url [--target-id <id>] [--url <url>] [--title <text>] [--after <ref_id>] [--before <ref_id>]
  doc-push <project_id> <file> [--path <path>] [--title <text>] [--ref-title <text>] [--after <ref_id>] [--before <ref_id>]
  refs-reorder <project_id> <ref_id> [--after <ref_id>] [--before <ref_id>]
  refs-remove <project_id> <ref_id>

Notes:
  create --todo/--ref/--from-json build the project and its children in ONE
  atomic call: flag order is the order, and a failure anywhere creates nothing.
  It is create-only - there is no upsert or dedupe, so running it twice makes
  two projects. --ref takes <type>:<value> (topic|todo|project|doc:<id>, or
  url:<url>) and cannot point at a --todo from the same call (no id yet).
  --from-json <file> is client-side only: the file is merged OVER the flags
  and posted as the same JSON body, so it can set per-todo status/priority/
  dueDate/topicId that have no flag.

  doc-push document paths are GLOBAL per user, not per project: re-pushing a
  path replaces that one document everywhere it is referenced. --path defaults
  to projects/<project_id>/<basename> so same-named files in different projects
  do not collide; pass the same --path from two projects only to share one doc.
EOF
}
# GENERATED-FROM-OPENAPI:projects:end

# GENERATED-FROM-OPENAPI:areas:start
show_ty_areas_help() {
  cat <<'EOF'
TeamYou Areas (ty areas)

Usage: teamyou.sh ty areas <action> [arguments]

Actions:
  list [--include-archived] [--limit N]
  create <name> [--description <text>] [--archived]
  get <area_id> [--depth direct|full]
  update <area_id> [--name <text>] [--description <text>] [--no-description] [--archived] [--no-archived]
  delete <area_id>
  refs-add <area_id> --target-type topic|todo|project|area|doc|url [--target-id <id>] [--url <url>] [--title <text>] [--after <ref_id>] [--before <ref_id>]
  refs-reorder <area_id> <ref_id> [--after <ref_id>] [--before <ref_id>]
  refs-remove <area_id> <ref_id>
EOF
}
# GENERATED-FROM-OPENAPI:areas:end

# GENERATED-FROM-OPENAPI:agent:start
show_ty_agent_help() {
  cat <<'EOF'
TeamYou Agent (ty agent)

Usage: teamyou.sh ty agent <action> [arguments]

Actions:
  register [--slug <slug> | --openclaw-instance-id <instance-id>] [--kind claude|codex|perplexity|openclaw|other] [--name <display name>] [--model <model>]
  whoami
  ack <token>

Environment:
  TEAMYOU_AGENT_SLUG              - default --slug value (a stable, human-meaningful id)
  TEAMYOU_OPENCLAW_INSTANCE_ID    - provisioned OpenClaw reconciliation mode
EOF
}
# GENERATED-FROM-OPENAPI:agent:end

# GENERATED-FROM-OPENAPI:agent-drive:start
show_ty_agent_drive_help() {
  cat <<'EOF'
TY Agent Drive (ty agent-drive)

Usage: teamyou.sh ty agent-drive <action> [arguments]

Actions:
  list [--scope mine|shared|all|accessed] [--prefix <path>] [--archived] [--limit N] [--offset N]
  push <file> [--path <path>] [--title <text>]
  pull <id> [--out <file>]
  delete <id>
  share <path-or-id> [--audience public|authenticated]
  unshare <path-or-id>   # sets visibility back to private
  grant <path-or-id> --email <address>
  ungrant <path-or-id> --email <address>   # removes that person’s access
  restore <id>
  search <query> [precision] [--scope mine|shared|all] [--path-prefix <prefix>] [--limit N]

TY Agent Drive - document and file storage for agents (markdown today).
EOF
}
# GENERATED-FROM-OPENAPI:agent-drive:end



# ============================================================================
# Main dispatch
# ============================================================================

if [[ $# -eq 0 ]] || [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
  show_help
  exit 0
fi

provider=$1
shift

case "$provider" in
  ty) dispatch_ty "$@" ;;
  *)
    echo "Unknown provider: $provider" >&2
    echo "Run 'teamyou.sh --help' for usage" >&2
    exit 1
    ;;
esac
