# Omarchy Server

Omarchy Server is the headless edition: no Hyprland, no Omarchy shell, reached over SSH. `/etc/omarchy/edition` holding `server` marks it, and `omarchy-edition` prints the answer. The installer writes that file; nothing in this repo does. How the router hides desktop commands is in [cli-router.md](cli-router.md).

## Packages and code

The installer pacstraps `install/omarchy-server.packages` in place of `install/omarchy-base.packages`, and `omarchy-pkg-defaults` prints it on a Server. The `omarchy` and `omarchy-dev` packages depend on the desktop, so a Server installs neither. It runs Omarchy from a git checkout in `~/omarchy` through the dev channel: `omarchy-channel-set dev` links the checkout and installs only the settings package, and refuses every other channel. `omarchy update` fast-forwards the checkout like on any dev-linked machine.

## Install

`install/config/all.sh` and `install/user/all.sh` skip the desktop leaves on a Server. In their place `install/config/server/` enables sshd, turns on a firewall that lets in only rate-limited SSH, writes `/etc/ssh/sshd_config.d/10-omarchy-server.conf` (keys only, no root login, checked against `sshd -T`), gives the install user passwordless sudo in `/etc/sudoers.d/omarchy-server-owner`, and readies rootless Podman: subordinate IDs, lingering and `podman-restart`.

## Login

`/etc/profile.d/omarchy.sh` sources `default/bash/server-login`, which runs `om status` (`omarchy-status`) for an interactive login at a terminal. Commands over SSH, scp, sftp, root shells and tmux panes stay quiet. The lines use ✓ for working, ⚠ for a problem and ○ for a setup step still to do; `omarchy-server-setup-steps` lists those steps (storage, backups, agent).

## Updates

On a Server, `omarchy update` runs `omarchy-server-update-watch record` once the update is confirmed. It keeps sshd, tailscaled, network mounts and the owner's Quadlet and `container-*` user units that are up, with the boot ID. At the first login after a later boot, `compare` keeps those that are down, and the login lines and the Services row of the menu show them until they come back.

## Menu

`omarchy menu` on a Server runs `omarchy-server-menu`, an fzf list. Icons show only when `TERM` names a terminal known to draw Nerd Font symbols.
