#!/bin/bash

rundir=`dirname $0`
cd $rundir
backupfile.sh *.py *.pl *.cgi *.sh
