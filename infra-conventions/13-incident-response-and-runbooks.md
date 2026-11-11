# Incident Response and Runbooks

## Summary

Prepare before anything happens: a short runbook for every service, and a one-page incident plan with named roles, a channel that works when the main one is compromised, a safe place for evidence, and the contacts you will need. During an incident, contain first, preserve the evidence, then find the scope, fix the cause, recover from something you trust and tell the people who must be told. Afterwards, write a blameless review with owners and dates, and change the alerts, the limits and these notes. The playbook below is for the case that motivates several notes in this set: a public endpoint that is brute-forced or injected with SQL. Exercise it twice a year.

## Rules

### Runbooks

- **Every service has `docs/runbook.md`** in its repository, short enough to read at three in the morning. It holds: what the service does and who owns it; a sketch of the hosts, ports and dependencies; where the logs, dashboards and backups are; how to deploy and roll back ([CI/CD](10-ci-cd-and-deployment.md#the-deploy-script)); how to restore from a backup ([backups](12-backups-and-recovery.md)); how to rotate each secret ([secrets](08-secrets-and-configuration.md#inventory-and-rotation)); a table of the alerts and the first action for each ([alerts](11-logging-monitoring-and-alerting.md#alerts)); the recovery point and time objectives; the end-of-support dates of the software it runs ([databases](09-databases-and-data-stores.md#versions)); and the dates of the last backup restore and the last rollback rehearsal.
- **Test a runbook by having someone who did not write it follow it on staging.** Every question they ask is a missing line.
- Keep the runbook where an administrator can read it when the main systems are down: in the repository and as a printed or offline copy. CISA asks for "a hard copy of the plan and an offline version".
- A server has its own record ([server](03-linux-server-baseline.md#checking-the-server)). The incident plan below lives in the infra repository and links to both.

### The incident plan

- **Roles:** an incident lead who decides and does not type commands, a technical lead who investigates, a communications lead who talks to management, customers and authorities, and a scribe who keeps the timeline. Name a deputy for each. In a small team one person holds two roles; the lead and the scribe are never the same person.
- **Channels:** a primary channel and an out-of-band one (phone numbers, a second messaging system). CISA's advice is to isolate systems in a coordinated manner and to use out-of-band communication, because an intruder may watch your normal channels and move on if they see you react.
- **Contacts:** the hosting provider's support, the registrar, the people who decide on legal and regulatory notification, management, and anyone who can approve taking a service offline. Keep their numbers outside the systems that may be down.
- **Authority:** write down who may take a service offline, who may spend money on outside help, and who may speak to regulators and customers. Deciding that during the incident costs hours.
- **Severity:** define two or three levels in terms of customer impact and data involved, with what each one triggers.
- **Evidence store:** a write-once or access-limited location outside the affected hosts, with a person responsible for it.
- **Exercise it twice a year** with a scenario: an injection on the submit endpoint, a leaked deploy key, a lost database volume. CISA asks that the plan be "regularly exercised". After the exercise, fix what did not work.

### Containment

For a suspected attack on a public endpoint (brute force, scanning, injection). Do the steps in order, and write each one in the timeline with its UTC time.

1. **Declare it.** Name the lead and open the channel. Start the timeline. Stop unrelated deployments and migrations.
2. **Preserve the evidence before you change anything that destroys it.** Copy to the evidence store, with hashes (`sha256sum`): the nginx access and error logs, the application logs and the WAF audit log for the whole period, the database error counters and, if enabled, its slow-query and audit logs, `docker ps -a --no-trunc` and `docker inspect` of the containers, the list of listeners (`ss -tulpn`), the SSH and `sudo` entries of the journal, and `docker events`. For a cloud server, take a snapshot of the volumes: CISA advises a point-in-time copy for later forensic review. **Do not reboot, prune, run `docker compose down -v` or restore over the data yet.** Powering a host off loses what is only in memory; do it only if you cannot isolate the host any other way.
3. **Stop the traffic that hurts.** Block the abusive addresses in the cloud firewall or with fail2ban; lower the rate limits on the endpoint; switch the WAF from detection to blocking for that location; or answer the endpoint with a maintenance response from nginx. Decide with the business whether the site stays up. Do the least that stops the damage.
4. **Cut the attacker's path.** Create a new password for the application's database account, deploy it, revoke the old one. Invalidate sessions and tokens that the endpoint issued. Rotate the other secrets the application can read. If the host itself may be compromised, isolate it with the provider's security group (administration addresses only) instead of powering it off, and bring a clean replacement from the repository.
5. **Check the accounts and the keys** that could have been reached: SSH `authorized_keys`, the deploy key, the CI/CD variables, the registry credentials. Rotate what you cannot prove untouched ([secrets](08-secrets-and-configuration.md#inventory-and-rotation)).

### Investigation

- **Find the first and the last malicious request.** Search the access log for the endpoint, the unusual query strings, the sizes of requests and responses, the status codes and the addresses; line up the time of the first suspicious request with the first rise of the database error counters ([databases](09-databases-and-data-stores.md#containment-and-detection)). A `200` after a series of `4xx` and `5xx` is the interesting line. Follow the `request_id` into the application and the WAF.
- **Work out what the database account could do, then what it did.** `SHOW GRANTS` for the runtime account is the upper bound. Use the binary log (`mysqlbinlog`) for changes in the window, and look for new accounts, tables, triggers, events and stored routines that nobody created. With the grants of this set an attacker could read and change rows of one schema but could not create files, change the schema or reach other databases ([accounts](09-databases-and-data-stores.md#accounts-and-privileges)); verify that this was true on the day.
- **Look for persistence:** new SSH keys, new users, cron entries and systemd timers, containers or images that are not in the Compose file, changed files in writable volumes, and changed configuration (compare with the repository, which is the reason it is the source of truth).
- **Estimate the exposure:** which tables the account could read, the sizes of responses (`bytes_sent`) that stand out, and the outbound traffic of the host. Say what you know and what you cannot know; "no evidence of exfiltration" is different from "none".
- Keep the old backups. Do not run the retention job during the investigation ([backups](12-backups-and-recovery.md#recovery-objectives)).

### Recovery

- **Fix the cause first.** For an injection, that is parameterised queries in the application and a test that fails on the old code. Deploy through the normal pipeline. Do not re-open the endpoint with the defect in it, even behind the WAF.
- **Restore what was changed.** Restore a verified backup from before the first malicious request into a scratch server, compare it with production, and move the data back or replay the binary logs to just before the first bad statement ([restore drills](12-backups-and-recovery.md#restore-drills)). Restore on a clean network and a rebuilt host if the host was compromised; prioritise by the list of critical systems that CISA asks you to prepare.
- **Rotate everything the path could reach**, then re-open gradually with the limits and the extra alerts in place for at least two weeks.

### Notification

- Who must be told, and by when, is a legal and business question, and the deadlines can be short. Decide before an incident which laws and contracts apply to the data you hold (privacy and data-protection law, the financial regulator, payment-card rules, customer contracts), and put the owner of that decision and the contacts in the plan. CISA's guide says to make sure breach notification follows the applicable law, to consult legal counsel when needed, and, when personal data is involved, to tell affected people what was exposed, what they should do and whom to contact.
- This set does not give legal advice. It requires only that the question is answered in the plan before the first incident.

### After an incident

- **Hold a blameless review within five working days.** Produce a UTC timeline, the technical cause and the process cause, what detection missed or delayed, what worked, and a list of actions with an owner and a date. Share it with everyone who touches the system.
- Every action goes to the right place: the code fix, the alert that should have fired ([alerts](11-logging-monitoring-and-alerting.md#alerts)), the limit or rule that was missing ([abuse control](07-abuse-control-and-edge-protection.md)), the runbook, the incident plan, and, when a rule in this set was wrong or missing, the note.
- NIST's incident response publication (SP 800-61 Revision 3, April 2025) treats incident response as part of managing cybersecurity risk, not as a separate activity. Follow that: the review changes the next risk decision.

## Sources and raw notes

Pages read on 2026-11-11:

- [CISA #StopRansomware Guide](https://www.cisa.gov/stopransomware/ransomware-guide): the incident response and communications plan, the hard copy and offline version, exercising the plan, isolating systems in a coordinated manner with out-of-band communication, snapshots of cloud volumes, powering off only as a last resort, triage and restoration order, breach notification and the notice to people whose data was exposed.
- [NIST SP 800-61 Rev. 3](https://csrc.nist.gov/pubs/sp/800/61/r3/final), *Incident Response Recommendations and Considerations for Cybersecurity Risk Management: A CSF 2.0 Community Profile* (April 2025). Only the abstract page was read.
- [OWASP Logging Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Logging_Cheat_Sheet.html) (what to keep, attacks on logs) and [OWASP SQL Injection Prevention Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/SQL_Injection_Prevention_Cheat_Sheet.html) (parameterised queries, least privilege).
- The command-level steps, the roles and the time limits are this set's own and were not run in an exercise. Rehearse them on staging before you need them.
