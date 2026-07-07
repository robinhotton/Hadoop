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

---

## Security hardening: non-root user

In production, running as **root** is a security risk. The current stack runs as root
for simplicity (the containers are disposable learning environments).

### Why non-root in production?

| Risk | Impact |
|------|--------|
| Container escape | Root in container = root on host in some configurations |
| Vulnerability exploit | Full system access if Hadoop/HBase is compromised |
| Compliance | Many security standards require non-root |

### How to migrate to non-root

1. Create a user (e.g. `hadoop`) in the Dockerfile:

```dockerfile
RUN useradd -m -d /home/hadoop -s /bin/bash hadoop && \
    echo "hadoop ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
```

2. Copy the SSH key and authorized_keys to `/home/hadoop/.ssh/`

3. Change ownership of all data and application directories:

```dockerfile
RUN chown -R hadoop:hadoop /opt/hadoop /opt/hbase /opt/zookeeper /opt/spark \
    /data/hdfs /data/zookeeper /opt/scripts /tmp/hadoop
```

4. Update SSH config to allow the user:

```dockerfile
RUN sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
```

5. Switch user in the entrypoint or Dockerfile:

```dockerfile
USER hadoop
ENTRYPOINT ["/opt/scripts/bootstrap.sh"]
```

6. Ensure all directories mounted as volumes (`/data/hdfs/namenode`, etc.)
   are owned by the `hadoop` user (the host creates them as root by default).
