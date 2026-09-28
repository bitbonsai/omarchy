#!/bin/bash

source "$(dirname "$0")/base-test.sh"

require_command jq
require_command python3

timestamp="$(date +%Y-%m-%d)T12:00:00Z"

# pi and omp can spend an OpenCode subscription without opencode's CLI ever
# running, so its own database cannot be the only source.
PI_HOME=$(mktemp -d)
trap 'rm -rf "$PI_HOME"' EXIT
mkdir -p "$PI_HOME/.pi/agent/sessions/project" "$PI_HOME/.omp/agent/sessions/project"

cat >"$PI_HOME/.pi/agent/sessions/project/pi.jsonl" <<EOF
{"type":"message","id":"pi-1","timestamp":"$timestamp","message":{"role":"assistant","provider":"opencode","model":"deepseek-v4.1-flash:high","usage":{"input":100,"output":10,"reasoning":5,"cacheRead":20,"cacheWrite":3}}}
{"type":"message","id":"pi-2","timestamp":"$timestamp","message":{"role":"assistant","provider":"opencode-local","model":"gpt-nope","usage":{"input":999,"output":999}}}
{"type":"message","id":"pi-3","timestamp":"$timestamp","message":{"role":"user","provider":"opencode","model":"deepseek-v4.1-flash","usage":{"input":999,"output":999}}}
EOF
cat >"$PI_HOME/.omp/agent/sessions/project/omp.jsonl" <<EOF
{ "type": "message", "id": "omp-1", "timestamp": "$timestamp", "message": { "role": "assistant", "provider": "opencode-go", "model": "minimax-m3", "usage": { "input": 50, "output": 4, "reasoning": 1, "cacheRead": 5, "cacheWrite": 0 } } }
{"type":"message","id":"other-1","timestamp":"$timestamp","message":{"role":"assistant","provider":"openai-codex","model":"gpt-nope","usage":{"input":999,"output":999}}}
EOF

result=$(HOME="$PI_HOME" XDG_CACHE_HOME="$PI_HOME/.cache" XDG_DATA_HOME="$PI_HOME/.local/share" \
  PATH="$PI_HOME/bin:$PATH" "$ROOT/bin/omarchy-agent-usage-opencode")

[[ $(jq -r '.todayTotalTokens' <<<"$result") == "198" ]] ||
  fail "OpenCode collector counts usage from pi and omp sessions" "$result"
[[ $(jq -c '.modelUsage' <<<"$result") == '{"deepseek-v4.1-flash":{"inputTokens":100,"outputTokens":15,"cacheReadInputTokens":20,"cacheCreationInputTokens":3},"minimax-m3":{"inputTokens":50,"outputTokens":5,"cacheReadInputTokens":5,"cacheCreationInputTokens":0}}' ]] ||
  fail "OpenCode collector folds reasoning into output and strips the thinking suffix" "$result"
pass "OpenCode collector counts pi and omp subscription usage"

[[ $(jq -r '.id + "/" + (.name) + "/" + (.limits|tostring)' <<<"$result") == 'opencode/OpenCode/[]' ]] ||
  fail "OpenCode collector identifies itself with an empty limits list" "$result"
pass "OpenCode collector identifies itself with an empty limits list"

# A subscription burned entirely through opencode has no pi session files;
# usage must come from opencode's message database, filtered to its providers.
OPENCODE_HOME=$(mktemp -d)
trap 'rm -rf "$PI_HOME" "$OPENCODE_HOME"' EXIT

python3 - "$OPENCODE_HOME/.local/share/opencode/opencode.db" <<'PY'
import json
import sqlite3
import sys
import time
from pathlib import Path

db = Path(sys.argv[1])
db.parent.mkdir(parents=True, exist_ok=True)
conn = sqlite3.connect(db)
conn.execute("CREATE TABLE message (id text PRIMARY KEY, session_id text NOT NULL, time_created integer NOT NULL, time_updated integer NOT NULL, data text NOT NULL)")
now_ms = int(time.time() * 1000)

def message(id, provider, model, role="assistant", input=0, output=0, reasoning=0, read=0, write=0):
  return (id, "ses_1", now_ms, now_ms, json.dumps({
    "role": role,
    "providerID": provider,
    "modelID": model,
    "tokens": {"input": input, "output": output, "reasoning": reasoning, "cache": {"read": read, "write": write}},
    "time": {"created": now_ms},
  }))

conn.executemany("INSERT INTO message VALUES (?, ?, ?, ?, ?)", [
  message("msg_1", "opencode", "deepseek-v4-flash", input=80, output=40, reasoning=5, read=30),
  message("msg_2", "opencode-go", "minimax-m3", input=10, output=2),
  message("msg_3", "anthropic", "claude-opus-5", input=999, output=999),
  message("msg_4", "opencode-local", "gpt-nope", input=999, output=999),
  message("msg_5", "opencode", "deepseek-v4-flash", role="user", input=999, output=999),
])
conn.execute("INSERT INTO message VALUES ('msg_6', 'ses_1', ?, ?, '[\"not\",\"an\",\"object\"]')", (now_ms, now_ms))
conn.commit()
conn.close()
PY

result=$(HOME="$OPENCODE_HOME" XDG_CACHE_HOME="$OPENCODE_HOME/.cache" XDG_DATA_HOME="$OPENCODE_HOME/.local/share" \
  PATH="$OPENCODE_HOME/bin:$PATH" "$ROOT/bin/omarchy-agent-usage-opencode")

[[ $(jq -r '.todayTotalTokens' <<<"$result") == "167" ]] ||
  fail "OpenCode collector counts opencode database usage, reasoning included" "$result"
[[ $(jq -c '.modelUsage' <<<"$result") == '{"deepseek-v4-flash":{"inputTokens":80,"outputTokens":45,"cacheReadInputTokens":30,"cacheCreationInputTokens":0},"minimax-m3":{"inputTokens":10,"outputTokens":2,"cacheReadInputTokens":0,"cacheCreationInputTokens":0}}' ]] ||
  fail "OpenCode collector ignores prefix-colliding providers, user messages, and malformed rows" "$result"
[[ $(jq -r '.totalSessions' <<<"$result") == "1" ]] ||
  fail "OpenCode collector counts a database session once" "$result"
pass "OpenCode collector counts opencode database usage"

# The cache is an optimization: the record must stay complete either way.
CACHE_HOME=$(mktemp -d)
trap 'rm -rf "$PI_HOME" "$OPENCODE_HOME" "$CACHE_HOME"' EXIT
mkdir -p "$CACHE_HOME/bin" "$CACHE_HOME/.pi/agent/sessions/project"

cat >"$CACHE_HOME/.pi/agent/sessions/project/pi.jsonl" <<EOF
{"type":"message","id":"pi-1","timestamp":"$timestamp","message":{"role":"assistant","provider":"opencode","model":"deepseek-v4.1-flash","usage":{"input":7,"output":3}}}
EOF

result=$(HOME="$CACHE_HOME" XDG_CACHE_HOME="$CACHE_HOME/.cache" XDG_DATA_HOME="$CACHE_HOME/.local/share" \
  PATH="$CACHE_HOME/bin:$PATH" "$ROOT/bin/omarchy-agent-usage-opencode")
[[ $(jq -r '.todayTotalTokens' <<<"$result") == "10" ]] ||
  fail "OpenCode collector scans without a cache" "$result"

cache_file=$(find "$CACHE_HOME/.cache/omarchy/agent-usage" -name 'opencode-scan-*.json' -print -quit)
[[ -n $cache_file ]] ||
  fail "OpenCode collector writes a local-stats cache" "$cache_file"

result=$(HOME="$CACHE_HOME" XDG_CACHE_HOME="$CACHE_HOME/.cache" XDG_DATA_HOME="$CACHE_HOME/.local/share" \
  PATH="$CACHE_HOME/bin:$PATH" "$ROOT/bin/omarchy-agent-usage-opencode" --limits-only)
[[ $(jq -r '.todayTotalTokens' <<<"$result") == "10" && $(jq -r '.totalPrompts' <<<"$result") == "1" ]] ||
  fail "OpenCode collector --limits-only emits a complete record from cache" "$result"
pass "OpenCode collector caches and reuses local stats"
