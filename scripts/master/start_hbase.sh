#!/bin/bash

echo "[INFO] Starting ZooKeeper..."
$ZK_HOME/bin/zkServer.sh start 2>/dev/null
sleep 2
$ZK_HOME/bin/zkServer.sh status 2>/dev/null || echo "[WARN] ZooKeeper status check failed, but it may still be running."

echo "[INFO] Starting HBase (Master + RegionServers)..."
$HBASE_HOME/bin/start-hbase.sh

echo "[INFO] Starting HBase Thrift..."
$HBASE_HOME/bin/hbase-daemon.sh start thrift

echo "[INFO] HBase services started successfully."
