# Déploiement sur Proxmox


## 1. Prérequis

| Ressource | Minimum | Recommandé |
|-----------|---------|------------|
| vCPU | 2 cœurs | 4 cœurs |
| RAM | 3.5 GB | 8 GB |
| Disque | 30 GB | 50 GB |
| OS invité | Debian 12 / Ubuntu 22.04 / Rocky Linux 9 | Debian 12 |
| Docker | Engine 24+ | Dernière version stable |


## 2. Connexion SSH à la VM

---

## 3. Création de la VM

---

## 4. Installation de Docker

---

## 5. Copie du projet sur la VM


---

## 6. Build et lancement du cluster

```bash
cd /root/hadoop-cluster

# Build de l'image (~5-10 min)
docker compose build

# Lancement des conteneurs
docker compose up -d

# Vérification
docker compose ps
```

Les 3 conteneurs doivent être `Up` :

```
NAME            STATUS   PORTS
hadoop-master   Up       ...
hadoop-slave1   Up       ...
hadoop-slave2   Up       ...
```

---

## 7. Ports exposés

### Tableau des ports

| Port hôte | Port conteneur | Service | Type | URL |
|-----------|---------------|---------|------|-----|
| 9870 | 9870 | NameNode (HDFS) | UI web | `http://<IP_VM>:9870` |
| 8088 | 8088 | ResourceManager (YARN) | UI web | `http://<IP_VM>:8088` |
| 16010 | 16010 | HMaster (HBase) | UI web | `http://<IP_VM>:16010` |
| 8041 | 8042 | NodeManager slave1 | UI web | `http://<IP_VM>:8041` |
| 8042 | 8042 | NodeManager slave2 | UI web | `http://<IP_VM>:8042` |
| 9000 | 9000 | NameNode RPC | Binaire | — |
| 9090 | 9090 | HBase Thrift | Binaire | — |
| 9091 | 9091 | HBase REST API | API HTTP | `http://<IP_VM>:9091` |

---

## 8. Démarrage des services

```bash
# Accéder au master
docker exec -it hadoop-master bash

# Tout lancer en une commande
./start-all.sh

# Vérifier les processus
jps
```

### Vérification depuis un navigateur

Depuis votre poste, ouvrir :

| URL | Ce qu'on doit voir |
|-----|-------------------|
| `http://<IP_VM>:9870` | Interface HDFS NameNode (Overview, Datanodes, Utilities) |
| `http://<IP_VM>:8088` | Interface YARN ResourceManager (cluster metrics, jobs, scheduler) |
| `http://<IP_VM>:16010` | Interface HBase Master (tables, regions, masters) |
| `http://<IP_VM>:9091` | Réponse XML/JSON de l'API REST HBase |
| `http://<IP_VM>:8041` | NodeManager slave1 (logs, nodes) |
| `http://<IP_VM>:8042` | NodeManager slave2 (logs, nodes) |

---

## 9. Arrêt du cluster

```bash
# 1. Arrêter les services dans le master
docker exec hadoop-master bash -c "pkill -f 'hbase|zookeeper|ResourceManager|NodeManager|NameNode|DataNode|SecondaryNameNode|historyserver' 2>/dev/null"

# 2. Arrêter les conteneurs
cd /root/hadoop-cluster
docker compose down
```

---

## 10. Démarrage automatique

Start les 3 containers au lancement de la VM

---

## 11. Sécurité

- **Changer le mot de passe root** de la VM après l'installation
- ou non, a voir

---

## 12. Résolution de problèmes

### Les UIs web ne répondent pas

1. Vérifier que les services sont actifs dans le master :
   ```bash
   docker exec hadoop-master jps
   ```

2. Vérifier les ports ouverts sur la VM :
   ```bash
   ss -tlnp | grep -E '9870|8088|16010|9091|8041|8042'
   ```

3. Vérifier le pare-feu Proxmox et le pare-feu local de la VM

### Les conteneurs ne démarrent pas

```bash
# Voir les logs
docker compose logs

# Vérifier les ressources disponibles
free -h
df -h
```

### Rebuild complet

```bash
docker compose down -v
docker compose build --no-cache
docker compose up -d
```
