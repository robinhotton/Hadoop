#!/bin/bash

echo "[INFO] Starting MapReduce JobHistory Server..."
$HADOOP_HOME/bin/mapred --daemon start historyserver

echo "[INFO] MapReduce JobHistory Server started successfully."
