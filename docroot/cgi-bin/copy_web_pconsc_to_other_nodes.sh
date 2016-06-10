#!/bin/bash

nodelist="
10.20.20.29
10.20.20.36
10.20.20.46
10.20.20.51
"

OPT1="--exclude=~* --exclude=*~ --exclude=.*.sw[mopn]"
OPT2="--exclude=.dump_tmp"
for node in $nodelist; do
    rsync -auvz -e ssh $OPT1 --exclude=tmp/* --exclude=result/md5 --exclude=result/[a-z]* --exclude=[0-9]*  ~/web_pconsc/ $node:~/web_pconsc/
    rsync -auvz -e ssh $OPT1  ~/pconsc2/ $node:~/pconsc2/
done
