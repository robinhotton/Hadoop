# Scripts de démarrage - ordre d'exécution

Chaque script démarre un service indépendant. L'ordre ci-dessous respecte les dépendances entre services.

| Étape | Script | Service activé | Dépendances |
|-------|--------|----------------|-------------|
| 1 | `start-zookeeper.sh` | **ZooKeeper** — coordination distribuée | Aucune |
| 2 | `start-dfs.sh` | **HDFS** — stockage distribué (NameNode + Datanodes) | Aucune |
| 3 | `start-yarn.sh` | **YARN** — ordonnanceur de ressources (ResourceManager + NodeManagers) | HDFS |
| 4 | `start-hbase.sh` | **HBase** — base NoSQL (Master + RegionServers) | HDFS + ZooKeeper |
| 5 | `start-thrift.sh` | **HBase Thrift** — passerelle Thrift pour HBase | HBase |
| 6 | `start-rest.sh` | **HBase REST** — API REST pour HBase | HBase |

> Les services se stoppent avec `docker compose down`.
