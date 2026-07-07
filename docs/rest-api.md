# API REST HBase

Le serveur REST HBase expose les données via HTTP (port 9091).
Les formats acceptés sont **XML** (défaut) et **JSON** (`Accept: application/json`).

> Les clés et valeurs sont encodées en **base64** dans les payloads JSON.

## Opérations de base

### Lister les tables

```bash
curl http://<IP>:9091/
```

### Version de l'API

```bash
curl http://<IP>:9091/version
```

### Statut du cluster

```bash
curl http://<IP>:9091/status/cluster
```

### Schéma d'une table

```bash
curl http://<IP>:9091/test/schema
```

## CRUD

### Lire une ligne

```bash
curl -H "Accept: application/json" http://<IP>:9091/test/ma_cle
```

### Insérer / mettre à jour une ligne

```bash
curl -X PUT \
  -H "Content-Type: application/json" \
  -d '{"Row":[{"key":"ma_cle","Cell":[{"column":"cf:nom","$":"ma_valeur"}]}]}' \
  http://<IP>:9091/test/ma_cle
```

### Supprimer une ligne

```bash
curl -X DELETE http://<IP>:9091/test/ma_cle
```

## Scanner

### Créer un scanner

```bash
curl -X POST \
  -H "Content-Type: application/json" \
  -d '{"scan":{"startRow":"","endRow":"","columns":["cf:nom"]}}' \
  http://<IP>:9091/test/scanner
```

Retourne un header `Location` avec l'URL du scanner.

### Lire les résultats du scanner

```bash
curl http://<IP>:9091/test/scanner/ID_DU_SCANNER
```

### Supprimer un scanner

```bash
curl -X DELETE http://<IP>:9091/test/scanner/ID_DU_SCANNER
```

## Gestion des tables

### Désactiver une table

```bash
curl -X POST http://<IP>:9091/test/disable
```

### Activer une table

```bash
curl -X POST http://<IP>:9091/test/enable
```

### Supprimer une table

```bash
curl -X POST http://<IP>:9091/test/disable
curl -X DELETE http://<IP>:9091/test/schema
```

## Format JSON

Exemple de payload pour PUT :

```json
{
  "Row": [
    {
      "key": "bGlnbmUx",
      "Cell": [
        {
          "column": "Y2Y6bm9t",
          "timestamp": 1783415462126,
          "$": "aGVsbG8="
        }
      ]
    }
  ]
}
```

- `key` : row key en base64
- `column` : famille:qualifier en base64
- `$` : valeur en base64
- `timestamp` : optionnel (horodatage Unix en ms)
