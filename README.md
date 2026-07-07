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

# Lancement des 3 conteneurs (froids : SSH uniquement)
docker compose up -d

# Vérification
docker compose ps
```

### Premiers pas dans le cluster

Les conteneurs démarrent sans aucun service Hadoop/HBase actif.
Vous devez lancer les services manuellement depuis le master.

```bash
# 1. Accéder au master
./bash_hadoop_master.sh
# ou : docker exec -it hadoop-master bash

# 2. Lancer HDFS et YARN
./start_hadoop.sh

# 3. Lancer HBase et Thrift
./start_hbase.sh

# 4. (optionnel) Lancer l'API REST HBase
./start_rest.sh

# 5. Vérifier les processus
jps

# 6. Lancer un MapReduce wordcount
cd /home/src/wordcount
echo "hello world hello hadoop hello yarn hello hbase" > data.txt
./run_mr.sh data.txt wordcount_mapper.py wordcount_reducer.py wordcount
```

Pour arrêter les services :

```bash
./stop_rest.sh
./stop_hbase.sh
./stop_hadoop.sh
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

| URL | Port | Service | Description |
|-----|------|---------|-------------|
| `http://<IP>:9870` | `9870` | NameNode | Interface web HDFS (métadonnées, blocs, datanodes) |
| `http://<IP>:9868` | `9868` | SecondaryNameNode | Statut du checkpointing |
| `http://<IP>:8088` | `8088` | ResourceManager | Interface web YARN (jobs, scheduler, nodes) |
| `http://<IP>:8041` | `8041` | NodeManager slave1 | Logs et statut du nœud d'exécution YARN slave1 |
| `http://<IP>:8042` | `8042` | NodeManager slave2 | Logs et statut du nœud d'exécution YARN slave2 |
| `http://<IP>:16010` | `16010` | HMaster | Interface web HBase (tables, regions, masters) |
| `http://<IP>:9091` | `9091` | HBase REST | API REST HBase (requêtes HTTP JSON/XML) |

> Le master n'a pas de NodeManager (il ne figure pas dans `workers`).
> Les ports 2181 (ZooKeeper), 9000 (NameNode RPC) et 9090 (Thrift) sont des protocoles binaires, pas des interfaces web.

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
./container_stop.sh
# ou : docker compose down

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
├── Dockerfile.rocky          # Image multistage
├── docker-compose.yml        # Orchestration
├── container_start.sh        # Démarre les conteneurs
├── container_stop.sh         # Arrête les conteneurs
├── bash_hadoop_master.sh     # Console dans le master
├── config/                   # Fichiers de configuration
│   ├── core-site.xml
│   ├── hdfs-site.xml
│   ├── mapred-site.xml
│   ├── yarn-site.xml
│   ├── hbase-site.xml
│   ├── zoo.cfg
│   ├── spark-defaults.conf
│   └── workers
├── scripts/                  # Scripts copiés dans le conteneur
│   ├── entrypoint.sh          # Entrypoint (init + heaps JVM)
│   ├── regionservers          # Liste des RegionServers HBase
│   └── master/                # Scripts de gestion des services (dans /home/)
│       ├── start_hadoop.sh
│       ├── stop_hadoop.sh
│       ├── start_hbase.sh
│       ├── stop_hbase.sh
│       ├── start_rest.sh
│       └── stop_rest.sh
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
