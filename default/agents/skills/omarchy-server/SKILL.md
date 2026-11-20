---
name: omarchy
description: >
  REQUIRED for managing an Omarchy Server machine: the headless edition of Omarchy, with no Hyprland,
  no display and no desktop session, reached over SSH. Triggers: system updates, snapshots and
  rollback, packages, containers with rootless Podman, Tailscale, NAS and other network mounts, the
  firewall, opening or publishing a port, tunnels, SSH access, systemd services, and omarchy
  commands. Desktop topics (themes, keybindings, monitors, the bar, screenshots, launchers) do not
  apply to this machine. Not for Omarchy source development (`omarchy dev link`).
---

# Omarchy Server skill

This machine runs Omarchy Server, the headless edition of [Omarchy](https://omarchy.org/). It is Arch Linux with Omarchy's update, snapshot and package tooling, administered over SSH. `omarchy edition` prints `server` here and `desktop` on a desktop install.

This skill is for administering an installed server. Developing Omarchy itself follows the repository's own instructions.

## What this machine does without

There is no Hyprland, no display and no desktop session. The Omarchy shell (bar, dock, notifications, menus), themes, fonts, screenshots, launchers and web apps have nothing to run on.

- Desktop config paths such as `~/.config/hypr/`, `~/.config/omarchy/shell.json` and `~/.config/uwsm/` are unused. Creating or editing them changes nothing.
- A command that needs the desktop refuses to run: it prints one line to stderr and exits non-zero. Pick another route when that happens; retrying gives the same answer.
- Advice written for desktop Omarchy, including most of the Omarchy manual, assumes a session this machine lacks. Check that a command is listed here before suggesting it.

## Finding the commands that work here

`omarchy <group> <command>` dispatches to the `omarchy-*` binaries. The listings already leave out everything that needs the desktop.

```bash
omarchy commands --json             # every command this machine can run
omarchy commands --all --json       # adds hidden and desktop-only commands; the latter carry "available": false
omarchy --help                      # command groups
omarchy <group> --help              # commands in one group
omarchy <group> <command> --help    # help for one command, without running it
cat "$(which omarchy-snapshot)"     # a command's source
```

For diagnostics, run `omarchy-debug --no-sudo --print` directly.

## What is here

### Updates and snapshots

Always update with `omarchy update`, never `pacman -Syu` or `yay -Syu`. Omarchy's update takes a snapshot first and runs its migrations with the new packages.

```bash
omarchy update              # snapshot, packages, migrations
omarchy snapshot create     # snapshot now, before a risky change
omarchy snapshot restore    # roll back to an earlier snapshot
omarchy version
```

Take a snapshot before changing packages, system services or anything under `/etc/`.

### Packages

```bash
omarchy pkg add <packages...>       # install from the configured repositories
omarchy pkg aur add <packages...>   # install from the AUR
omarchy pkg drop <packages...>      # remove
```

### Containers

Containers run under rootless Podman, as the logged-in user and without `sudo`.

```bash
podman ps --all
podman logs <container>
systemctl --user list-units --type=service
```

Find out how an existing container is started (a systemd user unit, a Quadlet file under `~/.config/containers/systemd/`, or a compose file) before changing it, and change it there so the fix survives a reboot.

### Tailscale

```bash
tailscale status
tailscale ip
```

Tailscale may be the only way this machine is reached. Do not run `tailscale down`, `tailscale logout` or change its routes without asking first.

### NAS and network mounts

```bash
findmnt --types nfs,nfs4,cifs       # what is mounted, and from where
cat /etc/fstab
systemctl list-units --type=mount
```

A path under a mount lives on another machine. Check `findmnt` before writing large amounts of data, changing ownership recursively or deleting, and confirm a mount is present before a job writes to it, so nothing fills the local disk by mistake.

### Firewall

UFW denies incoming connections by default and allows outgoing ones.

```bash
sudo ufw status verbose
```

### SSH

```bash
omarchy setup security sshd [--key=<public-key>] [--gh-keys <github-username>]
omarchy remove security sshd
```

You are most likely working through SSH yourself. Ask before restarting or disabling `sshd`, editing `/etc/ssh/`, changing authorized keys or touching the firewall rule that admits SSH, since a mistake there locks everyone out of a machine with no screen.

## Safety rules

**Never modify anything in `/usr/share/omarchy/`.** The omarchy package owns that directory, and the next `omarchy update` overwrites local changes. Reading it is safe and useful for understanding how a command works. Put your own configuration under `~/.config/` or `/etc/`.

**Ask before publishing any port or tunnel.** That covers a `ufw allow` rule, a container port bound to anything other than `127.0.0.1`, `tailscale serve`, `tailscale funnel`, a reverse SSH tunnel and a port forward on the router. Say what would become reachable and from where, then wait for a yes. Bind new services to `127.0.0.1` until then.

**Use `sudo` for privileged commands.** An SSH session is a terminal, so the password prompt works there. This machine has no graphical prompt to fall back on: when no terminal is available to enter a password, ask the user to run the command. Leave `sudo` off commands that ask for it themselves, such as `omarchy update`.
