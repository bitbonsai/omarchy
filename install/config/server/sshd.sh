# SSH keys only, and no root login. The installer writes the owner's
# authorized keys; the owner has no password, so a key is the only way in.
install -d -m 755 /etc/ssh/sshd_config.d
cat >/etc/ssh/sshd_config.d/10-omarchy-server.conf <<'EOF'
# Omarchy Server: SSH keys only, and no root login.
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
EOF
chmod 644 /etc/ssh/sshd_config.d/10-omarchy-server.conf

# sshd checks no config without host keys. Keys the installer already put in
# place are kept.
ssh-keygen -A

# sshd takes the first value it reads for each setting, so an earlier rule
# could still let passwords or root in. Stop the install rather than boot a
# server that does.
effective=$(sshd -T)
for setting in "permitrootlogin no" "passwordauthentication no" "kbdinteractiveauthentication no"; do
  if ! grep -qixF "$setting" <<<"$effective"; then
    echo "sshd does not apply '$setting'" >&2
    exit 1
  fi
done
