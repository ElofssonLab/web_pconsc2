#!/bin/bash

# Filename:    clean_pconsc_result_folder.sh
# Description: clean the pconsc result folder so that only necessary files are
#              kept
# Author: Nanjiang Shu (nanjiang.shu@scilifelab.se)

usage="
Usage: $0 DIR [DIR ...] [-l LISTFILE] 
OPTIONS:
  -l       FILE     Set the file containing a list of DIRs
  -h, --help        Print this help message and exit

Created 2014-12-03, updated 2014-12-03, Nanjiang Shu 
"
PrintHelp(){ #{{{
    echo "$usage"
}
#}}}
CleanPconsCResultFolder(){ #{{{
    local dir=$1
    find $dir  -name "*.trimmed" -o -name "*.hhr" -o -name "*.psicov" -o -name "*.jones" -o -name "*.a3m" -o -name "*.plmdca" -o -name "*.ss2" -o -name "*.horiz" -o -name "*.ss" -o -name "*.rsa" -o -name "*.bak"  | tr '\n' '\0' | xargs -0 rm -f
    echo "pconsc folder $dir cleaned"
}
#}}}

if [ $# -lt 1 ]; then
    PrintHelp
    exit
fi

dirListFile=
dirList=()

isNonOptionArg=0
while [ "$1" != "" ]; do
    if [ $isNonOptionArg -eq 1 ]; then 
        dirList+=("$1")
        isNonOptionArg=0
    elif [ "$1" == "--" ]; then
        isNonOptionArg=true
    elif [ "${1:0:1}" == "-" ]; then
        case $1 in
            -h | --help) PrintHelp; exit;;
            -outpath|--outpath) outpath=$2;shift;;
            -o|--o) outfile=$2;shift;;
            -l|--l|-list|--list) dirListFile=$2;shift;;
            -q|-quiet|--quiet) isQuiet=1;;
            -*) echo Error! Wrong argument: $1 >&2; exit;;
        esac
    else
        dirList+=("$1")
    fi
    shift
done

if [ "$dirListFile" != ""  ]; then 
    if [ -s "$dirListFile" ]; then 
        while read line
        do
            dirList+=("$line")
        done < $dirListFile
    else
        echo listfile \'$dirListFile\' does not exist or empty. >&2
    fi
fi

numDir=${#dirList[@]}
if [ $numDir -eq 0  ]; then
    echo $0: Input not set! Exit. >&2
    exit 1
fi

for ((i=0;i<numDir;i++));do
    dir=${dirList[$i]}
    CleanPconsCResultFolder "$dir"
done

