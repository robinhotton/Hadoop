#!/bin/bash

echo "[INFO] Starting all services..."
./start-zookeeper.sh
./start-dfs.sh
./start-yarn.sh
./start-jobhistory.sh
./start-hbase.sh
./start-thrift.sh
./start-rest.sh
echo "[INFO] All services started successfully."