run_logged "$OMARCHY_INSTALL/config/pacman-keyring.sh"
run_logged "$OMARCHY_INSTALL/config/ssh-command-path.sh"
run_logged "$OMARCHY_INSTALL/config/ssh-keepalive.sh"
run_logged "$OMARCHY_INSTALL/config/locale.sh"
run_logged "$OMARCHY_INSTALL/config/language.sh"
run_logged "$OMARCHY_INSTALL/config/snapper.sh"

# Omarchy Server has no display, browser or lock screen, and is reached over
# SSH, so it gets its own services, firewall and access rules.
if [[ $(omarchy-edition) == "server" ]]; then
  run_logged "$OMARCHY_INSTALL/config/server/services.sh"
  run_logged "$OMARCHY_INSTALL/config/server/firewall.sh"
  run_logged "$OMARCHY_INSTALL/config/server/sshd.sh"
  run_logged "$OMARCHY_INSTALL/config/server/sudo.sh"
  run_logged "$OMARCHY_INSTALL/config/server/podman.sh"
else
  run_logged "$OMARCHY_INSTALL/config/theme-system.sh"
  run_logged "$OMARCHY_INSTALL/config/browser-policy.sh"
  run_logged "$OMARCHY_INSTALL/config/increase-lockout-limit.sh"
  run_logged "$OMARCHY_INSTALL/config/lockscreen-pam.sh"
  run_logged "$OMARCHY_INSTALL/config/docker.sh"
  run_logged "$OMARCHY_INSTALL/config/enable-services.sh"
  run_logged "$OMARCHY_INSTALL/config/firewall.sh"
fi
