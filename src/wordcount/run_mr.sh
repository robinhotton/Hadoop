#!/bin/bash

# Gestion des erreurs
set -e 

# Récupération des arguments
INPUT_FILE="$1"
MAPPER="$2"
REDUCER="$3"
OUTPUT_DIR="$4"
HBASE_SCRIPT="$5"

# Vérification qte arg recu
if [ $# -lt 4 ]; then
    echo "Usage: $0 <input_file> <mapper.py> <reducer.py> <output_dir> [hbase_script.py]"
    echo ""
    echo "Exemples :"
    echo "  $0 words.txt mapper.py reducer.py wordcount"
    echo "  $0 words.txt mapper.py reducer.py wordcount store_in_hbase.py"
    exit 1
fi


# 1. Vérifier que les fichiers existent
for f in "$INPUT_FILE" "$MAPPER" "$REDUCER"; do
    if [ ! -f "$f" ]; then
        echo "[ERROR] Fichier introuvable : $f"
        exit 1
    fi
done

if [ -n "$HBASE_SCRIPT" ] && [ ! -f "$HBASE_SCRIPT" ]; then
    echo "[ERROR] Fichier introuvable : $HBASE_SCRIPT"
    exit 1
fi


# 2. Créer le dossier input HDFS et copier le fichier
hdfs dfs -mkdir -p input
hdfs dfs -put -f "$INPUT_FILE" "input/$INPUT_FILE"


# 3. Supprimer l'output s'il existe déjà
hdfs dfs -mkdir -p output
hdfs dfs -rm -r "output/$OUTPUT_DIR" 2>/dev/null || true


# 4. Lancer le job MapReduce
hadoop jar "$HADOOP_HOME/share/hadoop/tools/lib/hadoop-streaming-3.3.6.jar" \
    -files "$MAPPER,$REDUCER" \
    -mapper "python3 $(basename "$MAPPER")" \
    -reducer "python3 $(basename "$REDUCER")" \
    -input "input/$INPUT_FILE" \
    -output "output/$OUTPUT_DIR"


# 5. Afficher le résultat
echo ""
echo "=== Resultat ==="
if hdfs dfs -test -e "output/$OUTPUT_DIR/_SUCCESS" 2>/dev/null; then
    if [ -n "$HBASE_SCRIPT" ]; then
        hdfs dfs -cat "output/$OUTPUT_DIR/part-*" | python3 "$HBASE_SCRIPT"
    else
        hdfs dfs -cat "output/$OUTPUT_DIR/part-*"
    fi
else
    echo "[ERROR] Le job n'a pas produit de sortie (_SUCCESS absent)"
fi
