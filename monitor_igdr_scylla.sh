#!/bin/bash
#
# IMPORTANT: adapt the variable NODETOOL_AUTH by adding the authentication options for nodetool in your environment
# and other options that may be needed ! Empty var -> no authentication parameters
NODETOOL_AUTH=""

# IMPORTANT: adapt the variable CQLSH_AUTH by adding the authentication options for cqlsh in your environment
# e.g. CQLSH_AUTH="-u <your user> -p <your password> --ssl --cqlsh=/path to your file/cqlshrc"
# and other options that may be needed ! Empty var -> no authentication parameters
CQLSH_AUTH=""

# days for logs. Increase it if not covering the time of the issue under investigation
DAY_LOGS=3

#the script will end itself after this amount of seconds if no Ctrl-C received
MAX_SECONDS=900

#seconds between iostat, top, mpstats samples
OS_STATS_INTERVAL=1

#---- End of normal user customization ----
RUN_ID=`date +%s`

#all timestamps in ISO
isodate="date --iso-8601=seconds"
export S_TIME_FORMAT=ISO

#presumes only ONE DSE process is running,
PS_LINE=$(ps -e -o pid,user:20,cmd | grep scylla | grep "\-\-listen-address" | grep -v grep)
SCYLLA_OWNER=$(echo $PS_LINE| awk '{print $2}' -)
SCYLLA_PID=$(echo $PS_LINE| awk '{print $1}' -)
WHOAMI=`whoami`

trap ctrl_c INT
function ctrl_c() {
   echo "CTRL-C pressed. Terminating background activity"
   # Capturing logs before closing
   echo "capturing logs before finishing"
   journalctl _COMM=scylla --since "$DAY_LOGS days ago" > scylla-logs-`hostname`-$RUN_ID.out
   # terminating
   kill -TERM -- -$$
   do_end
}

do_proxyhistograms() {
   sleep 2;while [ 1 ];do echo; $isodate; echo '=========='; nodetool $NODETOOL_AUTH proxyhistograms; sleep 60; done >> proxyhistograms-`hostname`-$RUN_ID.out
}

do_tablehistograms() {
   sleep 1;while [ 1 ];do echo; $isodate; echo '=========='; nodetool $NODETOOL_AUTH tablehistograms; sleep 60; done >> tablehistograms-`hostname`-$RUN_ID.out  2> /dev/null
}

do_tablestats() {
   sleep 5;while [ 1 ];do  echo; $isodate; echo '=========='; nodetool $NODETOOL_AUTH tablestats; sleep 60; done >> tablestats-`hostname`-$RUN_ID.out
}

do_netstats() {
   sleep 3;while [ 1 ];do echo; $isodate; echo '=========='; nodetool $NODETOOL_AUTH netstats; sleep 15; done >> netstats-`hostname`-$RUN_ID.out
}

do_top_cpu_procs () {
    while [ 1 ]; do  echo; $isodate; echo '=========='; top -b | head -n 20 ; sleep $OS_STATS_INTERVAL ;echo; echo '=========='; done >> os_top_cpu-`hostname`-$RUN_ID.out
}


do_begin()
{
   echo "hostname ---"
   hostname
   echo "IP ---"
   hostname -i
   echo "CPUs ---"
   lscpu
   echo "Memory ----"
   free
   echo "processes"
   ps -efl
   echo "mountpoints ---"
   df -h
   echo "..."
   lsblk --output NAME,KNAME,TYPE,MAJ:MIN,FSTYPE,SIZE,RA,MOUNTPOINT,LABEL,ROTA
   #these are from scylla perf configurations
   echo "cpuset.conf output..."
   cat /etc/scylla.d/cpuset.conf
   echo "dev-mode.conf output..."
   cat /etc/scylla.d/dev-mode.conf
   echo "docker.conf output..."
   cat /etc/scylla.d/docker.conf
   echo "housekeeping.cfg output..."
   cat /etc/scylla.d/housekeeping.cfg
   echo "io.conf output..."
   cat /etc/scylla.d/io.conf
   echo "memory.conf output..."
   cat /etc/scylla.d/memory.conf
   #these go in their own file
   nodetool $NODETOOL_AUTH status > nodetool-status-`hostname`-$RUN_ID.out
   nodetool $NODETOOL_AUTH describecluster  > nodetool-describecluster-`hostname`-$RUN_ID.out
   nodetool $NODETOOL_AUTH compactionstats  > nodetool-compactionstats-`hostname`-$RUN_ID.out
   nodetool $NODETOOL_AUTH compactionhistory > nodetool-compactionhistory-`hostname`-$RUN_ID.out
   nodetool $NODETOOL_AUTH gossipinfo  > nodetool-gossipinfo-`hostname`-$RUN_ID.out
   nodetool $NODETOOL_AUTH info  > nodetool-info-`hostname`-$RUN_ID.out
   nodetool $NODETOOL_AUTH listsnapshots  > nodetool-listsnapshots-`hostname`-$RUN_ID.out
   cqlsh $CQLSH_AUTH -e "DESCRIBE FULL SCHEMA;" > schema-`hostname`-$RUN_ID.out
   cat /etc/scylla/scylla.yaml > scylla-yaml-`hostname`-$RUN_ID.out
   cat /etc/scylla/cassandra-rackdc.properties > cassandra-rackdc-properties-`hostname`-$RUN_ID.out
}

# the "main" code -----

#check if sudo is needed and if it works
if [ $WHOAMI != $SCYLLA_OWNER ] ; then
   echo "current user $WHOAMI is not the same as the SCYLLA process owner $SCYLLA_OWNER"
fi     

echo "gather-begin"
echo "ensure sysstat is installed for iostats & mpstat"
do_begin >> common-`hostname`-$RUN_ID.out
echo "gather loop actions"
do_proxyhistograms &
do_tablehistograms &
do_tablestats &
do_netstats &
do_top_cpu_procs &
iostat -x -c -d -t $OS_STATS_INTERVAL >> iostat-`hostname`.out &
mpstat -P ALL -I SCPU -u $OS_STATS_INTERVAL >> mpstat-`hostname`.out &


echo "launched commands, press Ctrl-C to exit, or wait " $MAX_SECONDS " seconds for the script to complete automatically"
echo "children list "
jobs
#wait $MAX_SECONDS to have the lot
for ((n=$MAX_SECONDS;n>0;n--)); do
   echo -e -n $n \\r
   sleep 1
done
echo "end of script"
ctrl_c
