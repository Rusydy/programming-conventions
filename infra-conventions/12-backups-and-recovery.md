# Backups and Recovery

## Summary

A backup you have not restored is a hope. Back up every database and every set of user files on a schedule, keep the copies encrypted and off the server, under credentials that the server cannot use to delete them, and get an alert when a backup is missing. Each month restore the newest copy into a scratch server and compare it with production; each year rebuild a whole server from the repository and the backups. Write down, per service, how much data you can lose (the recovery point objective) and how long you can be down (the recovery time objective), and choose the schedule to fit those numbers. After an incident, a trustworthy backup from before the attack, and a log that tells you when it began, are what let you recover.

## Rules

### What to back up

| Data | Method | Notes |
| --- | --- | --- |
| Relational databases | A consistent logical dump every night, plus the binary logs when the recovery point objective is shorter than a day | The dump and the logs travel off the server together |
| Files that users upload (volumes, object storage) | A snapshot of the volume or a copy of the bucket, with versioning on | Treat it like the database: it is customer data |
| Configuration | Git | Nothing to back up if every change is committed ([principles](01-principles-and-sources.md#principles)) |
| Secrets | The secret manager's own backup, or an encrypted offline export | Never in the same repository as the data backups ([secrets](08-secrets-and-configuration.md)) |
| The server | Rebuild from the repository (and a provider snapshot as a bonus) | A snapshot does not replace a tested rebuild |

- Do not back up what you can rebuild: images, container layers and caches.
- Every new data store gets its backup before it gets its first user. A new volume in a Compose file is a prompt to ask where its backup is.

### Where the copies go

- **Keep copies off the server, encrypted, under other credentials.** CISA's ransomware guide advises "offline, encrypted backups of critical data", tested regularly, because many ransomware variants "find and subsequently delete or encrypt accessible backups". Anyone who takes over the server must not be able to erase the history: write to the backup store with credentials that can add snapshots but not delete them, and run the pruning from another machine with its own credentials.
- Use at least two copies in two places, one of them in a different provider account or region. A second copy in the same account protects against a mistake; it does not protect against a stolen credential.
- **restic** is the default tool for files and dumps. It encrypts with a key you hold ("confidentiality and integrity"), deduplicates, stores snapshots, and supports many storage backends. This is a recorded decision ([decisions](01-principles-and-sources.md#decisions-to-review)). Keep the repository password in the secret store and an offline copy of it elsewhere; without it, the backups are unreadable.
- Databases that are large for a nightly dump (hours, or gigabytes you cannot ship each night) need a physical or parallel method: the MySQL manual points to MySQL Shell's dump utilities for parallel dumps and, for the Enterprise edition, MySQL Enterprise Backup. Choose by measuring the restore time, not the backup time.

### How to take the database backup

- For MySQL: `mysqldump --single-transaction --routines --triggers --events --no-tablespaces DATABASE`, run as the dedicated backup account ([databases](09-databases-and-data-stores.md#accounts-and-privileges)) from a short-lived container of the **server's own version** on the internal network. Credentials go in an option file, never on the command line.
- Stream the dump straight into restic with `restic backup --stdin-from-command --stdin-filename shop.sql -- COMMAND`. restic uses the command's exit code: "a non-zero exit code from the command causes restic to cancel the backup", and no snapshot is made. A plain pipe into `restic backup --stdin` cannot detect an incomplete dump, which is the reason for choosing this form. No plain-text dump touches the disk.
- Keep the binary log when the recovery point objective is under a day. MySQL enables it by default (`log_bin` is on); only the run that initialises the data directory has it off. After a restore, the server re-executes the events recorded after the backup, which brings the data forward to a chosen moment ("point-in-time recovery"). Copy the binary logs off the server on a schedule, and set a retention that outlasts the gap between two full backups. MySQL can encrypt them (`binlog_encryption`).
- Apply a retention policy with `restic forget --keep-daily 14 --keep-weekly 8 --keep-monthly 12 --prune`. These numbers are a recorded decision; change them to fit the recovery point objective and the rules your business is under.
- Check the repository, not just the last backup: run `restic check` weekly and `restic check --read-data-subset=n/t` for a slice of the data each time (restic also accepts a percentage or a size). A rotating slice reads the whole repository over `t` runs.

### Schedule and monitoring

- **Run backups from a systemd timer**, not a hand-edited crontab. The unit logs to the journal, `Persistent=true` runs a missed job when the machine starts again, and `RandomizedDelaySec` spreads the load. The units below were not run on a server.
- **Monitor the absence of a backup.** At the end of a successful run the script requests a heartbeat URL; the monitor alerts when no request has arrived for 26 hours. A failing job that prints an error nobody reads is the usual way backups die. Also alert when the size of the newest dump falls sharply, which usually means an empty or truncated dump ([alerts](11-logging-monitoring-and-alerting.md#alerts)).
- Use `Type=oneshot`, and keep the credentials in an `EnvironmentFile` that only root can read. The service runs as root because the script needs Docker. Make the script and the file root-owned and not writable by anyone else.

```ini
# /etc/systemd/system/backup-db.service
[Unit]
Description=Back up the shop database to restic
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
EnvironmentFile=/etc/backup/shop.env
ExecStart=/srv/shop/bin/backup_db
```

```ini
# /etc/systemd/system/backup-db.timer
[Unit]
Description=Daily database backup

[Timer]
OnCalendar=*-*-* 02:30:00
RandomizedDelaySec=15min
Persistent=true

[Install]
WantedBy=timers.target
```

- Enable it with `sudo systemctl enable --now backup-db.timer` and read the schedule with `systemctl list-timers`.

### Restore drills

- **Every month, restore the newest snapshot into a scratch server and compare it.** Start an empty server of the same version on a throwaway network, create the empty database, load the dump, then compare row counts of the key tables and the newest timestamp with production, and count the routines, triggers, views and events. Fail loudly if the numbers differ by more than the agreed margin. The restore through restic is `restic dump latest shop.sql | mysql ...`, as the restic manual shows.
- The MySQL side of this drill was run: a dump taken with exactly the flags above, as the backup account, was loaded into a second empty server; the two servers then agreed on every count (5 rows in the main table, 1 audit row, 1 procedure, 1 trigger, 1 view, 1 event). The restic and the Docker-network steps around it were not run here.
- **Every year, rebuild the whole thing**: a new server from the repository, the secret store and the backups only, in a clean account. Time it. That time is the recovery time objective you can honestly promise. Put what you learn in the runbook the same day ([runbooks](13-incident-response-and-runbooks.md#runbooks)).
- After any change of backup tool, key, schedule or storage, restore once. Run each drill with the credentials a brand-new machine would have, not the production server's, or it proves nothing about a real disaster.

### Recovery objectives

- Write both numbers for every service in its runbook, and have the people who own the business accept them. A nightly dump gives a recovery point objective of about 24 hours; the binary log gives minutes. A restore from object storage into a new server gives the recovery time you measured in the last drill, not the one you hope for.
- Keep the oldest backup you would need after a slow-burning problem. If an attacker or a bug quietly changed data three weeks ago, the monthly snapshots are what remain. Do not prune during an investigation ([incidents](13-incident-response-and-runbooks.md#containment)).

## Reference script

`bin/backup_db` is the script the systemd unit runs. It follows the [Bash set](../bash-conventions/01-principles-and-sources.md): a version guard, strict mode, `main`, no secrets in arguments. ShellCheck 0.11.0 and shfmt 3.14.1 pass with that set's configuration. Under Bash 5.2 with stub `docker`, `restic` and `curl` commands: without its environment it exited 1 with "RESTIC_REPOSITORY must be set"; with it, the calls were `restic backup ... --stdin-from-command -- docker run ... mysqldump ...`, then `restic forget ... --prune`, then the heartbeat request; when `restic backup` failed, the script stopped with exit 1 before `forget` and the heartbeat.

```bash
#!/usr/bin/env bash
#
# Back up one MySQL database into an encrypted restic repository.
#
# Usage: backup_db [-h | --help]
#
# Streams a consistent dump (mysqldump --single-transaction) straight into
# restic, so no plain-text dump touches the disk. restic creates no snapshot
# when mysqldump fails. Then it applies the retention policy and, after a
# successful run, requests a heartbeat URL so that a monitor can alert when
# backups stop arriving.
#
# Environment (set by the systemd unit from a file with mode 0600):
#   RESTIC_REPOSITORY     Where the snapshots go.
#   RESTIC_PASSWORD_FILE  File that holds the repository password.
#   BACKUP_MYSQL_OPTIONS  Path of a [client] option file with user and password.
#   BACKUP_NETWORK        Docker network of the database (default shop_backend).
#   BACKUP_DB_HOST        Database host on that network (default db).
#   BACKUP_DB_NAME        Database to dump (default shop).
#   BACKUP_MYSQL_IMAGE    Image with mysqldump, the server's version.
#   BACKUP_HEARTBEAT_URL  Optional. Requested after a successful run.
#
# Requires: Bash 4.4 or newer, Docker, restic, curl.

if ((BASH_VERSINFO[0] * 100 + BASH_VERSINFO[1] < 404)); then
  printf '%s: requires Bash 4.4 or newer (found %s)\n' \
    "${0##*/}" "${BASH_VERSION}" >&2
  exit 1
fi

set -euo pipefail
shopt -s inherit_errexit

readonly BACKUP_NETWORK="${BACKUP_NETWORK:-shop_backend}"
readonly BACKUP_DB_HOST="${BACKUP_DB_HOST:-db}"
readonly BACKUP_DB_NAME="${BACKUP_DB_NAME:-shop}"
readonly BACKUP_MYSQL_IMAGE="${BACKUP_MYSQL_IMAGE:-mysql:8.4.13}"

usage() {
  printf 'Usage: %s [-h | --help]\n' "${0##*/}"
}

main() {
  case "${1-}" in
    -h | --help)
      usage
      return 0
      ;;
    "") ;;
    *)
      printf '%s: unexpected argument: %s\n' "${0##*/}" "$1" >&2
      usage >&2
      return 2
      ;;
  esac

  : "${RESTIC_REPOSITORY:?RESTIC_REPOSITORY must be set}"
  : "${RESTIC_PASSWORD_FILE:?RESTIC_PASSWORD_FILE must be set}"
  : "${BACKUP_MYSQL_OPTIONS:?BACKUP_MYSQL_OPTIONS must be set}"

  # --no-tablespaces: the backup account has no PROCESS privilege.
  restic backup --tag mysql --stdin-filename "${BACKUP_DB_NAME}.sql" \
    --stdin-from-command -- \
    docker run --rm --network "${BACKUP_NETWORK}" \
    --volume "${BACKUP_MYSQL_OPTIONS}:/run/mysql.cnf:ro" \
    "${BACKUP_MYSQL_IMAGE}" \
    mysqldump --defaults-extra-file=/run/mysql.cnf --host "${BACKUP_DB_HOST}" \
    --single-transaction --routines --triggers --events --no-tablespaces \
    "${BACKUP_DB_NAME}"

  restic forget --tag mysql \
    --keep-daily 14 --keep-weekly 8 --keep-monthly 12 --prune

  if [[ -n "${BACKUP_HEARTBEAT_URL-}" ]]; then
    curl --fail --silent --show-error --max-time 10 --output /dev/null \
      -- "${BACKUP_HEARTBEAT_URL}"
  fi
}

main "$@"
```

## Sources and raw notes

Pages read on 2026-11-11:

- MySQL 8.4 Reference Manual: [Backup and Recovery](https://dev.mysql.com/doc/refman/8.4/en/backup-and-recovery.html), [Using mysqldump for Backups](https://dev.mysql.com/doc/refman/8.4/en/using-mysqldump.html) (MySQL Shell dump utilities), [Point-in-Time Recovery](https://dev.mysql.com/doc/refman/8.4/en/point-in-time-recovery.html) and [The Binary Log](https://dev.mysql.com/doc/refman/8.4/en/binary-log.html) (on by default, re-execution after a restore, `binlog_encryption`).
- restic: the [README](https://github.com/restic/restic) (secure, backends), [Backing up](https://restic.readthedocs.io/en/stable/040_backup.html) (`--stdin-from-command`, `--stdin-filename`, exit-code behaviour, the warning about `--stdin`), [Removing backup snapshots](https://restic.readthedocs.io/en/stable/060_forget.html) (`--keep-*`, `--prune`), [Working with repositories](https://restic.readthedocs.io/en/stable/045_working_with_repos.html) (`check`, `--read-data-subset`) and [Restoring from backup](https://restic.readthedocs.io/en/stable/050_restore.html) (`dump`).
- [CISA #StopRansomware Guide](https://www.cisa.gov/stopransomware/ransomware-guide): offline, encrypted, tested backups; the incident response plan.
- [systemd.timer](https://www.freedesktop.org/software/systemd/man/latest/systemd.timer.html): `OnCalendar=`, `Persistent=`, `RandomizedDelaySec=`.
- [OWASP Database Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Database_Security_Cheat_Sheet.html): regular backups with protected permissions, ideally encrypted.
- Runs: the dump, restore and comparison on `mysql:8.0` (two servers on a Docker network), and the script tests under Bash 5.2.15, as described above.
