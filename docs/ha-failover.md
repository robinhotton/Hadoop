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

## Full HA architecture

### Required components

| Component | HA setup | Count |
|-----------|----------|-------|
| NameNode | Active / Standby (via ZKFC) | 2 |
| JournalNode | Quorum for HDFS edits | 3 |
| DataNode | Unchanged | 2+ |
| ResourceManager | Active / Standby (via ZK) | 2 |
| NodeManager | Unchanged | 2+ |
| ZooKeeper | Ensemble (quorum) | 3 |
| HBase Master | Active / Standby (native via ZK) | 2 |
| RegionServer | Unchanged | 2+ |

### Total: 12 containers (vs 3 currently)

```
hadoop-ha/
├── zk1, zk2, zk3              # ZooKeeper ensemble
├── nn1, nn2                    # NameNode active / standby
├── jn1, jn2, jn3              # JournalNodes
├── rm1, rm2                    # ResourceManager active / standby
├── dn1, dn2                    # DataNodes (unchanged)
├── hbase-master1, hbase-master2  # HBase Masters
└── rs1, rs2                    # RegionServers (unchanged)
```

---

## HA docker-compose.yml (partial example)

```yaml
services:
  zk1: &zk
    hostname: zk1
    image: hadoop-ha:latest
    command: ["zkServer.sh", "start-foreground"]
    volumes:
      - ./volumes/zk1:/data/zookeeper
    environment:
      - ZK_MYID=1
    networks:
      ha-net:
        ipv4_address: 172.21.0.10

  zk2:
    <<: *zk
    hostname: zk2
    environment:
      - ZK_MYID=2
    networks:
      ha-net:
        ipv4_address: 172.21.0.11

  zk3:
    <<: *zk
    hostname: zk3
    environment:
      - ZK_MYID=3
    networks:
      ha-net:
        ipv4_address: 172.21.0.12

  jn1: &jn
    hostname: jn1
    image: hadoop-ha:latest
    command: ["hdfs", "journalnode"]
    networks:
      ha-net:
        ipv4_address: 172.21.0.20

  jn2:
    <<: *jn
    hostname: jn2
    networks:
      ha-net:
        ipv4_address: 172.21.0.21

  jn3:
    <<: *jn
    hostname: jn3
    networks:
      ha-net:
        ipv4_address: 172.21.0.22

  nn1:
    hostname: nn1
    image: hadoop-ha:latest
    command: ["hdfs", "namenode"]
    environment:
      - HA_ACTIVE=true
    depends_on: [zk1, zk2, zk3, jn1, jn2, jn3]
    networks:
      ha-net:
        ipv4_address: 172.21.0.30

  nn2:
    hostname: nn2
    image: hadoop-ha:latest
    command: ["hdfs", "namenode"]
    environment:
      - HA_ACTIVE=false
    depends_on: [zk1, zk2, zk3, jn1, jn2, jn3]
    networks:
      ha-net:
        ipv4_address: 172.21.0.31

  rm1:
    hostname: rm1
    image: hadoop-ha:latest
    command: ["yarn", "resourcemanager"]
    depends_on: [zk1, zk2, zk3]
    networks:
      ha-net:
        ipv4_address: 172.21.0.40

  rm2:
    hostname: rm2
    image: hadoop-ha:latest
    command: ["yarn", "resourcemanager"]
    depends_on: [zk1, zk2, zk3]
    networks:
      ha-net:
        ipv4_address: 172.21.0.41

  dn1: &dn
    hostname: dn1
    image: hadoop-ha:latest
    command: ["hdfs", "datanode"]
    depends_on: [nn1, nn2]
    networks:
      ha-net:
        ipv4_address: 172.21.0.50

  dn2:
    <<: *dn
    hostname: dn2
    networks:
      ha-net:
        ipv4_address: 172.21.0.51
```

---

## Configuration changes for HA

### core-site.xml

```xml
<property>
    <name>fs.defaultFS</name>
    <value>hdfs://hadoop-ha</value>
</property>
<property>
    <name>ha.zookeeper.quorum</name>
    <value>zk1:2181,zk2:2181,zk3:2181</value>
</property>
```

### hdfs-site.xml

```xml
<property>
    <name>dfs.nameservices</name>
    <value>hadoop-ha</value>
</property>
<property>
    <name>dfs.ha.namenodes.hadoop-ha</name>
    <value>nn1,nn2</value>
</property>
<property>
    <name>dfs.namenode.rpc-address.hadoop-ha.nn1</name>
    <value>nn1:9000</value>
</property>
<property>
    <name>dfs.namenode.rpc-address.hadoop-ha.nn2</name>
    <value>nn2:9000</value>
</property>
<property>
    <name>dfs.namenode.http-address.hadoop-ha.nn1</name>
    <value>nn1:9870</value>
</property>
<property>
    <name>dfs.namenode.http-address.hadoop-ha.nn2</name>
    <value>nn2:9870</value>
</property>
<property>
    <name>dfs.namenode.shared.edits.dir</name>
    <value>qjournal://jn1:8485;jn2:8485;jn3:8485/hadoop-ha</value>
</property>
<property>
    <name>dfs.client.failover.proxy.provider.hadoop-ha</name>
    <value>org.apache.hadoop.hdfs.server.namenode.ha.ConfiguredFailoverProxyProvider</value>
</property>
<property>
    <name>dfs.ha.fencing.methods</name>
    <value>sshfence</value>
</property>
<property>
    <name>dfs.ha.fencing.ssh.private-key-files</name>
    <value>/root/.ssh/id_rsa</value>
</property>
<property>
    <name>dfs.ha.automatic-failover.enabled</name>
    <value>true</value>
</property>
```

### yarn-site.xml

```xml
<property>
    <name>yarn.resourcemanager.ha.enabled</name>
    <value>true</value>
</property>
<property>
    <name>yarn.resourcemanager.cluster-id</name>
    <value>yarn-ha</value>
</property>
<property>
    <name>yarn.resourcemanager.ha.rm-ids</name>
    <value>rm1,rm2</value>
</property>
<property>
    <name>yarn.resourcemanager.hostname.rm1</name>
    <value>rm1</value>
</property>
<property>
    <name>yarn.resourcemanager.hostname.rm2</name>
    <value>rm2</value>
</property>
<property>
    <name>yarn.resourcemanager.webapp.address.rm1</name>
    <value>rm1:8088</value>
</property>
<property>
    <name>yarn.resourcemanager.webapp.address.rm2</name>
    <value>rm2:8088</value>
</property>
<property>
    <name>yarn.resourcemanager.zk-address</name>
    <value>zk1:2181,zk2:2181,zk3:2181</value>
</property>
```

---

## What changes from the current stack

| Aspect | Current stack | HA stack |
|--------|---------------|----------|
| Containers | 3 | 12 |
| RAM required | ~6 GB | ~20 GB |
| Complexity | Low | High |
| SPOF | Yes | No |
| Maintenance | Full restart | Rolling upgrade |
| Updates | Downtime | Zero-downtime |
| Use case | Learning | Production |

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

### Trade-offs

| Aspect | Root | Non-root (hadoop user) |
|--------|------|----------------------|
| Setup complexity | Low | Medium |
| Security | Low | High |
| Student commands | `docker exec -it hadoop-master bash` | Same |
| Volume permissions | Auto (root) | Must chown on first start |

For a learning environment, root is perfectly acceptable. The non-root migration
is recommended only if deploying to a shared or production-like infrastructure.

## Summary

HA is **essential in production** but **unnecessary for learning**:
- Complexity hides core concepts
- Resource consumption is 3-4x higher
- Setup time is multiplied

The current stack (master + 2 slaves) is enough to understand all
Hadoop/HBase concepts without the HA overhead.