# Validation and Troubleshooting

## Check Kubernetes workload

Use generic commands to confirm the workload, Service, and persistent storage are present:

~~~bash
kubectl get pods -n <namespace>
kubectl get svc -n <namespace>
kubectl get pvc -n <namespace>
~~~

## Check Postfix

Confirm the required map support and inspect the active configuration without publishing environment-specific values:

~~~bash
postconf -m | grep lmdb
postqueue -p
postconf inet_interfaces
~~~

## Validate logging

Confirm that mail-related operational logs are written where the logging pattern expects them. Check that the logs remain available after a controlled Pod recreation. Do not use production log lines in public documentation.

## Check SMTP path

Treat the path as two separate network legs:

~~~text
Client → Kubernetes Relay
Kubernetes Relay → Upstream SMTP Service
~~~

A generic connectivity check can use placeholders only:

~~~bash
nc -vz <UPSTREAM_SMTP_HOST> <SMTP_PORT>
~~~

Checking the legs separately helps isolate whether an issue belongs to Kubernetes, Postfix, or network connectivity.

## Common problems worked through

### Server-specific interface assumptions

**Symptom:** Postfix starts with unexpected interface behaviour in a container.

**Cause:** The configuration assumes a traditional server network layout.

**What to check:** Review the active interface-related configuration and Kubernetes networking path.

**General fix approach:** Adjust the configuration for the container environment while preserving the intended relay behaviour.

### Missing LMDB support

**Symptom:** Postfix cannot use the expected lookup-map type.

**Cause:** The first container environment does not include the required LMDB support.

**What to check:** Run postconf -m | grep lmdb.

**General fix approach:** Provide and validate the required map support before using the configuration.

### Missing persistent logs

**Symptom:** Useful relay logs disappear after a Pod is recreated.

**Cause:** Container-local files are not durable operational storage.

**What to check:** Confirm the log path, syslog-ng behaviour, and persistent storage mount.

**General fix approach:** Send operational logs through syslog-ng and keep the required log location on persistent storage.

### Relay access denied

**Symptom:** A client cannot use the relay.

**Cause:** Relay protection correctly rejects an unapproved source, or the access policy is incomplete.

**What to check:** Review the sanitized policy design and confirm the client path reaches the Kubernetes Service.

**General fix approach:** Keep normal relay protection enabled and correct the approved-source policy without publishing network ranges.

### Mail accepted but still queued

**Symptom:** Postfix accepts a message but it remains in the queue.

**Cause:** A later delivery stage is unavailable or rejects the attempt.

**What to check:** Inspect queue state and separate the client-to-relay path from the relay-to-upstream path.

**General fix approach:** Identify the failing leg before changing Postfix or Kubernetes settings.

### Upstream connectivity issue

**Symptom:** The relay cannot complete the connection to the upstream SMTP service.

**Cause:** The issue may be DNS, network policy, routing, or upstream service availability.

**What to check:** Use a placeholder-based connectivity test from the relay context and compare the result with Kubernetes and Postfix state.

**General fix approach:** Correct the identified network or upstream dependency without exposing production addresses or rules.
