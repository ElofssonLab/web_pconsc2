#!/bin/bash

AddAbsolutePath(){ #$fileordir#{{{
    #convert a path to absolute path, 
    #return "" if the file or path does not exist
    if [ ! -e "$1" ]; then 
        return 1
    fi
    curr="$PWD"
    if [ -d "$1" ]; then
        cd "$1" && echo "$PWD"       
    else 
        file="$(basename "$1")"
        cd "$(dirname "$1")" && dir="$PWD"
        echo "$dir/$file"
    fi
    cd "$curr"
    return 0
}
#}}}

rundir=`dirname $0`
rundir=`AddAbsolutePath $rundir`
basedir=$rundir/../
user=ubuntu

OPT="--exclude=env --exclude=tmp --exclude=.dump_tmp --exclude=result --exclude=md5 --exclude=.suq --exclude=log"
OPT1="--exclude=~* --exclude=*~ --exclude=.*.sw[mopn]"
SSH=""

hostname=`hostname`
case $hostname in
    *pdc*)serverlistfile=$basedir/debug/docroot/pdc.serverlist.txt;;
    *egi*)serverlistfile=$basedir/debug/docroot/egi.serverlist.txt;;
    **)serverlistfile=$basedir/debug/docroot/smog.serverlist.txt;;
esac

serverlist=$(cat $serverlistfile)

for server in $serverlist; do
    # sync data to that VM
    rsync -auvz $OPT1 $OPT -e "ssh -o StrictHostKeyChecking=no" $basedir/   $user@$server:/server/var/www/web_pconsc/
    # run install.sh to create necessary folders
    echo "running command in the remote: $user@$server"
    ssh $user@$server << EOF
bash /server/var/www/web_pconsc/install.sh
EOF
done
