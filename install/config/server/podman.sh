# Rootless Podman for the owner: subordinate IDs to map container users to,
# and lingering, so their container units start at boot without a login.
user=${OMARCHY_INSTALL_USER:-}
if [[ -n $user ]]; then
  grep -q "^$user:" /etc/subuid 2>/dev/null || usermod --add-subuids 100000-165535 "$user"
  grep -q "^$user:" /etc/subgid 2>/dev/null || usermod --add-subgids 100000-165535 "$user"
  install -d -m 755 /var/lib/systemd/linger
  touch "/var/lib/systemd/linger/$user"
fi

# Containers run with --restart=always come back after a reboot.
systemctl --global enable podman-restart.service
