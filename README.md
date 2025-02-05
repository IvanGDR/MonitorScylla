# MonitorScylla


Before copying the script on the various nodes, edit it and revise the value of the variables at the top NODETOOL_AUTH, MAX_SECONDS and OS_STATS_INTERVAL. Also ensure you have SYSSTAT tool installed.

    adapt the variable NODETOOL_AUTH by adding the authentication options for nodetool in your environment and other options that may be needed. Empty var -> no authentication parameters

    If the user that will run the script is not the same that runs the Scylla process make sure the user running the script can sudo without password (as it's a script)

    The script runs for up to MAX_SECONDS seconds (default set ot 900 == 15mins). If your test runs for longer (or for less time) adapt the value accordingly make sure it covers enough time for starting the script before your test starts, and the test completes (or errors out) before the script ends

If the test to monitor is going to run for a long time, for example 1 hour or more, you may want to lower the frequency at which the most detailed samples are taken.

    SJK_INTERVAL controls the sample frequency of the nodetool sjk commands (ttop and stcap) and need to be expressed in milliseconds including the ms as in 5000ms for a 5 second sampling interval
    OS_STATS_INTERVAL controls the sample frequency of the commands top,iostat and mpstat. It's a number of seconds between samples.

On each node

    create a directory and place the script inside. Set the script as executable
    when ready to run your test program, start the script on all nodes of the DSE cluster
    wait for the scripts to start counting down, then start your test program and note down the time it started (including timezone)
    once the program reproduces the issue
        if you use jstack , wait 10s then hit Ctrl-C on the terminals
        if you don't use jstack, wait 1 minute and then hit Ctrl-C on the terminals

After the test, on each node

    create a compressed tarball with
        the content of the script dir
        the complete DSE logs

    for example if your script directory is /tmp/datastax_script and your DSE logs are under /var/log/cassandra

     tar zcvf out-`hostname -i`-`date +%s`.tar.gz   /tmp/datastax_script  /var/log/cassandra

