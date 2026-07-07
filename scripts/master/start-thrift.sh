#!/bin/bash

echo "[INFO] Starting HBase Thrift..."
$HBASE_HOME/bin/hbase-daemon.sh start thrift

echo "[INFO] HBase Thrift started successfully."
