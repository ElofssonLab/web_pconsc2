#!/bin/bash
# install web_pconsc from the debug version to the release version
rundir=`dirname $0`

rundir=`readlink -f $rundir`
cd $rundir


folderlist="
tmp
log
result
md5
"

echo "setting up file permissions"
platform_info=`python -mplatform |  tr '[:upper:]' '[:lower:]'`
platform=
case $platform_info in 
    *centos*)platform=centos;;
    *ubuntu*)platform=ubuntu;;
    *)platform=other;;
esac


case $platform in 
    centos) user=apache;group=apache;;
    ubuntu) user=www-data;group=www-data;;
    other)echo Unrecognized plat form; exit 1;;
esac

for folder in $folderlist;do
    dir=$rundir/$mode/$folder
    if [ ! -d $dir ];then
        mkdir -p $dir
    fi
    sudo chmod 755 $dir
    sudo chown -R $user:$group $dir
done

    # make symbolic links

cd $rundir/$mode/docroot
for folder in $folderlist; do
    if [ ! -L $folder ];then
        ln -s ../$folder .
    fi
done

if [ ! -d /scratch ];then
    if [ -d /media/storage ];then
        if [ ! -d /media/storage/scratch ];then
            mkdir -p /media/storage/scratch
        fi
        sudo chmod 777 /media/storage/scratch
        sudo ln -s /media/storage/scratch /scratch
    fi
fi
