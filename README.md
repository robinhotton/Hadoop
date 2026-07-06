# Hadoop Learning Cluster

Stack Hadoop complète pour l'apprentissage, déployable en local ou sur Proxmox.

## Versions

| Composant | Version | URL de téléchargement |
|-----------|---------|----------------------|
| OS | Rocky Linux 9 | `rockylinux:9` (Docker Hub) |
| Java | OpenJDK 11.0.25 | `java-11-openjdk-headless` |
| Hadoop | 3.3.6 | [dlcdn.apache.org](https://dlcdn.apache.org/hadoop/common/hadoop-3.3.6/hadoop-3.3.6.tar.gz) |
| HBase | 2.5.15 | [dlcdn.apache.org](https://dlcdn.apache.org/hbase/2.5.15/hbase-2.5.15-hadoop3-bin.tar.gz) |
| ZooKeeper | 3.8.6 | [dlcdn.apache.org](https://dlcdn.apache.org/zookeeper/zookeeper-3.8.6/apache-zookeeper-3.8.6-bin.tar.gz) |
| Spark | 3.5.8 | [dlcdn.apache.org](https://dlcdn.apache.org/spark/spark-3.5.8/spark-3.5.8-bin-hadoop3-scala2.13.tgz) |
| Python | 3.11 | pip : pandas, matplotlib, happybase, thriftpy2 |

## Prérequis

- Docker Engine 24+ et Docker Compose v2+
- 6-8 GB RAM recommandés

## Quick start

```bash
# Build de l'image (~5-10 min selon la connexion)
docker compose build

# Lancement des 3 conteneurs
docker compose up -d

# Vérification
docker compose ps

# Logs en direct
docker compose logs -f
```

### Premiers pas dans le cluster

```bash
# 1. Accéder au master
docker exec -it hadoop-master bash

# 2. Vérifier que tous les services tournent
jps

# 3. Vérifier les scripts de TP (montés via le volume ./src:/home/src)
ls -la /home/src/ /home/src/wordcount/

# 4. Lancer un MapReduce wordcount via le script générique
cd /home/src/wordcount
echo "hello world hello hadoop hello yarn hello hbase" > data.txt
./run_mr.sh data.txt wordcount_mapper.py wordcount_reducer.py wordcount
```

## Services

### Master (`hadoop-master`)

| Processus | Rôle | Port |
|-----------|------|------|
| `NameNode` | Gestionnaire HDFS (métadonnées) | 9870 (UI), 9000 (RPC) |
| `SecondaryNameNode` | Checkpoint du NameNode | 9868 (UI) |
| `DataNode` | Stockage HDFS local | — |
| `ResourceManager` | Ordonnanceur YARN | 8088 (UI) |
| `NodeManager` | Exécuteur YARN local | 8042 (UI) |
| `HMaster` | Gestionnaire HBase | 16010 (UI) |
| `HRegionServer` | Stockage HBase local | — |
| `HQuorumPeer` | Serveur ZooKeeper | 2181 |
| `ThriftServer` | API Thrift (happybase) | 9090 |
| `RESTServer` | API REST (Power BI) | 9091 |

### Slaves (`hadoop-slave1`, `hadoop-slave2`)

| Processus | Rôle | Port |
|-----------|------|------|
| `DataNode` | Stockage HDFS | — |
| `NodeManager` | Exécuteur YARN | 8041 / 8042 (UI) |
| `HRegionServer` | Stockage HBase | — |

### URLs utiles

| URL | Description |
|-----|-------------|
| `http://<IP>:9870` | NameNode UI |
| `http://<IP>:8088` | YARN ResourceManager UI |
| `http://<IP>:8040` | NodeManager UI (master) |
| `http://<IP>:8041` | NodeManager UI (slave1) |
| `http://<IP>:8042` | NodeManager UI (slave2) |
| `http://<IP>:16010` | HBase Master UI |
| `http://<IP>:9091` | HBase REST API |

## Utilisation

### HBase avec happybase

```bash
python3 /home/src/hbase.py
```

### Power BI

1. Power BI Desktop → **Obtenir des données** → **Web**
2. URL : `http://<IP_PROXMOX>:9091/`
3. Utiliser l'éditeur Power Query pour parser le JSON

### Spark (mode YARN)

```bash
spark-submit --master yarn --deploy-mode cluster /path/to/script.py
```

## Arrêt et nettoyage

```bash
# Arrêter les conteneurs
docker compose down

# Rebuild complet
docker compose build --no-cache
```

## Déploiement sur Proxmox

1. Installer Docker sur la VM Proxmox
2. Copier le dossier `hadoop-cluster/` sur la VM
3. Lancer `docker compose up -d`
4. Ouvrir les ports dans le firewall Proxmox (9870, 8088, 9090, 9091, ...)
5. Distribuer l'URL `http://<IP_VM>:9870` aux apprenants

## Arborescence

```
hadoop-cluster/
├── Dockerfile.rocky        # Image multistage
├── docker-compose.yml      # Orchestration
├── config/                 # Fichiers de configuration
│   ├── core-site.xml
│   ├── hdfs-site.xml
│   ├── mapred-site.xml
│   ├── yarn-site.xml
│   ├── hbase-site.xml
│   ├── zoo.cfg
│   └── spark-defaults.conf
├── scripts/                # Scripts de démarrage
│   ├── bootstrap.sh
│   └── regionservers
├── src/                     # Scripts des TP
│   ├── hbase.py              # Exemple HBase (étudiants)
│   ├── wordcount/
│   │   ├── wordcount_mapper.py
│   │   ├── wordcount_reducer.py
│   │   ├── store_in_hbase.py  # Stocke le résultat MR dans HBase
│   │   └── run_mr.sh         # Script générique de lancement MR
│   └── tp_hbase.py
├── docs/                   # Documentation
│   ├── ha-failover.md
│   └── technical-implementation.md
```
