#!/bin/bash

# Filename: nova_init_vm.sh 
# Description: 
#      Init a VM for pconsc2
#      this should be run on the node pconsc2_frontend

# Author: Nanjiang Shu (nanjiang.shu@scilifelab.se)

usage="
USAGE:  $0 [-vmname STR] [-max INT]
OPTIONS:
  -max INT    Set the maximum number of VMs, (default: 5)
  -h, --help  Print this help message and exit

Created 2014-12-01, updated 2014-12-01, Nanjiang Shu

Examples:
    $0                      #boot a new VM and prepare data
    $0 -vmname pconsc_2     #prepare data for an existing vm
"

BootVM(){   #{{{
    nr_largest_vm=`echo "$info_running_VM" | awk '{print $4}' | awk -F "_" '{print $2}' | sort -rg | head -n 1`

    ((nr_new=nr_largest_vm+1))
    vm_name_new=pconsc_${nr_new}
    echo "nova boot --poll --image $image --flavor $flavor --key_name $key $vm_name_new"
    msg=`nova boot --poll --image $image --flavor $flavor --key_name $key $vm_name_new`
    #echo "$vm_name_new"
}
#}}}
CheckNewVM(){ #ipaddress#{{{
    local ip=$1
    if [ "$ip" == "" ];then
        echo "ip is empty. exit"
        exit 1
    fi
    while [ 1 ]; do
        status=$(ssh -o StrictHostKeyChecking=no -o BatchMode=yes -o ConnectTimeout=5 $ip echo ok 2>&1)
        if [[ "$status" == "ok" ]] ; then
            echo "$ip is accessable now"
            break
        elif [[ "$status" == "Permission denied"* ]] ; then
            echo "$ip $status"
        else
            echo "$ip $status"
        fi
        echo "check in 30 seconds..."
        sleep 30s
    done
}
#}}}
CopyData(){ #{{{
    local ip=$1
    if [ "$ip" == "" ];then
        echo "ip is empty. exit"
        exit 1
    fi
    echo "rsync -auvz --exclude=/pconsc2 --exclude=uniref100.* -e \"ssh -o StrictHostKeyChecking=no\" /data3/data_local/ ubuntu@$ip:/data3/data_local/"
    rsync -auvz --exclude=/pconsc2 --exclude=uniref100.* -e "ssh -o StrictHostKeyChecking=no" /data3/data_local/ ubuntu@$ip:/data3/data_local/
}
#}}}
passwdfile=/home/ubuntu/.pconsc/pdccloud.psd
env_init_script=/home/ubuntu/.pconsc/Arne_Scilife-openrc.sh
image=shu_pconsc2_20141201_noDB_noph
key=njNoph
flavor=m1.xlarge
optVM=

MAXN=5
isNonOptionArg=0
while [ "$1" != "" ]; do
    if [ $isNonOptionArg -eq 1 ]; then 
        echo Error! Wrong argument: $1 >&2; exit
        isNonOptionArg=0
    elif [ "$1" == "--" ]; then
        isNonOptionArg=true
    elif [ "${1:0:1}" == "-" ]; then
        case $1 in
            -h | --help) echo "$usage"; exit;;
            -max|--max) MAXN=$2;shift;;
            -vmname|-vmname) optVM=$2;shift;;
            -q|-quiet|--quiet) isQuiet=1;;
            -*) echo Error! Wrong argument: $1 >&2; exit;;
        esac
    else
        echo Error! Wrong argument: $1 >&2; exit
    fi
    shift
done


. $env_init_script < $passwdfile

if [ "$optVM" == "" ];then

    info_running_VM=`nova list | grep pconsc_ | grep -v front`
    num_running_VM=`echo "$info_running_VM"  | wc -l`

    if [ "$num_running_VM" == "" ];then
        echo "$0: something is wrong with nova. exit." >&2
        exit 1
    elif [ $num_running_VM -ge $MAXN ];then
        echo "$0: num_running_VM ($num_running_VM) >= MAXN ($MAXN). No resource available. Exit"
        exit 1
    fi

    # 1. boot a new VM
    vm_name_new=
    BootVM
else
    vm_name_new=$optVM
fi

echo "vm_name_new=$vm_name_new"

# 2.  Get IP of the new VM
ip_new_vm=`nova list | grep "\<$vm_name_new\>" | awk -F "private=" '{print $2}' | awk '{print $1}' | sed -s 's/,$//g'`

echo "ip_new_vm=$ip_new_vm"
if [ "$ip_new_vm" == "" ];then
    echo "ip_new_vm is empty. exit"
    exit 1
fi

# clean the stored host for ip_new_vm
ssh-keygen -R $ip_new_vm

# 3. loop until the new VM is accessable 
CheckNewVM "$ip_new_vm"

# 4. Copy data to the new VM
CopyData "$ip_new_vm"

echo "$vm_name_new $ip_new_vm is ready to use"
