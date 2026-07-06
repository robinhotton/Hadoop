#!/bin/bash

echo "[INFO] Stopping HBase REST..."
$HBASE_HOME/bin/hbase-daemon.sh stop rest

echo "[INFO] HBase REST stopped successfully."
