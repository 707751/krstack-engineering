# Postfix and container considerations

## Moving from a server to a container

A traditional Postfix setup can depend on operating-system defaults, local interfaces, installed map libraries, and local logging behaviour. Those assumptions need review when the same workload moves into a container.

## Interface assumptions

Settings that expect a particular server interface or hostname can behave differently inside a container. Start with the required relay behaviour and use Kubernetes networking as the outer boundary.

## LMDB support

Some Postfix configurations use LMDB lookup maps. Confirm that the container environment provides the required support before relying on the configuration.

~~~bash
postconf -m | grep lmdb
~~~

## Foreground process behaviour

A container should keep its main service in the foreground. That lets Kubernetes observe the process and apply its normal lifecycle handling.

## Logging

syslog-ng and persistent storage can keep operational mail logs available when a Pod is recreated. This supports investigation without treating a container filesystem as long-term log storage.

## Relay protection

SMTP relay protection should remain enabled. Only approved sources should be allowed to use the relay. Public examples should never include source ranges, credentials, access-map contents, or network rules.

## Queue inspection

Queue inspection helps show whether mail has been accepted but is waiting for another stage of delivery.

~~~bash
postqueue -p
postconf -n
~~~
