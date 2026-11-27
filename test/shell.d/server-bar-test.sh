#!/bin/bash

# omarchy-server-bar renders clickable status bar pills with user ranges,
# underlines accelerator letters, highlights the focused pill in bar-focus
# mode, and dispatches click/keyboard actions cleanly.

set -euo pipefail
source "$(dirname "$0")/base-test.sh"

test_tmp=$(mktemp -d)
trap 'rm -rf "$test_tmp"' EXIT

mkdir -p "$test_tmp/bin"
PATH="$test_tmp/bin:$PATH"
bar="$ROOT/bin/omarchy-server-bar"
conf="$ROOT/default/tmux/server.conf"

cat >"$test_tmp/bin/systemctl" <<'EOF'
#!/bin/bash
if [[ -n ${FAKE_FAILED:-} ]]; then
  printf '%s\n' "$FAKE_FAILED"
fi
EOF

cat >"$test_tmp/bin/tailscale" <<'EOF'
#!/bin/bash
printf '{"BackendState":"%s"}\n' "${FAKE_TS_STATE:-Running}"
EOF

chmod +x "$test_tmp/bin/"*

# Healthy output includes clickable ranges for fleet, telemetry, om, help.
out=$(OMARCHY_ASCII=0 "$bar")
[[ $out == *"#[range=user|fleet]"* && $out == *"#[underscore]f#[nounderscore]leet"* ]] ||
  fail "healthy bar renders clickable fleet pill with underlined f" "$out"
pass "healthy bar renders clickable fleet pill with underlined f"

[[ $out == *"#[range=user|telemetry]"* && $out == *"#[range=user|om]"* && $out == *"#[underscore]o#[nounderscore]m"* && $out == *"#[range=user|help]"* ]] ||
  fail "healthy bar renders clickable telemetry, om, and ? help pills" "$out"
pass "healthy bar renders clickable telemetry, om, and ? help pills"

# Focus mode highlights the focused pill in amber.
focused=$(OMARCHY_BAR_FOCUS=help "$bar")
[[ $focused == *"#[range=user|help]#[fg=#e0af68,bg=#13141c]#[bg=#e0af68,fg=#15161e,bold]?"* ]] ||
  fail "bar focus highlights the active pill in amber" "$focused"
pass "bar focus highlights the active pill in amber"

# Visible IDs list matches healthy vs alert states.
ids=$(tr '\n' ' ' < <("$bar" --ids))
[[ $ids == "host fleet telemetry om help " ]] ||
  fail "healthy bar --ids lists host, fleet, telemetry, om, help" "$ids"
pass "healthy bar --ids lists host, fleet, telemetry, om, help"

alert_ids=$(FAKE_FAILED="jellyfin.service" "$bar" --ids | tr '\n' ' ')
[[ $alert_ids == "host failed om help " ]] ||
  fail "alert bar --ids replaces telemetry with failed pill" "$alert_ids"
pass "alert bar --ids replaces telemetry with failed pill"

# Disconnected tailscale omits fleet pill.
no_ts_ids=$(FAKE_TS_STATE=Stopped "$bar" --ids | tr '\n' ' ')
[[ $no_ts_ids == "host telemetry om help " ]] ||
  fail "disconnected tailscale omits fleet pill from --ids" "$no_ts_ids"
pass "disconnected tailscale omits fleet pill from --ids"

# tmux server.conf parses cleanly on a live detached tmux server.
sock="omarchy-bar-test-$$"
tmux -L "$sock" -f "$conf" new-session -d -s test "sleep 5"
trap 'tmux -L "$sock" kill-server 2>/dev/null || true; rm -rf "$test_tmp"' EXIT
bindings=$(tmux -L "$sock" list-keys)
[[ $bindings == *"bar-focus"* && $bindings == *"MouseDown1StatusRight"* && $bindings == *"M-o"* && $bindings == *"M-f"* && $bindings == *"M-?"* ]] ||
  fail "tmux server.conf loads click, Alt, prefix, and bar-focus bindings" "$bindings"
pass "tmux server.conf loads click, Alt, prefix, and bar-focus bindings"
