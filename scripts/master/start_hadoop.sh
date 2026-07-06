#!/bin/bash

export HDFS_NAMENODE_USER=root
export HDFS_DATANODE_USER=root
export HDFS_SECONDARYNAMENODE_USER=root
export YARN_RESOURCEMANAGER_USER=root
export YARN_NODEMANAGER_USER=root

echo "[INFO] Starting HDFS..."
$HADOOP_HOME/sbin/start-dfs.sh

echo "[INFO] Starting YARN..."
$HADOOP_HOME/sbin/start-yarn.sh

echo "[INFO] Starting MapReduce HistoryServer..."
$HADOOP_HOME/bin/mapred --daemon start historyserver

echo "[INFO] Creating /spark-logs in HDFS..."
$HADOOP_HOME/bin/hdfs dfs -mkdir -p /spark-logs 2>/dev/null || true

echo "[INFO] Hadoop services started successfully."
