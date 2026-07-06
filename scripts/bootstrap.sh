#!/bin/bash

HOSTNAME=$(hostname)
ROLE=${ROLE:-slave}

HADOOP_HOME=${HADOOP_HOME:-/opt/hadoop}
HBASE_HOME=${HBASE_HOME:-/opt/hbase}
ZK_HOME=${ZK_HOME:-/opt/zookeeper}
SPARK_HOME=${SPARK_HOME:-/opt/spark}

export HADOOP_HOME HBASE_HOME ZK_HOME SPARK_HOME
export HADOOP_CONF_DIR=$HADOOP_HOME/etc/hadoop
export HBASE_CONF_DIR=$HBASE_HOME/conf
export PATH=$PATH:$HADOOP_HOME/bin:$HADOOP_HOME/sbin:$HBASE_HOME/bin:$ZK_HOME/bin:$SPARK_HOME/bin

setup_hosts() {
    cat > /etc/hosts <<-EOF
127.0.0.1  localhost
172.20.0.10 hadoop-master
172.20.0.20 hadoop-slave1
172.20.0.30 hadoop-slave2
EOF
}

start_ssh() {
    if [ ! -f /var/run/sshd/sshd.pid ]; then
        /usr/sbin/sshd
    fi
}

setup_hadoop_env() {
    mkdir -p /tmp/hadoop
    cat > /etc/profile.d/hadoop.sh <<-EOF
export JAVA_HOME=$JAVA_HOME
export HADOOP_HOME=$HADOOP_HOME
export HBASE_HOME=$HBASE_HOME
export ZK_HOME=$ZK_HOME
export SPARK_HOME=$SPARK_HOME
export HADOOP_CONF_DIR=$HADOOP_CONF_DIR
export HBASE_CONF_DIR=$HBASE_CONF_DIR
export PATH=\$PATH:$HADOOP_HOME/bin:$HADOOP_HOME/sbin:$HBASE_HOME/bin:$ZK_HOME/bin:$SPARK_HOME/bin
EOF
    chmod +x /etc/profile.d/hadoop.sh
}

start_master() {
    echo "[INFO] Initializing ZooKeeper myid..."
    echo "1" > /data/zookeeper/myid

    echo "[INFO] Starting ZooKeeper..."
    $ZK_HOME/bin/zkServer.sh start

    echo "[INFO] Formatting HDFS NameNode (first run only)..."
    if [ ! -f /data/hdfs/namenode/current/VERSION ]; then
        $HADOOP_HOME/bin/hdfs namenode -format -force -nonInteractive
    fi

    echo "[INFO] Starting HDFS NameNode..."
    $HADOOP_HOME/bin/hdfs --daemon start namenode

    echo "[INFO] Starting SecondaryNameNode..."
    $HADOOP_HOME/bin/hdfs --daemon start secondarynamenode

    echo "[INFO] Starting YARN ResourceManager..."
    $HADOOP_HOME/bin/yarn --daemon start resourcemanager

    echo "[INFO] Starting MapReduce HistoryServer..."
    $HADOOP_HOME/bin/mapred --daemon start historyserver

    echo "[INFO] Starting HBase and Spark in background (waiting for DataNodes)..."
    (
        echo "[INFO] Waiting for at least 1 DataNode before starting HBase..."
        for i in $(seq 1 60); do
            DN_REPORT=$($HADOOP_HOME/bin/hdfs dfsadmin -report 2>/dev/null)
            DN_COUNT=$(echo "$DN_REPORT" | grep -c "Live datanodes" 2>/dev/null || echo 0)
            if [ "$DN_COUNT" -gt 0 ] 2>/dev/null; then
                break
            fi
            sleep 5
        done
        echo "[INFO] DataNode detected. Starting HBase..."
        $HBASE_HOME/bin/hbase-daemon.sh start master
        $HBASE_HOME/bin/hbase-daemon.sh start thrift
        $HBASE_HOME/bin/hbase-daemon.sh start rest -p 9091
        $HADOOP_HOME/bin/hdfs dfs -mkdir -p /spark-logs 2>/dev/null || true
        echo "[INFO] HBase and Spark services started."
    ) &

    echo "[INFO] Core master services started (HBase will follow when DataNodes join)."
}

start_slave() {
    echo "[INFO] Waiting for HDFS NameNode at hadoop-master:9000..."
    for i in $(seq 1 30); do
        if echo > /dev/tcp/hadoop-master/9000 2>/dev/null; then
            break
        fi
        sleep 2
    done

    echo "[INFO] Starting HDFS DataNode..."
    $HADOOP_HOME/bin/hdfs --daemon start datanode

    echo "[INFO] Starting YARN NodeManager..."
    $HADOOP_HOME/bin/yarn --daemon start nodemanager

    echo "[INFO] Starting HBase RegionServer..."
    $HBASE_HOME/bin/hbase-daemon.sh start regionserver

    echo "[INFO] Slave services started."
}

cleanup() {
    echo "[INFO] Shutting down services..."
    if [ "$ROLE" = "master" ]; then
        $HBASE_HOME/bin/hbase-daemon.sh stop rest 2>/dev/null || true
        $HBASE_HOME/bin/hbase-daemon.sh stop thrift 2>/dev/null || true
        $HBASE_HOME/bin/hbase-daemon.sh stop master 2>/dev/null || true
        $HADOOP_HOME/bin/mapred --daemon stop historyserver 2>/dev/null || true
        $HADOOP_HOME/bin/yarn --daemon stop resourcemanager 2>/dev/null || true
        $HADOOP_HOME/bin/hdfs --daemon stop namenode 2>/dev/null || true
        $HADOOP_HOME/bin/hdfs --daemon stop secondarynamenode 2>/dev/null || true
        $ZK_HOME/bin/zkServer.sh stop 2>/dev/null || true
    else
        $HBASE_HOME/bin/hbase-daemon.sh stop regionserver 2>/dev/null || true
        $HADOOP_HOME/bin/yarn --daemon stop nodemanager 2>/dev/null || true
        $HADOOP_HOME/bin/hdfs --daemon stop datanode 2>/dev/null || true
    fi
    exit 0
}

trap cleanup SIGTERM SIGINT

setup_hosts
start_ssh
setup_hadoop_env

if [ "$ROLE" = "master" ]; then
    start_master
else
    start_slave
fi

echo "[INFO] Container ready. Role: $ROLE"

while true; do
    sleep 30
done