#!/bin/bash
# copy pconsc data from this node to other node

usage="
USAGE: $0 IP [IP...]
"

user=ubuntu
exec_cmd(){
    echo "$*"
    eval "$*"
}

if [ $# -lt 1 ];then
    echo "$usage"
    exit 1
fi

# rundir=`dirname $0`
# rundir=`realpath $rundir`
# cd $rundir

OPT="--exclude=*.gz --exclude=uniref100*"
OPT1="--exclude=~* --exclude=*~ --exclude=.*.sw[mopn]"

datapath=/data3/share/pconsc2/
remote_datapath=/media/storage/usr/share/pconsc2/

if [ ! -d $datapath ];then
    echo "datapath $datapath is empty. exit"
    exit 1
fi

for ipaddress in $*; do
    ssh -o StrictHostKeyChecking=no $user@$ipaddress << EOF
mkdir -p $remote_datapath
EOF
    exec_cmd "rsync -auvz $OPT1 $OPT  $datapath/   ubuntu@$ipaddress:$remote_datapath/"
done
