#!/bin/bash

# Omarchy Server records what runs before an update and, after the reboot,
# reports only what came back down, until it is up again.

set -euo pipefail
source "$(dirname "$0")/base-test.sh"

test_tmp=$(mktemp -d)
trap 'rm -rf "$test_tmp"' EXIT

export HOME="$test_tmp/home" STATE="$test_tmp/state" OMARCHY_BOOT_ID_FILE="$test_tmp/boot_id"
mkdir -p "$HOME" "$STATE" "$test_tmp/bin"
PATH="$test_tmp/bin:$PATH"

# Units and mounts are up while a file of their name exists in $STATE.
cat >"$test_tmp/bin/systemctl" <<'EOF'
#!/bin/bash
scope=system
[[ $1 == "--user" ]] && { scope=user; shift; }
case $1 in
  is-active) [[ -e $STATE/$scope-${@: -1} ]] ;;
  list-units) for f in "$STATE"/user-*; do [[ -e $f ]] && echo "${f##*/user-} loaded active running"; done ;;
  show) for unit in "${@:3}"; do printf 'Id=%s\nSourcePath=%s\n\n' "$unit" "$HOME/.config/containers/systemd/${unit%.service}.container"; done ;;
esac
EOF
cat >"$test_tmp/bin/findmnt" <<'EOF'
#!/bin/bash
if [[ $3 == "-M" ]]; then
  [[ -e $STATE/mount-${4//\//_} ]]
else
  for f in "$STATE"/mount-*; do [[ -e $f ]] && { name=${f##*/mount-}; echo "${name//_//}"; }; done
fi
EOF
chmod +x "$test_tmp/bin/"*

watch="$ROOT/bin/omarchy-server-update-watch"

echo boot-a >"$OMARCHY_BOOT_ID_FILE"
touch "$STATE/system-sshd.service" "$STATE/user-jellyfin.service" "$STATE/mount-_mnt_media"
"$watch" record

# Still the update's own boot: nothing is compared yet.
rm "$STATE/user-jellyfin.service"
"$watch" compare
[[ -z $("$watch" down) ]] || fail "nothing is reported before the reboot"
pass "nothing is reported before the reboot"

echo boot-b >"$OMARCHY_BOOT_ID_FILE"
"$watch" compare
[[ $("$watch" down) == "user jellyfin.service" ]] || fail "after the reboot, what ran before and is down is reported" "$("$watch" down)"
pass "after the reboot, what ran before and is down is reported"

touch "$STATE/user-jellyfin.service"
[[ -z $("$watch" down) ]] || fail "a unit that came back up is no longer reported"
pass "a unit that came back up is no longer reported"
