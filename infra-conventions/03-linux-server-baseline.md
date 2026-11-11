# Linux Server Baseline

## Summary

Every server runs a supported long-term-support release of one distribution, installed minimal, patched automatically for security fixes, rebooted in a planned window and rebuilt from files in a repository. People reach it only over SSH with keys, one account each; the provider's firewall, the host firewall and the way Docker publishes ports are each set deliberately, because Docker publishes around `ufw`. The server's clock is UTC, its logs outlive the containers, and its Docker daemon has rotating logs and live restore. After provisioning, and every quarter, you check what the server actually exposes from the outside.

## Rules

### Operating system and patching

- Run **Ubuntu Server LTS** (26.04 "resolute", standard support to 2031-05-29; 24.04 is also supported) or **Debian stable** (13 "trixie", 13.7, end of life 2030-06-30). One distribution family across the fleet. Debian 11 reached the end of its regular support on 2026-08-31 (endoflife.date lists extended support to 2031-06-30), so a machine still on it needs a decision, not neglect. A new server gets the newest LTS; move an old one at the latest six months before its end of support.
- Install the minimum: no desktop, no compilers, no database or web server unless the server's role is that service. Install packages from the distribution and from the two vendor repositories you document in the runbook (Docker, and nginx.org if you use it). Never `curl | sh`.
- **Turn on automatic security updates** with `unattended-upgrades`. Its two files are `/etc/apt/apt.conf.d/20auto-upgrades` (whether and how often it runs) and `/etc/apt/apt.conf.d/50unattended-upgrades` (which origins, which packages are held back, mail reports). On a fresh install, check the first run with `sudo unattended-upgrade --dry-run`.

```text
# /etc/apt/apt.conf.d/20auto-upgrades
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
```

- **Reboot in a planned window.** Kernel and library updates need a reboot, and `unattended-upgrades` can do it: `Unattended-Upgrade::Automatic-Reboot` is `false` by default and `Automatic-Reboot-Time` takes `"hh:mm"`. Ubuntu's documentation warns that reboots can be very disruptive if the system does not come back. Choose one of two policies per server and write it in its record: automatic reboot at a quiet hour for a server that restarts cleanly, or a monthly manual window with a check for the reboot flag the distribution sets.
- Docker Engine updates are a separate monthly task, not part of the unattended run. Read the release notes of the new version first: 29.9.3 (2026-11-03) carried several security fixes. With `live-restore` ([Docker daemon](#docker-daemon)), restarting the daemon leaves containers running; a reboot does not.

### Accounts and sudo

- One account per person; no shared logins. Administrators are in the `sudo` group. Remove a person's account and keys on the day they leave. Service accounts have no shell (`/usr/sbin/nologin`) and no password.
- **Membership of the `docker` group is root access**, because whoever can reach the Docker socket controls the host (OWASP, rule 1). Only administrators and the restricted deploy user ([CI/CD](10-ci-cd-and-deployment.md#deploying-over-ssh)) belong to it. Never expose the daemon on a TCP port, and never mount the socket into a container.
- Review accounts, groups and `authorized_keys` every quarter ([checklists](14-checklists.md)).

### SSH

- Put the hardening in a drop-in file named so that it is read first. On Debian and Ubuntu the main `sshd_config` includes `/etc/ssh/sshd_config.d/*.conf`. The manual says that for each keyword "the first obtained value will be used", so `00-hardening.conf` wins over a later file, such as the `50-cloud-init.conf` that a cloud image may add to switch passwords on.

```text
# /etc/ssh/sshd_config.d/00-hardening.conf
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin no
PubkeyAuthentication yes
AuthenticationMethods publickey
AllowGroups ssh-users
MaxAuthTries 3
LoginGraceTime 30
X11Forwarding no
ClientAliveInterval 300
ClientAliveCountMax 2
```

- The defaults this file replaces: `PasswordAuthentication yes`, `KbdInteractiveAuthentication yes`, `PermitRootLogin prohibit-password`, `MaxAuthTries 6` and `LoginGraceTime 120`. All the keywords above exist in the OpenSSH `sshd_config` manual.
- `AllowGroups ssh-users` only lets that group in. Create the group and add yourself and the deploy user before you enable the line, or you lock yourself out.
- **Change SSH safely.** Keep a second session open, run `sudo sshd -t` (it tests the configuration), then `sudo systemctl reload ssh` (the service is `ssh` on Debian and Ubuntu). Open a third session to prove that a new login works before you close the others.
- OpenSSH (10.6 on 2026-11-11) penalises sources by default: `PerSourcePenalties` refuses a source for a few seconds after failed authentication, invalid users or an expired login grace time, and for up to ten minutes when the penalties add up. That removes most of the noise of password guessing, so fail2ban is optional for SSH ([abuse control](07-abuse-control-and-edge-protection.md#fail2ban)).
- Keys: Ed25519, one per person per device, with a passphrase. A forwarded agent is off. `AllowTcpForwarding` stays at its default, because disabling it improves nothing unless the user has no shell either, as the manual points out.
- Do not reach a database through an SSH tunnel to a published port: databases publish no port ([databases](09-databases-and-data-stores.md#placement)).

### Firewall

- **Three layers, each set on purpose:** the cloud provider's security group (allow 80 and 443 from anywhere; allow 22 only from known addresses), the host firewall, and the way Docker publishes ports.
- With `ufw` (the front end that ships with Ubuntu): default deny incoming, allow outgoing, then add only what the server serves.

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow proto tcp from 203.0.113.0/24 to any port 22
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
sudo ufw status verbose
```

- **`ufw` does not filter published container ports.** The Docker documentation states that Docker and `ufw` are incompatible: Docker routes the traffic in the `nat` table, "before it reaches the `INPUT` and `OUTPUT` chains that ufw uses", so a published port ignores your rules. Publishing a port opens it to the outside world unless the mapping names the loopback address. Therefore: publish on `127.0.0.1` ([Compose](05-compose-and-container-runtime.md#ports-and-networks)), run `bin/check_published_ports`, and scan the server from another network after every provisioning and every deploy that touches ports.
- When a published port must be restricted by source address, put the rule in the `DOCKER-USER` chain, the one Docker keeps for your rules, for example `iptables -I DOCKER-USER -i eth0 ! -s 203.0.113.10 -j DROP` (the pattern in Docker's documentation; replace `eth0` with the external interface). Persist it with the tool your distribution offers, and test it after a reboot. This was not run here.
- Leave Docker's own firewall management on, and stay on the iptables backend: the nftables backend of Docker 29 is marked experimental.
- Repeat the outside scan over IPv6 when the host has an address: Docker publishes on `[::]` as well.

### Docker daemon

- Configure the daemon in `/etc/docker/daemon.json`:

```json
{
  "log-driver": "local",
  "log-opts": {
    "max-size": "10m",
    "max-file": "5"
  },
  "live-restore": true
}
```

- **`log-driver: local`** is Docker's recommendation against disk exhaustion: the default `json-file` driver does no log rotation, while `local` rotates by default (20 MB and five files, compressed) and uses a more efficient format. The values above keep 50 MB per container. A change applies only to containers created afterwards; recreate the existing ones (`docker compose up -d --force-recreate`) to apply it.
- **`live-restore: true`** keeps containers running when the daemon stops for a crash, an upgrade or a planned restart, which shortens downtime.
- Leave the daemon's own log level at `info`. Run it as root with the hardening of the [Compose note](05-compose-and-container-runtime.md#runtime-hardening); rootless mode is an option with limits (OWASP, rule 11), not the default of this set.
- Do not run `docker system prune --volumes` on a server; it removes volumes that nothing uses at that moment, which can be your database.

### Disk, time and logs

- **UTC everywhere.** Set the server clock with `timedatectl set-timezone UTC` and keep a time-synchronisation service (`systemd-timesyncd` or `chrony`) running. A single zone makes logs from the server, the containers, the provider and the vendors comparable ([logging](11-logging-monitoring-and-alerting.md#logs)). Services convert to local time at the edge.
- Watch disk space and inodes of `/`, `/var/lib/docker`, the database volume and `/var/log`; alert at 80 percent ([alerts](11-logging-monitoring-and-alerting.md#alerts)). Put the database volume on its own disk when you can.
- Keep the journal across reboots and cap it. Without a cap, the journal grows to a share of the disk.

```text
# /etc/systemd/journald.conf.d/persistent.conf
[Journal]
Storage=persistent
SystemMaxUse=1G
```

- Rotate files under `/var/log` with logrotate (the nginx packages install their own policy). Ship the logs off the host ([logging](11-logging-monitoring-and-alerting.md#logs)), so that a compromise of the server does not erase them.

### Checking the server

- After provisioning, and quarterly, check what is exposed. From another network, scan all TCP ports of the public address (the MySQL manual's check for its own port is an `nmap` scan or a `telnet` to the port). On the host, list listeners with `sudo ss -tulpn` and compare them with the list in the server's record. Run `bin/check_published_ports`.
- Run Lynis, an open source auditing tool for Linux, after provisioning and each quarter, and either fix its findings or write down why not.
- Keep a one-page record per server in the infra repository: role, owner, distribution and end-of-support date, expected open ports, who has access, the reboot policy, where its backups go, when the last restore drill was.

### Building the server from code

- A server is rebuilt from the repository: an idempotent provisioning script (in Bash, per the [Bash set](../bash-conventions/08-scripts-and-command-line.md)) or a configuration-management tool, plus the files in this note. A change made by hand on the server is committed to the repository the same day ([principles](01-principles-and-sources.md#principles)).
- Prove it once a year by building a server from nothing ([backups](12-backups-and-recovery.md#restore-drills)). Every manual step you needed is a defect in the script.

## Sources and raw notes

Pages read on 2026-11-11:

- Ubuntu Server documentation: [Automatically update packages](https://documentation.ubuntu.com/server/how-to/software/automatic-updates/) (`unattended-upgrades`, `20auto-upgrades`, `50unattended-upgrades`, `--dry-run`, reboots) and [Firewalls](https://documentation.ubuntu.com/server/how-to/security/firewalls/) (`ufw` commands). Release data: the [Ubuntu LTS meta-release list](https://changelogs.ubuntu.com/meta-release-lts), the [Debian `stable` Release file](https://deb.debian.org/debian/dists/stable/Release) (13.7, 2026-09-12) and endoflife.date for [Ubuntu](https://endoflife.date/api/ubuntu.json) and [Debian](https://endoflife.date/api/debian.json).
- OpenBSD manual [`sshd_config(5)`](https://man.openbsd.org/sshd_config) (first obtained value, `Include`, defaults, `PerSourcePenalties`, `AllowTcpForwarding`) and the [OpenSSH release notes](https://www.openssh.com/releasenotes.html) (10.6, 2026-10-06).
- Docker: [Packet filtering and firewalls](https://docs.docker.com/engine/network/packet-filtering-firewalls/) (`ufw`), [Docker with iptables](https://docs.docker.com/engine/network/firewall-iptables/) (`DOCKER-USER`), [Docker with nftables](https://docs.docker.com/engine/network/firewall-nftables/), [Configure logging drivers](https://docs.docker.com/engine/logging/configure/), [local file logging driver](https://docs.docker.com/engine/logging/drivers/local/), [Live restore](https://docs.docker.com/engine/daemon/live-restore/), [Rootless mode](https://docs.docker.com/engine/security/rootless/) and the [Engine 29 release notes](https://docs.docker.com/engine/release-notes/29/).
- [OWASP Docker Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Docker_Security_Cheat_Sheet.html) (rules 0, 1, 5a, 10, 11); [systemd `journald.conf`](https://www.freedesktop.org/software/systemd/man/latest/journald.conf.html) (`Storage=`, `SystemMaxUse=`); [Lynis](https://cisofy.com/lynis/); [MySQL 8.4 Security Guidelines](https://dev.mysql.com/doc/refman/8.4/en/security-guidelines.html) (scan the port from outside); the [Go set](../golang-conventions/01-principles-and-sources.md) for UTC.
- Not read for this note, and not run: the `ufw` and `DOCKER-USER` commands on a real host, `sshd -t` on the drop-in file (the keywords were checked against the manual) and the `unattended-upgrades` files. Run them on a test server before you rely on them.
