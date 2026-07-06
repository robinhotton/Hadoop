# Implementation details

## Architecture

### Containers

| Hostname | Role | Services (après démarrage manuel) |
|----------|------|-----------------------------------|
| `hadoop-master` (172.20.0.10) | Master | NameNode, ResourceManager, SecondaryNameNode, ZooKeeper, HBase Master, HBase Thrift, HBase REST, HistoryServer, Spark |
| `hadoop-slave1` (172.20.0.20) | Slave | DataNode, NodeManager, HBase RegionServer |
| `hadoop-slave2` (172.20.0.30) | Slave | DataNode, NodeManager, HBase RegionServer |

**Note :** Les conteneurs démarrent sans aucun service actif (SSH uniquement).
Les services se lancent manuellement via les scripts `/home/*.sh` (le `WORKDIR` est `/home`).

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
| `./src/` | `/home/src/` | Scripts TP (partagés) |

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
- Copie l'entrypoint, les scripts master et regionservers
- Toute la configuration (XML, heaps JVM) est générée à chaud par `entrypoint.sh`

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

### entrypoint.sh — logique détaillée

L'`entrypoint.sh` centralise toute l'initialisation ET la génération des fichiers
de configuration (plus besoin de fichiers statiques dans `config/`).
Aucun service Hadoop/HBase n'est démarré automatiquement.

```
Master:
  1. Écrit /etc/hosts (3 entrées IP ↔ hostname)
  2. Démarre SSH (daemon)
  3. Configure SSH (PermitRootLogin, StrictHostKeyChecking)
  4. Charge les variables d'environnement (/etc/profile.d/hadoop.sh)
  5. Configure les heaps JVM (hadoop-env.sh, yarn-env.sh, hbase-env.sh)
  6. Génère tous les fichiers de configuration (XML, zoo.cfg, spark-defaults, workers)
  7. Écrit /data/zookeeper/myid = 1
  8. Formate NameNode si première exécution (fichier sentinel VERSION)
  9. Boucle infinie (sleep 30) pour maintenir le conteneur en vie

Slave:
  1. Écrit /etc/hosts
  2. Démarre SSH (daemon)
  3. Configure SSH (PermitRootLogin, StrictHostKeyChecking)
  4. Charge les variables d'environnement
  5. Configure les heaps JVM
  6. Génère tous les fichiers de configuration (identiques au master)
  7. Boucle infinie (sleep 30) pour maintenir le conteneur en vie
```

Après le démarrage des conteneurs, l'utilisateur lance les services manuellement
depuis le master via les scripts dans `/home/` :

```bash
./start_hadoop.sh   # HDFS (start-dfs.sh) + YARN (start-yarn.sh)
./start_hbase.sh    # ZooKeeper + HBase + Thrift
./start_rest.sh     # HBase REST (optionnel)
```

### Scripts de démarrage

**start_hadoop.sh :**
```
1. start-dfs.sh       → NameNode (master) + DataNodes (slaves) via SSH
2. start-yarn.sh      → ResourceManager (master) + NodeManagers (slaves) via SSH
3. mapred --daemon start historyserver
4. hdfs dfs -mkdir -p /spark-logs
```

**start_hbase.sh :**
```
1. zkServer.sh start
2. start-hbase.sh     → HBase Master (master) + RegionServers (slaves) via SSH
3. hbase-daemon.sh start thrift
```

**start_rest.sh / stop_rest.sh :**
```
hbase-daemon.sh start rest
hbase-daemon.sh stop rest
```

### Ordre de démarrage recommandé

1. Démarrer les conteneurs : `./container_start.sh`
2. Attendre ~10s que SSH soit prêt
3. Se connecter au master : `./bash_hadoop_master.sh`
4. `./start_hadoop.sh` — HDFS + YARN (peut prendre 30-60s)
5. `./start_hbase.sh` — HBase + Thrift
6. `./start_rest.sh` — REST (si nécessaire)

### Gestion des signaux

```bash
trap cleanup SIGTERM SIGINT
```

`cleanup()` dans `entrypoint.sh` fait un `exit 0` — les services doivent être
arrêtés manuellement avant l'arrêt du conteneur via `./stop_hadoop.sh` et
`./stop_hbase.sh`.

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
master (démarrage simple)
  ├── slave1 (depends_on: master)
  └── slave2 (depends_on: master)
```

Les slaves attendent juste que le master ait démarré (pas de healthcheck).
Les dépendances réelles (HDFS, YARN, HBase) sont gérées par les scripts
`start-dfs.sh`, `start-yarn.sh` et `start-hbase.sh` qui utilisent SSH
pour orchestrer le démarrage à distance sur les slaves.

---

## Résolution de problèmes

### Symptôme : les conteneurs sont "cold" (aucun service)

C'est normal. Les services se lancent manuellement :
```bash
docker exec -it hadoop-master bash
./start_hadoop.sh
./start_hbase.sh
```

### Symptôme : HBase ne démarre pas

Vérifier que les DataNodes sont connectés :
```bash
docker exec hadoop-master hdfs dfsadmin -report | grep "Live datanodes"
```

### Symptôme : "No datanode" dans HBase

Vérifier que `start_hadoop.sh` a eu le temps de finir (30-60s) avant de
lancer `start_hbase.sh`. Les DataNodes doivent être actifs pour qu'HBase
puisse écrire dans HDFS.

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

Dans `scripts/entrypoint.sh`, fonction `setup_hadoop_heaps()` :
```bash
export HDFS_NAMENODE_OPTS="-Xms1g -Xmx1g"
```

### Ajouter un service

Exemple : ajouter un datawarehouse ou un outil de monitoring.
1. Ajouter le service dans `docker-compose.yml`
2. Ajouter l'installation dans `Dockerfile.rocky` (stage 2)
3. Ajouter sa configuration dans `scripts/entrypoint.sh`
4. Créer un script de démarrage dans `scripts/master/`

### Changer les versions

Modifier les `ARG HADOOP_VERSION=...` en haut du Dockerfile. Vérifier la
compatibilité des versions (HBase doit être compilé pour la version Hadoop utilisée).
