#!/usr/bin/env python3

import happybase

HOST = "localhost"
PORT = 9090

def main():
    connection = happybase.Connection(host=HOST, port=PORT)
    print(f"[OK] Connecte a HBase Thrift ({HOST}:{PORT})")

    tables = connection.tables()
    print(f"Tables existantes : {[t.decode() for t in tables]}")

    table_name = "etudiants"
    if table_name.encode() not in connection.tables():
        connection.create_table(table_name, {"info": dict(max_versions=1)})
        print(f"[OK] Table '{table_name}' creee")

    table = connection.table(table_name)

    print("\n--- Insertion de donnees ---")
    table.put(b"row1", {b"info:nom": b"Dupont", b"info:prenom": b"Jean", b"info:age": b"22"})
    table.put(b"row2", {b"info:nom": b"Martin", b"info:prenom": b"Sophie", b"info:age": b"24"})
    table.put(b"row3", {b"info:nom": b"Bernard", b"info:prenom": b"Pierre", b"info:age": b"23"})
    print("[OK] Donnees inserees")

    print("\n--- Scan de la table ---")
    for key, data in table.scan():
        print(f"  Row: {key.decode()}")
        for col, val in data.items():
            print(f"    {col.decode()} = {val.decode()}")

    print("\n--- Recuperation d'une ligne ---")
    row = table.row(b"row1")
    print(f"  row1: nom={row.get(b'info:nom', b'').decode()}, "
          f"prenom={row.get(b'info:prenom', b'').decode()}, "
          f"age={row.get(b'info:age', b'').decode()}")

    connection.close()
    print("\n[OK] Connexion fermee")

if __name__ == "__main__":
    main()
