# Informations techniques

## Architecture

### Containers

| Hostname | Role | Services (après démarrage manuel) |
|----------|------|-----------------------------------|
| `hadoop-master` (172.20.0.10) | Master | NameNode, ResourceManager, SecondaryNameNode, ZooKeeper, HBase Master, HBase Thrift, HBase REST, HistoryServer |
| `hadoop-slave1` (172.20.0.20) | Slave | DataNode, NodeManager, HBase RegionServer |
| `hadoop-slave2` (172.20.0.30) | Slave | DataNode, NodeManager, HBase RegionServer |

**Note :** Les conteneurs démarrent sans aucun service actif (SSH uniquement).
Les services se lancent manuellement via les scripts `/home/*.sh` (le `WORKDIR` est `/home`).

### Network

- Bridge Docker `hadoop-net` — subnet `172.20.0.0/16`
- IP fixes attribuées statiquement dans `docker-compose.yml`
- Résolution DNS via `/etc/hosts` écrit par `entrypoint.sh`

### Volumes

| Volume | Chemin conteneur | Utilité |
|--------|-----------------|---------|
| `hdfs-namenode` (named volume) | `/data/hdfs/namenode` | Métadonnées HDFS |
| `hdfs-datanode-1` (named volume) | `/data/hdfs/datanode` | Données slave1 |
| `hdfs-datanode-2` (named volume) | `/data/hdfs/datanode` | Données slave2 |
| `zookeeper-data` (named volume) | `/data/zookeeper` | Données ZooKeeper |
| `./src/` | `/home/src/` | Scripts TP (partagés) |


### Versions

| Composant | Version | Téléchargement |
|-----------|---------|----------------|
| Hadoop | 3.3.6 | `hadoop-3.3.6.tar.gz` |
| HBase | 2.5.15 | `hbase-2.5.15-hadoop3-bin.tar.gz` |
| ZooKeeper | 3.8.6 | `apache-zookeeper-3.8.6-bin.tar.gz` |

## Personnalisation

Les valeurs par défaut sont adaptées à un PC 4 GB RAM / 2 cœurs.
Pour une machine plus puissante (16+ GB), augmentez ces valeurs.


### docker-compose.yml

```yaml
master:
  mem_limit: 3g      # au lieu de 1.8g
  cpus: 2            # au lieu de 1.5

slave1, slave2:
  mem_limit: 1.5g    # au lieu de 0.8g
```

### scripts/entrypoint.sh

```bash
HADOOP_HEAPSIZE=512                              # au lieu de 192
HDFS_NAMENODE_OPTS="-Xms512m -Xmx512m"           # au lieu de 192m
HDFS_SECONDARYNAMENODE_OPTS="-Xms512m -Xmx512m"  # au lieu de 192m
YARN_RESOURCEMANAGER_OPTS="-Xms512m -Xmx512m"    # au lieu de 192m
YARN_HEAPSIZE=512                                # au lieu de 192
HBASE_HEAPSIZE=512                               # au lieu de 192
HBASE_MASTER_OPTS="-Xms512m -Xmx512m"            # au lieu de 192m
HBASE_REGIONSERVER_OPTS="-Xms512m -Xmx512m"      # au lieu de 192m
```

Supprimez aussi `-XX:MaxMetaspaceSize=64m -Xss512k` des lignes `HADOOP_OPTS` et `HBASE_OPTS`
si vous avez assez de RAM — ces flags limitent le surcoût JVM pour les petites machines.

### config/yarn-site.xml

```xml
<property>
    <name>yarn.nodemanager.resource.memory-mb</name>
    <value>2048</value>                    <!-- au lieu de 256 -->
</property>
<property>
    <name>yarn.scheduler.maximum-allocation-mb</name>
    <value>2048</value>                    <!-- au lieu de 256 -->
</property>
<property>
    <name>yarn.scheduler.minimum-allocation-mb</name>
    <value>512</value>                     <!-- au lieu de 128 -->
</property>
```

### config/mapred-site.xml

```xml
<property>
    <name>mapreduce.map.memory.mb</name>
    <value>512</value>                     <!-- au lieu de 128 -->
</property>
<property>
    <name>mapreduce.reduce.memory.mb</name>
    <value>512</value>                     <!-- au lieu de 128 -->
</property>
<property>
    <name>yarn.app.mapreduce.am.resource.mb</name>
    <value>512</value>                     <!-- au lieu de 128 -->
</property>
```

### config/hdfs-site.xml

```xml
<property>
    <name>dfs.replication</name>
    <value>2</value>                       <!-- au lieu de 1 (si 2+ slaves) -->
</property>
```
