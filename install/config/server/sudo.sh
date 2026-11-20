# The owner has no password, so sudo must not ask for one: their SSH key is
# the lock on the machine.
user=${OMARCHY_INSTALL_USER:-}
if [[ -z $user ]]; then
  echo "No install user: passwordless sudo is left for the owner's provisioning"
else
  if [[ ! $user =~ ^[a-z_][a-z0-9_-]*$ ]]; then
    echo "Refusing to write a sudo rule for the user name '$user'" >&2
    exit 1
  fi

  rule=$(mktemp)
  printf '%s ALL=(ALL:ALL) NOPASSWD: ALL\n' "$user" >"$rule"
  visudo -cqf "$rule"
  install -m 0440 "$rule" /etc/sudoers.d/omarchy-server-owner
  rm -f "$rule"
fi
