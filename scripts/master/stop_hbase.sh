#!/bin/bash

echo "[INFO] Stopping HBase Thrift..."
$HBASE_HOME/bin/hbase-daemon.sh stop thrift

echo "[INFO] Stopping HBase..."
$HBASE_HOME/bin/stop-hbase.sh

echo "[INFO] Stopping ZooKeeper..."
$ZK_HOME/bin/zkServer.sh stop

echo "[INFO] HBase services stopped successfully."
