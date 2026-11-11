# Logging, Monitoring and Alerting

## Summary

Every service writes events to stdout as JSON lines with a UTC time and a request ID. The host rotates what Docker and the journal collect, and a shipper copies it off the host, so that a compromised server cannot erase its own history. Monitoring measures the four golden signals of each user-facing service plus the health of the host, the containers, the data stores, the certificates and the backups. Alerts are few and tied to symptoms or to silence, each one names its first action and links to a runbook, and a separate small set watches for the signs of abuse: refusals, bans, firewall hits, database errors and unexpected listeners. The thresholds here are starting values; tune them from your own baselines.

## Rules

### Logs

- **Write events to stdout and stderr, one per line.** The Twelve-Factor app "never concerns itself with routing or storage of its output stream"; the environment captures it. In Compose, Docker collects it with the `local` driver ([server](03-linux-server-baseline.md#docker-daemon)); host services use the journal.
- **Format: JSON, one object per line**, with at least `time` (UTC, RFC 3339), `level`, `msg`, and, for requests, `request_id`, `method`, `path`, `status` and `duration`. A constant message with the data in fields is searchable; a sentence with the data inside is not ([Go note](../golang-conventions/11-service-practices.md)). nginx writes the same shape ([nginx](06-nginx-reverse-proxy.md#logging)).
- **One identifier joins the lines.** nginx generates `$request_id` and forwards it as `X-Request-ID`; the application logs it on every line it writes for that request; the WAF's audit entries and the database errors the application logs carry it too. An investigation then follows one request through every layer.
- **Log the events that matter.** OWASP lists them: input validation failures, authentication successes and failures, authorisation failures, application errors including syntax and runtime errors, start-ups and shut-downs, use of administrative privileges, user-administration actions, access to sensitive data, data import and export, and suspicious business-logic activity. OWASP also warns that a blind checklist produces "alarm fog", so choose events in proportion to the risk of each system.
- **Keep secrets and personal data out.** Do not record passwords, access tokens, session identifiers, database connection strings, keys, bank-account or card data, or health and government identifiers; remove, mask or hash them (OWASP "Data to exclude"). Nothing secret travels in a URL, because the access log records it ([secrets](08-secrets-and-configuration.md#delivering-secrets)). Logs that contain personal data are personal data: they fall under the same access control and retention rules.
- **Retention is a decision, written in the runbook.** The default of this set is 90 days searchable and 12 months in compressed storage. A financial regulator, a contract or a payment standard can require longer; the strictest rule that applies to the system wins. These numbers are a recorded decision ([decisions](01-principles-and-sources.md#decisions-to-review)).
- **Rotate on the host:** Docker's `local` driver for containers (50 MB per container with the values in the server note), a capped journal for system services, logrotate for files such as `/var/log/nginx/*.log`. A log that can fill the disk will, at the worst moment.
- **Ship the logs off the host.** Use any shipper that reads the journal and the Docker logs and writes to a store outside the host: the provider's log service, Loki, an object store. OWASP's list of attacks on logs includes tampering and deletion by an intruder. An off-host copy keeps the history after the host is lost, and a second reason is that the application's own logs vanish with the container otherwise. Alert when shipping stops ([alerts](#alerts)).
- **Time is UTC and synchronised** on every host and service, or events from two systems cannot be put in order ([server](03-linux-server-baseline.md#disk-time-and-logs)).
- Restrict who can read logs, and treat access to them as sensitive. Keep the log store's credentials out of the application hosts' write path where you can: the host can add lines, only an administrator can delete.

### Metrics

- **Measure the four golden signals** for each user-facing service: latency, traffic, errors and saturation. The Google SRE book's advice is that "if you can only measure four metrics of your user-facing system, focus on these four". Sources: the nginx access log (status and `request_time`), the application's own metrics, and an outside probe.
- **Measure the platform that carries them:**

| Area | What to measure |
| --- | --- |
| Host | CPU and load, memory and swap, out-of-memory kills, disk space and inodes of `/`, `/var/lib/docker`, the database volume and `/var/log`, disk errors, network errors, clock synchronisation, a pending reboot |
| Containers | Restarts, health status, memory use against the limit, out-of-memory kills |
| nginx | Request rate and status classes (2xx, 3xx, 4xx, 5xx), refusals (429), upstream errors, request time |
| Database | Connections against the maximum, slow queries, disk growth, replication lag where there is a replica, the age of the last backup, the client error counters ([databases](09-databases-and-data-stores.md#containment-and-detection)) |
| Certificates and domains | Days to expiry, seen from outside, and the expiry of the domain registration |
| Backups | Time since the last success, the size of the newest dump, the result of the last restore drill |

- **Use the smallest tool that tells a human in time.** The provider's monitoring, an external uptime checker, or Prometheus with Alertmanager and Grafana all work. Choose one place for alerts and one channel to reach the person on duty, and avoid running three tools that each know a third of the facts.
- **Probe from outside** your network, preferably from another provider: HTTPS reachable, certificate valid, expected content present. A probe on the same host cannot tell you that the host is unreachable. Add a probe of the sensitive flow (for example the submit form with a test account) only where it has no side effects.

### Alerts

- **Alert on symptoms that users feel**, and on silence, and keep the number small. Prometheus's practices say it directly: "keep alerting simple, alert on symptoms", have consoles that point to the cause, and "avoid having pages where there is nothing to do". Page on user-visible errors and latency at the top of the stack, not on every component below it. Allow for slack so that a blip does not wake anyone.
- **Every alert has a severity, a threshold with a duration, a first action and a link to the runbook.** *Page* means a person acts now, at any hour. *Ticket* means someone acts in working hours. An alert that never needs an action is deleted.
- The starting set (values are decisions to review after a month of data):

| Alert | Condition | Severity |
| --- | --- | --- |
| Site down | Outside probe fails three times in a row | Page |
| Errors | 5xx above 2 percent of requests for 5 minutes | Page |
| Latency | 95th percentile above the agreed limit for 10 minutes | Page |
| Disk | Above 80 percent for 15 minutes; above 90 percent | Ticket; page |
| Memory | A container is out-of-memory killed, or the host is above 90 percent for 10 minutes | Page |
| Container | More than three restarts in 15 minutes, or unhealthy for 5 minutes | Page |
| Certificate | Fewer than 14 days to expiry | Page |
| Backup | No success heartbeat for 26 hours | Page |
| Backup size | Newest dump below half the previous one | Ticket |
| Restore drill | The monthly drill failed | Ticket |
| Log shipping | No lines from a host for 10 minutes | Page |
| Clock | A host is not synchronised | Ticket |
| Patching | Reboot pending for 14 days, or a supported Docker or nginx release is behind by a security fix | Ticket |

- **Alert on the monitoring itself.** Have the monitor send a heartbeat to an outside service, so that a dead monitor is noticed. Send a test alert through the whole path once a month, and give every silence an end date.
- **After every incident, add or repair the alert that should have caught it. Every quarter, delete the alerts nobody acted on.** ([runbooks](13-incident-response-and-runbooks.md#after-an-incident))

### Security signals

These watch for the signs of an attack on a public endpoint: brute force, scanning and injection probes. Compare each with its own baseline of the previous two weeks (rates at the same hour), not with a fixed number, and send them to tickets until you know the normal level; page only when a signal is certain and actionable.

| Source | Signal | What it suggests |
| --- | --- | --- |
| nginx access log | A rise in `429`, `403`, `404`, `400` or `413`; many different paths from one address; requests for `.env`, `.git`, `phpmyadmin` or `wp-login.php` | Rate limits tripping, scanning |
| nginx access log | `POST` volume on the submit or login endpoint far above the usual for that hour; query strings that contain `UNION`, `SELECT`, `--` or `%27` | Brute force or injection attempts |
| nginx error log | Lines `limiting requests` or `limiting connections` by zone | The same, from the limiter's point of view |
| fail2ban | New bans per hour above the norm | Repeated offenders |
| WAF | Anomaly-score blocks, or detections in detection-only mode, above the norm | Known attack patterns |
| Database | A rise in the client error counters (`ER_PARSE_ERROR`, `ER_BAD_FIELD_ERROR`, `ER_NO_SUCH_TABLE`); a new account or a changed privilege; a login from an unexpected host | Injection probes, tampering |
| Application | Failed logins per account, lockouts, password resets, exports, administrator actions | Credential attacks, abuse |
| Host | Failed SSH logins, `sudo` use, a new user, a changed `authorized_keys` or `sshd_config`, a new listening port, a container not in the Compose file | Intrusion or drift |
| Pipeline | `bin/check_published_ports` finds a port published on all interfaces | A mistaken exposure |

- Log shipping and these signals are only useful if somebody looks. Put a 15-minute review of the signals in the weekly routine ([checklists](14-checklists.md)).
- Keep two weeks of the nginx access logs hot at the least, because an investigation starts from them. The longer retention above covers the rest.

## Sources and raw notes

Pages read on 2026-11-11:

- [The Twelve-Factor App: Logs](https://12factor.net/logs) (event streams on stdout, routing owned by the environment).
- [OWASP Logging Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Logging_Cheat_Sheet.html) (which events to log, data to exclude, attacks on logs, alarm fog).
- Google SRE book, [Monitoring Distributed Systems](https://sre.google/sre-book/monitoring-distributed-systems/) (the four golden signals) and the Prometheus documentation, [Alerting](https://prometheus.io/docs/practices/alerting/) (symptoms, few alerts, slack, runbook links).
- Docker: [Configure logging drivers](https://docs.docker.com/engine/logging/configure/) and [local file logging driver](https://docs.docker.com/engine/logging/drivers/local/); [systemd `journald.conf`](https://www.freedesktop.org/software/systemd/man/latest/journald.conf.html); [nginx log module](https://nginx.org/en/docs/http/ngx_http_log_module.html).
- [Let's Encrypt: decreasing certificate lifetimes to 45 days](https://letsencrypt.org/2025/12/02/from-90-to-45) (monitoring so that a missed renewal raises an alert).
- The error counters of the database and the check of the error log are from the runs described in the [databases note](09-databases-and-data-stores.md#sources-and-raw-notes). The thresholds, the retention periods and the signal list are decisions of this set; none of them was run against a monitoring system.
