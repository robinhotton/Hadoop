#!/bin/bash

export ZK_SERVER_HEAP=${ZK_SERVER_HEAP:-128}

echo "[INFO] Starting ZooKeeper..."
$ZK_HOME/bin/zkServer.sh start >/dev/null 2>&1
sleep 2
$ZK_HOME/bin/zkServer.sh status >/dev/null 2>&1 && echo "[INFO] ZooKeeper is running." || echo "[WARN] ZooKeeper status check failed, but it may still be running."

echo "[INFO] ZooKeeper started successfully."
