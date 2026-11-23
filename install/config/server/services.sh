# Omarchy Server's services. Enable only: the install is followed by a reboot.
# NetworkManager-wait-online stays on, unlike the desktop: network mounts and
# container units wait on network-online.target to find the network up.
systemctl enable linux-modules-cleanup.service
systemctl enable systemd-resolved.service
systemctl enable NetworkManager.service
systemctl enable NetworkManager-wait-online.service
systemctl enable systemd-oomd.service
systemctl enable sshd.service
