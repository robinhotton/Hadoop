#!/bin/bash

HOSTNAME=$(hostname)
ROLE=${ROLE:-slave}

HADOOP_HOME=${HADOOP_HOME:-/opt/hadoop}
HBASE_HOME=${HBASE_HOME:-/opt/hbase}
ZK_HOME=${ZK_HOME:-/opt/zookeeper}
HADOOP_CONF_DIR=$HADOOP_HOME/etc/hadoop
HBASE_CONF_DIR=$HBASE_HOME/conf

export HADOOP_HOME HBASE_HOME ZK_HOME HADOOP_CONF_DIR HBASE_CONF_DIR
export PATH=$PATH:$HADOOP_HOME/bin:$HADOOP_HOME/sbin:$HBASE_HOME/bin:$ZK_HOME/bin

# ── System ────────────────────────────────────────────────────

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

setup_hadoop_profile() {
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

# ── SSH config (non-keys) ─────────────────────────────────────

setup_ssh_config() {
    sed -i 's/#PermitRootLogin yes/PermitRootLogin yes/' /etc/ssh/sshd_config 2>/dev/null
    grep -q "StrictHostKeyChecking no" /etc/ssh/ssh_config || \
        echo "StrictHostKeyChecking no" >> /etc/ssh/ssh_config
    grep -q "UserKnownHostsFile /dev/null" /etc/ssh/ssh_config || \
        echo "UserKnownHostsFile /dev/null" >> /etc/ssh/ssh_config
}

# ── Hadoop env tweaks (heaps) ─────────────────────────────────

setup_hadoop_heaps() {
    cat >> $HADOOP_CONF_DIR/hadoop-env.sh <<-EOF
export JAVA_HOME=$JAVA_HOME
export HADOOP_HOME=$HADOOP_HOME
export HADOOP_CONF_DIR=$HADOOP_CONF_DIR
export HADOOP_HEAPSIZE=512
export HDFS_NAMENODE_OPTS="-Xms512m -Xmx512m"
export HDFS_DATANODE_OPTS="-Xms256m -Xmx256m"
EOF

    cat >> $HADOOP_CONF_DIR/yarn-env.sh <<-EOF
export YARN_RESOURCEMANAGER_OPTS="-Xms512m -Xmx512m"
export YARN_NODEMANAGER_OPTS="-Xms256m -Xmx256m"
export YARN_HEAPSIZE=512
EOF

    cat >> $HBASE_CONF_DIR/hbase-env.sh <<-EOF
export HBASE_HEAPSIZE=512
export HBASE_MASTER_OPTS="-Xms512m -Xmx512m"
export HBASE_REGIONSERVER_OPTS="-Xms512m -Xmx512m"
export HBASE_THRIFT_OPTS="-Xms256m -Xmx256m"
EOF
}

# ── Cleanup ───────────────────────────────────────────────────

cleanup() {
    echo "[INFO] Container stopped."
    exit 0
}

# ── Main ──────────────────────────────────────────────────────

trap cleanup SIGTERM SIGINT

setup_hosts
start_ssh
setup_ssh_config
setup_hadoop_profile
setup_hadoop_heaps

if [ "$ROLE" = "master" ]; then
    echo "[INFO] Initializing ZooKeeper myid..."
    echo "1" > /data/zookeeper/myid

    echo "[INFO] Formatting HDFS NameNode (first run only)..."
    if [ ! -f /data/hdfs/namenode/current/VERSION ]; then
        $HADOOP_HOME/bin/hdfs namenode -format -force -nonInteractive
    fi
fi

echo "[INFO] Container ready. Role: $ROLE"

while true; do
    sleep 30
done
