# Implementation details

## Architecture

### Containers

| Hostname | Role | Services |
|----------|------|----------|
| `hadoop-master` (172.20.0.10) | Master | NameNode, ResourceManager, SecondaryNameNode, ZooKeeper, HBase Master, HBase Thrift, HBase REST, HistoryServer, Spark |
| `hadoop-slave1` (172.20.0.20) | Slave | DataNode, NodeManager, HBase RegionServer |
| `hadoop-slave2` (172.20.0.30) | Slave | DataNode, NodeManager, HBase RegionServer |

### Network

- Bridge Docker `hadoop-net` — subnet `172.20.0.0/16`
- IP fixes attribuées statiquement dans `docker-compose.yml`
- Résolution DNS via `/etc/hosts` écrit par `bootstrap.sh`

### Volumes

| Volume | Chemin conteneur | Utilité |
|--------|-----------------|---------|
| `./volumes/namenode/` | `/data/hdfs/namenode` | Métadonnées HDFS |
| `./volumes/datanode1/` | `/data/hdfs/datanode` | Données slave1 |
| `./volumes/datanode2/` | `/data/hdfs/datanode` | Données slave2 |
| `./volumes/zookeeper/` | `/data/zookeeper` | Données ZooKeeper |
| `./src/` | `/home/tp/` | Scripts TP (partagés) |

---

## Dockerfile multistage

### Stage 1 — builder

- Base `rockylinux:9`
- Installe `curl` uniquement
- Télécharge et extrait Hadoop 3.3.6, HBase 2.5.15, ZooKeeper 3.8.6, Spark 3.5.8
- Supprime : `share/doc/`, `docs/`, `examples/`, `data/`, fichiers `.bat`, `.cmd`, `.ps1`, `.a`
- Cette image est jetée après le build

### Stage 2 — runtime

- Base `rockylinux:9`
- Installe OpenJDK 11 headless, OpenSSH, Python 3, pip
- Copie les binaires depuis le builder
- Installe les packages Python (pandas, matplotlib, happybase, thriftpy2)
- Configure SSH (clés hôte + utilisateur, authorized_keys)
- Copie les fichiers de configuration et scripts
- Configure les heaps JVM

### Versions

| Composant | Version | Téléchargement |
|-----------|---------|----------------|
| Hadoop | 3.3.6 | `hadoop-3.3.6.tar.gz` |
| HBase | 2.5.15 | `hbase-2.5.15-hadoop3-bin.tar.gz` |
| ZooKeeper | 3.8.6 | `apache-zookeeper-3.8.6-bin.tar.gz` |
| Spark | 3.5.8 | `spark-3.5.8-bin-hadoop3-scala2.13.tgz` |

---

## Configuration des services

### HDFS (`hdfs-site.xml`)

- Réplication : 2 (correspond aux 2 slaves)
- NameNode data dir : `/data/hdfs/namenode`
- DataNode data dir : `/data/hdfs/datanode`
- Permissions désactivées (environnement d'apprentissage)
- Block size : 128 MB

### YARN (`yarn-site.xml`)

- ResourceManager : `hadoop-master` (ports 8030-8033)
- NodeManager memory : 1024 MB
- Allocation conteneurs : 256-1024 MB
- Vérifications mémoire désactivées (pour les petits jobs)
- CPU vcores : 1 par NodeManager

### MapReduce (`mapred-site.xml`)

- Framework : YARN
- HistoryServer : `hadoop-master:10020`
- Map memory : 256 MB
- Reduce memory : 256 MB

### HBase (`hbase-site.xml`)

- Rootdir : `hdfs://hadoop-master:9000/hbase`
- Mode distribué
- ZooKeeper : `hadoop-master:2181`
- Memstore : 30% de la heap RegionServer
- Block cache : 30%
- Handler count : 3 (minimal pour l'apprentissage)
- Max file size : 1 GB (évite les splits prématurés)
- Flush size : 128 MB

### ZooKeeper (`zoo.cfg`)

- Mode standalone (1 nœud)
- tickTime : 2000 ms
- dataDir : `/data/zookeeper`
- Client port : 2181
- Purge automatique : 3 snapshots conservés, purge toutes les 1 heure

### Spark (`spark-defaults.conf`)

- Mode : YARN
- AM memory : 512 MB
- Executor memory : 512 MB
- Executor cores : 1
- Kryo serializer (meilleures performances)
- Event log activé

---

## Optimisations mémoire

### Heaps JVM

Variables définies dans `hadoop-env.sh`, `yarn-env.sh`, `hbase-env.sh` du Dockerfile.

| Service | Heap | Variable d'env |
|---------|------|----------------|
| NameNode | 512 MB | `HDFS_NAMENODE_OPTS` |
| DataNode | 256 MB | `HDFS_DATANODE_OPTS` |
| ResourceManager | 512 MB | `YARN_RESOURCEMANAGER_OPTS` |
| NodeManager | 256 MB | `YARN_NODEMANAGER_OPTS` |
| HBase Master | 512 MB | `HBASE_MASTER_OPTS` |
| HBase RegionServer | 512 MB | `HBASE_REGIONSERVER_OPTS` |
| HBase Thrift | 256 MB | `HBASE_THRIFT_OPTS` |
| ZooKeeper | 128 MB | Valeur par défaut ZK |
| Spark executor | 512 MB | `spark.executor.memory` dans spark-defaults.conf |

**Note :** Hadoop 3.3.x utilise `HDFS_NAMENODE_OPTS` / `HDFS_DATANODE_OPTS`
(les anciens noms `HADOOP_NAMENODE_OPTS` / `HADOOP_DATANODE_OPTS` sont dépréciés
mais fonctionnent encore avec un warning).

### YARN

```xml
yarn.nodemanager.resource.memory-mb = 1024
yarn.scheduler.minimum-allocation-mb = 256
yarn.scheduler.maximum-allocation-mb = 1024
yarn.nodemanager.pmem-check-enabled = false
yarn.nodemanager.vmem-check-enabled = false
```

### Docker Compose limits

| Service | Memory | CPU |
|---------|--------|-----|
| master | 3 GB | 2 cœurs |
| slave1 | 1.5 GB | 1 cœur |
| slave2 | 1.5 GB | 1 cœur |

---

## Startup sequence

### bootstrap.sh — logique détaillée

```
Master:
  1. Écrit /etc/hosts (3 entrées IP ↔ hostname)
  2. Démarre SSH
  3. Charge les variables d'environnement
  4. Écrit /data/zookeeper/myid = 1
  5. Démarre ZooKeeper
  6. Formate NameNode si première exécution (fichier sentinel VERSION)
  7. Démarre NameNode (port 9000)
  8. Démarre ResourceManager (port 8088)
  9. Démarre HistoryServer (port 19888)
  10. Lance en BACKGROUND la boucle d'attente DataNode → HBase
  11. Le healthcheck teste le port 9000 → passe

Slave:
  1. Écrit /etc/hosts
  2. Démarre SSH
  3. Lance la boucle d'attente du port 9000 master (60 tentatives × 2s)
  4. Démarre DataNode
  5. Démarre NodeManager
  6. Démarre HBase RegionServer

Background (master):
  a. Boucle : `hdfs dfsadmin -report` → grep "Live datanodes" > 0
  b. Dès qu'au moins 1 DataNode est détecté → démarre HBase Master, Thrift, REST
  c. Crée le dossier Spark event log dans HDFS
```

### Healthcheck

```yaml
test: ["CMD", "bash", "-c", "echo > /dev/tcp/hadoop-master/9000"]
start_period: 120s   # Patiente 120s avant le premier test
interval: 30s        # Test toutes les 30s
retries: 3           # 3 échecs consécutifs = unhealthy
```

Le healthcheck teste la connectivité TCP au port RPC du NameNode (9000).
Tant que le NameNode n'est pas prêt, le conteneur est "starting".
Les slaves ont `depends_on: master: condition: service_healthy` et ne démarrent
que lorsque le master est sain.

### Gestion des signaux

```bash
trap cleanup SIGTERM SIGINT
```

`cleanup()` arrête proprement tous les services dans l'ordre inverse du démarrage
quand Docker envoie SIGTERM (docker compose down, docker stop).

---

## Détails techniques divers

### SSH

- Clés hôte générées dans le Dockerfile (RSA + ECDSA)
- Clé utilisateur root générée sans passphrase
- `authorized_keys` configuré pour le passwordless SSH
- `StrictHostKeyChecking no` et `UserKnownHostsFile /dev/null` pour éviter les prompts

### HDFS format unique

Le formatage du NameNode n'a lieu qu'une fois :
```bash
if [ ! -f /data/hdfs/namenode/current/VERSION ]; then
    hdfs namenode -format -force -nonInteractive
fi
```
Le volume `namenode/` est persistant. Tant qu'il contient les fichiers de métadonnées,
le format est ignoré.

### Dépendances inter-conteneurs

```
master (healthy: port 9000 open)
  ├── slave1 (depends_on: service_healthy)
  └── slave2 (depends_on: service_healthy)
```

Les slaves attendent le master. HBase sur le master attend les slaves
(boucle en background). Pas de deadlock possible.

---

## Résolution de problèmes

### Symptôme : master reste "unhealthy"

Vérifier que le port 9000 est accessible :
```bash
docker exec hadoop-cluster-master-1 sh -c 'echo > /dev/tcp/hadoop-master/9000 && echo OK'
```

### Symptôme : HBase ne démarre pas

Vérifier que les DataNodes sont connectés :
```bash
docker exec hadoop-cluster-master-1 hdfs dfsadmin -report | grep "Live datanodes"
```

### Symptôme : "No datanode" dans HBase

HBase attend les DataNodes en background (jusqu'à 5 minutes max). Vérifier les logs :
```bash
docker compose logs master | grep -A2 "Waiting for"
```

### Rebuild complet

```bash
docker compose down -v
docker compose build --no-cache
docker compose up -d
```

### Ports non accessibles depuis l'extérieur

Vérifier le firewall Proxmox et le pare-feu Windows. Ports à ouvrir :
`9870, 8088, 8040-8042, 16010, 9000, 9090, 9091, 2181`

---

## Personnalisation

### Modifier les heaps

Dans `Dockerfile.rocky`, ligne RUN avec les opts :
```dockerfile
RUN echo "export HADOOP_NAMENODE_OPTS=\"-Xms1g -Xmx1g\"" >> ...
```

### Ajouter un service

Exemple : ajouter un datawarehouse ou un outil de monitoring.
1. Ajouter le service dans `docker-compose.yml`
2. Ajouter l'installation dans `Dockerfile.rocky` (stage 2)
3. Ajouter le démarrage dans `bootstrap.sh`

### Changer les versions

Modifier les `ARG HADOOP_VERSION=...` en haut du Dockerfile. Vérifier la
compatibilité des versions (HBase doit être compilé pour la version Hadoop utilisée).
