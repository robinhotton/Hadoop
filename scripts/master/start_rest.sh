#!/bin/bash

echo "[INFO] Starting HBase REST..."
$HBASE_HOME/bin/hbase-daemon.sh start rest

echo "[INFO] HBase REST started successfully."
