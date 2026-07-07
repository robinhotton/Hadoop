# High Availability (HA) for Hadoop in production

## Why HA in production?

The current stack (1 master, 2 slaves) has **Single Points of Failure** (SPOF):

| Component | Risk if down |
|-----------|-------------|
| NameNode | HDFS unavailable -- no distributed storage |
| ResourceManager | No YARN jobs possible |
| HBase Master | HBase admin operations blocked |
| ZooKeeper | Full stack loses coordination |

In production, downtime = financial loss. HA removes these SPOFs.

## Security hardening: non-root user

In production, running as **root** is a security risk. The current stack runs as root
for simplicity (the containers are disposable learning environments).

### Why non-root in production?

| Risk | Impact |
|------|--------|
| Container escape | Root in container = root on host in some configurations |
| Vulnerability exploit | Full system access if Hadoop/HBase is compromised |
| Compliance | Many security standards require non-root |