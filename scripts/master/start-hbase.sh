#!/bin/bash

echo "[INFO] Starting HBase (Master + RegionServers)..."
$HBASE_HOME/bin/start-hbase.sh

echo "[INFO] HBase started successfully."
