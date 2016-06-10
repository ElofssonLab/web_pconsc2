#!/bin/bash
# note that realpath should be installed
# Description: run the script run_pconsc.py
# Created 2014-06-23, updated 2014-06-27, Nanjiang Shu

# ChangeLog 2014-06-30 
#   1. dblist is read from dblistfile.txt
#   2. set n_psicov_jobs and n_plmdca_jobs
# ChangeLog 2014-07-01
#   1. write the tag file "$outdir/run_pconsc.finished" at the end after the
#   script is finished. This will avoid copying pconsc.tar.gz in the middle of
#   tar program
# ChangeLog 2015-11-13
#   using  msg=`dmesg |grep -i hypervisor` to detect if the machine is VM or
#   not is not reliable. just test if the script file exists
rundir=`dirname $0`
basedir=$rundir/../

hostname=`hostname`
#msg=`dmesg |grep -i hypervisor`


if [ -f /home/ubuntu/pconsc2/PconsC2/run_pconsc2_nj1.py ];then
    export PCONSC=/home/ubuntu/pconsc2/
    isVM=1
elif [ -f /data3/share/pconsc2/PconsC2/run_pconsc2_nj1.py  ]; then
    export PCONSC=/data3/share/pconsc2
    isVM=0
else
    echo "PconsC2 folder does not exist." >&2
    exit 1
fi
export DATADIR=/data

hhdb=$DATADIR/hhsuite/uniprot20_2015_06/uniprot20_2015_06
hmmerdb=$DATADIR/blastdb/uniref90.fasta
#hmmerdb=$DATADIR/blastdb/swissprot
numCPU=`cat /proc/cpuinfo | grep processor | wc -l `


path_pconsc2=$PCONSC/PconsC2/
export PATH=$path_pconsc2/dependencies/bin:$PATH

export BLASTDB=$DATADIR/blastdb
export BLASTBIN=$PCONSC/share/blast/blast-2.2.26/bin
export BLASTMAT=$PCONSC/share/blast/blast-2.2.26/data


exec_cmd()(
    echo "$*"
    eval "$*"
)

usage="
USAGE: $0 FASTASEQFILE OUTDIR

result will be output to \$OUTDIR/pconsc/ and \$OUTDIR/pconsc.tar.gz 

Examples:
    $0  data/tmp/r_11/myseq.fa data/tmp/r_11/
"

if [ "$#" -lt 2 ];then
    echo "$usage"
    exit
fi

infile=$1
outdir=$2
infile=`realpath $infile`
outdir=`realpath $outdir`
resultdir=$outdir/pconsc

if [ ! -d $resultdir ];then
    mkdir -p $resultdir
fi
n_psicov_jobs=2  #number of psicov jobs
n_plmdca_jobs=1  #number of plmdca jobs

# echo "run $infile $outdir"

currdir=$PWD
/bin/cp -f $infile $resultdir/sequence.fasta
inputseqfile=$resultdir/sequence.fasta


date=`/bin/date '+%F %H:%M:%S'`
echo "start at $date"
cd $resultdir
echo
echo "#------------------------------------------------"
echo "Running PconsC2..."
res1=$(/bin/date +%s.%N)
exec_cmd "$path_pconsc2/run_pconsc2_nj1.py -c $numCPU --p_psi $n_psicov_jobs --p_plm $n_plmdca_jobs $hhdb $hmmerdb $inputseqfile"
res2=$(/bin/date +%s.%N)
printf "Running time for PconsC2 is %.0F seconds" $(echo "$res2 - $res1"|/usr/bin/bc)

echo
echo "#------------------------------------------------"
echo "Running PconsC1..."
res1=$(/bin/date +%s.%N)
exec_cmd "$path_pconsc2/run_pconsc2_nj1.py -c $numCPU --p_psi $n_psicov_jobs --p_plm $n_plmdca_jobs --pconsc1 $hhdb $hmmerdb $inputseqfile"
res2=$(/bin/date +%s.%N)
printf "Running time for PconsC1 is %.0F seconds" $(echo "$res2 - $res1"|/usr/bin/bc)

date=`/bin/date '+%F %H:%M:%S'`
echo
echo "End at $date"

cd $currdir

# make tarball after finishing
if [ -f $outdir/pconsc.tar.gz ];then
    rm -f $outdir/pconsc.tar.gz
fi
exec_cmd "tar -czf $outdir/pconsc.tar.gz -C $resultdir ./"
date=`/bin/date '+%F %H:%M:%S'`
echo $date > $outdir/run_pconsc.finished
