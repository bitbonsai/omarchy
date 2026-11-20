# Nothing comes in but SSH, rate limited against brute force. Everything goes out.
ufw default deny incoming
ufw default allow outgoing
ufw limit 22/tcp comment "omarchy-sshd"

# Installs are followed by reboot, so turn UFW on for the installed system and
# leave the live install session's firewall as it is.
sed -i 's/^ENABLED=.*/ENABLED=yes/' /etc/ufw/ufw.conf
systemctl enable ufw
