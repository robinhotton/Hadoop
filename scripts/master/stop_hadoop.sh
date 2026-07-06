#!/bin/bash

export HDFS_NAMENODE_USER=root
export HDFS_DATANODE_USER=root
export HDFS_SECONDARYNAMENODE_USER=root
export YARN_RESOURCEMANAGER_USER=root
export YARN_NODEMANAGER_USER=root

echo "[INFO] Stopping MapReduce HistoryServer..."
$HADOOP_HOME/bin/mapred --daemon stop historyserver

echo "[INFO] Stopping YARN..."
$HADOOP_HOME/sbin/stop-yarn.sh

echo "[INFO] Stopping HDFS..."
$HADOOP_HOME/sbin/stop-dfs.sh

echo "[INFO] Hadoop services stopped successfully."
