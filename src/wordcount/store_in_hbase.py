#!/usr/bin/env python3

import sys
import happybase

HOST = "localhost"
PORT = 9090
TABLE_NAME = "wordcount"
COLUMN_FAMILY = "stats"


def main():
    connection = happybase.Connection(host=HOST, port=PORT)
    print(f"[OK] Connecte a HBase Thrift ({HOST}:{PORT})")

    if TABLE_NAME.encode() not in connection.tables():
        connection.create_table(TABLE_NAME, {COLUMN_FAMILY: dict(max_versions=1)})
        print(f"[OK] Table '{TABLE_NAME}' creee")
    else:
        print(f"[OK] Table '{TABLE_NAME}' existe deja")

    table = connection.table(TABLE_NAME)
    inserted = 0

    print("\n--- Insertion dans HBase (flux) ---")
    for line in sys.stdin:
        line = line.strip()
        if not line or "\t" not in line:
            continue
        word, count = line.split("\t", 1)
        row_key = word.lower().strip()
        table.put(row_key.encode(), {f"{COLUMN_FAMILY}:count": count.strip().encode()})
        inserted += 1

    if inserted == 0:
        print("[ERROR] Aucune donnee recue sur stdin. "
              "Usage: hdfs dfs -cat /output/wordcount/part-* | python3 store_in_hbase.py")
        connection.close()
        sys.exit(1)

    print(f"\n[OK] {inserted} mots inseres dans HBase")

    print("\n--- Scan de la table ---")
    for key, cols in table.scan():
        val = cols.get(f"{COLUMN_FAMILY}:count", b"").decode()
        print(f"  {key.decode()} : {val}")

    connection.close()
    print("\n[OK] Termine")


if __name__ == "__main__":
    main()
