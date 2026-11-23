#!/bin/bash

# omarchy fleet lists Tailscale peers (online first, Mullvad exit nodes
# skipped), keeps a dedicated Fleet SSH key, and opens a shell or inline agent.

set -euo pipefail
source "$(dirname "$0")/base-test.sh"

test_tmp=$(mktemp -d)
trap 'rm -rf "$test_tmp"' EXIT

export HOME="$test_tmp/home"
export OMARCHY_FLEET_KEY="$HOME/.ssh/omarchy_fleet"
mkdir -p "$HOME" "$test_tmp/bin"
PATH="$test_tmp/bin:$PATH"

fleet="$ROOT/bin/omarchy-fleet"
ssh_log="$test_tmp/ssh.log"

cat >"$test_tmp/bin/tailscale" <<'EOF'
#!/bin/bash
if [[ -n ${TAILSCALE_FAIL:-} ]]; then
  exit 1
fi
cat <<JSON
{
  "BackendState": "${TAILSCALE_STATE:-Running}",
  "Peer": {
    "p1": { "DNSName": "minipc.tailnet.ts.net.", "Online": false, "TailscaleIPs": ["100.64.0.3"] },
    "p2": { "DNSName": "nas.tailnet.ts.net.", "Online": true, "TailscaleIPs": ["100.64.0.2"] },
    "p3": { "DNSName": "laptop.tailnet.ts.net.", "Online": true, "TailscaleIPs": ["100.64.0.1"] },
    "p4": { "DNSName": "us-nyc-wg-001.mullvad.ts.net.", "Online": true, "Tags": ["tag:mullvad-exit-node"], "TailscaleIPs": ["100.64.0.9"] }
  }
}
JSON
EOF

cat >"$test_tmp/bin/ssh" <<EOF
#!/bin/bash
printf '%s\n' "\$*" >"$ssh_log"
exit "\${SSH_EXIT:-0}"
EOF

cat >"$test_tmp/bin/fzf" <<'EOF'
#!/bin/bash
line=$(grep -F "${FZF_PICK:-nas}" | head -1)
printf '%s\n%s\n' "${FZF_KEY:-}" "$line"
EOF

chmod +x "$test_tmp/bin/"*

# Fleet key is created once and reused.
pub1=$("$fleet" key)
pub2=$("$fleet" key)
[[ $pub1 == ssh-ed25519* && $pub1 == "$pub2" && -f $OMARCHY_FLEET_KEY ]] ||
  fail "omarchy fleet key creates and reuses the Fleet SSH key" "$pub1"
pass "omarchy fleet key creates and reuses the Fleet SSH key"

# Peers are listed online-first, alphabetically, without Mullvad exit nodes.
expected=$'laptop\tonline\t100.64.0.1\nnas\tonline\t100.64.0.2\nminipc\toffline\t100.64.0.3'
actual=$("$fleet" list)
[[ $actual == "$expected" ]] || fail "omarchy fleet list orders online peers first and skips Mullvad nodes" "$actual"
pass "omarchy fleet list orders online peers first and skips Mullvad nodes"

# Disconnected Tailscale fails with a clear message.
if out=$(TAILSCALE_STATE=Stopped "$fleet" list 2>&1); then
  fail "omarchy fleet refuses to list when Tailscale is disconnected"
fi
[[ $out == *"Tailscale, which is not connected"* ]] ||
  fail "disconnected Tailscale explains why Fleet is unavailable" "$out"
pass "disconnected Tailscale explains why Fleet is unavailable"

# Enter opens a shell with the Fleet key; Ctrl+A starts the inline agent.
FZF_PICK=nas FZF_KEY="" "$fleet"
[[ $(cat "$ssh_log") == "-i $OMARCHY_FLEET_KEY nas" ]] ||
  fail "Enter opens a shell using the Fleet key" "$(cat "$ssh_log")"
pass "Enter opens a shell using the Fleet key"

FZF_PICK=laptop FZF_KEY="ctrl-a" "$fleet"
[[ $(cat "$ssh_log") == "-t -i $OMARCHY_FLEET_KEY laptop bash -lc 'omarchy agent --inline'" ]] ||
  fail "Ctrl+A starts the inline agent in a login shell using the Fleet key" "$(cat "$ssh_log")"
pass "Ctrl+A starts the inline agent in a login shell using the Fleet key"

# Selecting an offline peer reports it without calling ssh.
rm -f "$ssh_log"
if out=$(FZF_PICK=minipc "$fleet" 2>&1); then
  fail "selecting an offline peer fails cleanly"
fi
[[ $out == *"minipc is offline"* && ! -e $ssh_log ]] ||
  fail "selecting an offline peer prints an error without invoking ssh" "$out"
pass "selecting an offline peer prints an error without invoking ssh"

# Exit 255 from ssh prints the Fleet key authorization hint.
if out=$(SSH_EXIT=255 "$fleet" ssh nas 2>&1); then
  fail "ssh exit 255 propagates failure"
fi
[[ $out == *"omarchy fleet key"* ]] ||
  fail "ssh failure hints how to authorize the Fleet key" "$out"
pass "ssh failure hints how to authorize the Fleet key"
