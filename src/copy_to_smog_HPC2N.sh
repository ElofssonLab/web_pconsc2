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
remotehostlist="
130.239.46.222
130.239.46.224
130.239.46.225
"


OPT="--exclude=env --exclude=tmp --exclude=.dump_tmp --exclude=result --exclude=md5 --exclude=.suq --exclude=log"
OPT1="--exclude=~* --exclude=*~ --exclude=.*.sw[mopn]"

for remotehost in $remotehostlist; do
    ssh -o StrictHostKeyChecking=no $user@$remotehost << EOF
mkdir -p /media/storage/server
mkdir -p /media/storage/scratch
mkdir -p /server/var/www/web_pconsc/
EOF
    rsync -auvz $OPT1 $OPT  -e "ssh -o StrictHostKeyChecking=no" $basedir/   $user@$remotehost:/server/var/www/web_pconsc/
    # run install.sh to create necessary folders
    echo "running command in the remote host: $user@$remotehost"
    ssh -o StrictHostKeyChecking=no $user@$remotehost << EOF
bash /server/var/www/web_pconsc/install.sh
EOF


done
