#!/bin/bash

# Gestion des erreurs
set -e 

# Récupération des arguments
INPUT_FILE="$1"
MAPPER="$2"
REDUCER="$3"
OUTPUT_DIR="$4"

# Vérification qte arg recu
if [ $# -lt 4 ]; then
    echo "Usage: $0 <input_file> <mapper.py> <reducer.py> <output_dir>"
    echo ""
    echo "Exemple wordcount :"
    echo "  $0 data.txt wordcount_mapper.py wordcount_reducer.py wordcount"
    exit 1
fi


# 1. Vérifier que les fichiers existent
for f in "$INPUT_FILE" "$MAPPER" "$REDUCER"; do
    if [ ! -f "$f" ]; then
        echo "[ERROR] Fichier introuvable : $f"
        exit 1
    fi
done


# 2. Créer le dossier input HDFS et copier le fichier
hdfs dfs -mkdir -p input
hdfs dfs -put -f "$INPUT_FILE" "input/$INPUT_FILE"


# 3. Supprimer l'output s'il existe déjà
hdfs dfs -mkdir -p output
hdfs dfs -rm -r "output/$OUTPUT_DIR" 2>/dev/null || true


# 4. Lancer le job MapReduce
hadoop jar "$HADOOP_HOME/share/hadoop/tools/lib/hadoop-streaming-*.jar" \
    -files "$MAPPER,$REDUCER" \
    -mapper "python3 $(basename "$MAPPER")" \
    -reducer "python3 $(basename "$REDUCER")" \
    -input "input/$INPUT_FILE" \
    -output "output/$OUTPUT_DIR"


# 5. Afficher le résultat
echo ""
echo "=== Resultat ==="
hdfs dfs -cat "output/$OUTPUT_DIR/part-*"

# 6. Stocker le résultat dans HBase (wordcount uniquement)
if [ "$OUTPUT_DIR" = "wordcount" ]; then
    echo ""
    echo "=== Insertion dans HBase ==="
    hdfs dfs -cat "output/$OUTPUT_DIR/part-*" | python3 store_in_hbase.py
fi
