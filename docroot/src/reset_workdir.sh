#!/bin/bash

# reset the workdir as if it is not started

usage="
USAGE: $0 workdir [workdir ...]
"

#date  email  host  jobname  name  pconsc.start  pconsc.tar.gz  run_log.txt  run_pconsc.ref  sequence  sequence.fasta  server_submitted  wget.log

for workdir in $*; do
    rm -f $workdir/pconsc.start $workdir/pconsc.tar.gz $workdir/server_submitted $workdir/pconsc.stop
done
