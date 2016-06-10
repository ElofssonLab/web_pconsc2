#!/usr/bin/perl -w
# This daemon will check the queue status and submit jobs that is not already
# submitted.
# ChangeLog  2014-11-21 
#   first need to check if the server is accessible then check if there is any
#   running jobs on the server. Otherwise, if the server is down, the script
#   will consider it as available and submit the sequence to the dead server
#   anyway. Fixed
# ChangeLog 2015-03-11
#   To check if a job is stopped on a VM, use
#        if($return_msg !~ /run_pconsc.*$jobID/){
#   instead of 
#        if($return_msg !~ /run_pconsc/){


use POSIX qw(setsid);
use POSIX qw(strftime);
use Net::Domain qw(hostname hostfqdn hostdomain domainname);
use LWP::Simple qw($ua head);
$ua->timeout(10);


use Cwd 'abs_path';
use File::Basename;
my $rundir = dirname(abs_path(__FILE__));
my $progname = basename(__FILE__);
my $basedir = "$rundir/../";
my $progname_15char = substr $progname, 0, 15;
my $hostname = hostname();
my $dnsdomainname = `dnsdomainname`;
chomp($dnsdomainname);

my $hostname_of_the_computer = $hostname;

my $projectname = "";
my $search_word = "";
if ($rundir =~ /debug/){
    $projectname = "debug.pconsc";
    $search_word = "debug";
}else{
    $projectname = "pconsc";
    $search_word = "release";
}

require "$rundir/nanjianglib.pl";

my $cnt_failed_to_connect = 0; # counter for the continuous failed connect to the VM

# 2014-07-01, using new method to distinguish daemon file in debug and release version 
my $already_running=`ps aux | grep "$progname" | grep "$search_word" |grep -v gvim |  grep -v grep | grep -v archive_logfile | wc -l`;
my $date="";
#print "already_running=$already_running\n";
chomp($already_running);
if($already_running>1)#{{{
{
    if($already_running==2) {
        print STDERR "There is one $progname already running. Exit ...\n";
        exit;
    } else {
        print STDERR "There are $already_running $progname running. Kill them all ...\n";
        my $ps_info = `ps aux | grep "$progname" | grep "$search_word" | grep -v grep | grep -v archive_logfile `;
        my @lines = split('\n', $ps_info);
        my @pidlist = ();
        foreach my $line  (@lines){
            chomp($line);
            my @fields = split(/\s+/, $line);
            if (scalar @fields > 2 && $fields[1] =~ /[0-9]+/){
                push (@pidlist, $fields[1]);
            }
        }
        print 'killing.... <br>';
        foreach my $pid (@pidlist){
            print "kill -9 $pid<br>";
            system("kill -9 $pid");
        }
    }
}#}}}

my $access_log="$basedir/log/$progname.log";
my $error_log="$basedir/log/$progname.err";


open STDIN,  '/dev/null' or die "Can't read /dev/null: $!";
open STDOUT, ">>$access_log" or die "Can't write to $access_log: $!";
open STDERR, ">>$error_log" or die "Can't write to $error_log: $!";

defined(my $pid = fork)   or die "Can't fork: $!";
exit if($pid);
$date = strftime "%Y-%m-%d %H:%M:%S", localtime; 
print "\n\n\n**********************\nStarting up queue... [$date]\n";
setsid  or die "Can't start a new session: $!";
print "Started on $date\n";

my $resultdir="$basedir/result/";
my $INTERVAL_LENGTH=30; #in seconds
my $count_loop = 0;
while(1) #repeat the process#{{{
{
    $date = strftime "%Y-%m-%d %H:%M:%S", localtime;
    if ($count_loop == 0){
        print "[$date]: $progname restarted...\n";
    }else{
        print "[$date]: $progname loop $count_loop begin...\n"
    }

    # archive logfiles if their size is over the limit
    `find $basedir/log/ -name "*.log" -print0 -o -name "*.err" -print0 | xargs -0 $rundir/archive_logfile.py -maxsize 20M`;

    my @job_folders=();
    opendir(DIR,"$resultdir");
    my @folders=readdir(DIR);
    closedir(DIR);

    foreach my $folder(@folders)
    {
        if(($folder=~/^\d+$/ || $folder=~/r_/ ) && 
            (-d "$resultdir/$folder" || -l "$resultdir/$folder"))
        {
            if(age("$resultdir/$folder") > 90 && -d "$resultdir/COMPRESSED_OLD") #Archive results older than 30 days. 
            {
                print "$resultdir/$folder older than 30 days skipping...\n";
                if(!-e "$resultdir/$folder/do_not_delete")
                {
                    `cd $resultdir;tar -czf COMPRESSED_OLD/$folder.tar.gz $folder/*; cd /`;
                    if(-e "$resultdir/COMPRESSED_OLD/$folder.tar.gz")
                    {
                        `rm -fr $resultdir/$folder`;
                    }
                }
            }
            push(@job_folders,$folder);
        }
    }

    foreach my $folder(@job_folders) #first in first out queue
    {
        my $jobdir = "$resultdir/$folder";
        if (! -e "$jobdir/pconsc.stop"){ #ignore stopped jobs
            my $isCASPtarget = 0;

            my $email = ReadContent_chomp("$jobdir/email");
            my $name = ReadContent_chomp("$jobdir/name");

            #if ($email=~/predictioncenter\.org/ || $name=~/\bT[0-9]{4}\b/)
            if ($email=~/predictioncenter\.org/) {
                $isCASPtarget = 1;
            }

            if (! -e "$jobdir/pconsc.start"){
                print "Try to submit $jobdir\n";
                submit_pconsc($jobdir);
            }
            if (-e "$jobdir/pconsc.start"){
                print "Try to get result for $jobdir\n";
                get_pconsc_result($jobdir);
            }
        }
    }
    sleep($INTERVAL_LENGTH);
    $count_loop ++;
}#}}}

sub submit_pconsc #{{{
{
    my $jobdir = shift;
    my $jobID = pcons_result_path_to_folder_nr($jobdir);
    my $serverlistfile = "";
    my $urlcgi = "";
    my $urlfile = "";
    if ($hostname =~ /pdc/){
        $serverlistfile = "$basedir/pdc.serverlist.txt";
    }elsif ($hostname =~ /egi/){
        $serverlistfile = "$basedir/egi.serverlist.txt";
    }else{
        if ($dnsdomainname =~ /smog/){
            $serverlistfile = "$basedir/smog.serverlist.txt";
        }else{
            print "Bad hostname $hostname\n";
            return 1;
        }
    }
    my @serverlist = ();
    open(my $fpin, "<", $serverlistfile);
    if ($fpin){
        foreach my $line (<$fpin>){
            chomp($line);
            if ($line !~ /^#/){
                push(@serverlist, $line);
            }
        }
    }else{
        print "Failed to read $serverlistfile\n";
        return 1;
    }
    close($fpin);

    my $isRun = 0;
    foreach my $server (@serverlist){
        my $cgibin_url = "";
        if ($rundir =~ /debug/){
            $cgibin_url = "http://$server/debug.pconsc/cgi-bin";
        }else{
            $cgibin_url = "http://$server/pconsc/cgi-bin";
        }
        $urlcgi = "$cgibin_url/check_running_pconsc.cgi";
        print "curl $urlcgi 2>&1\n";
        my $return_msg=`curl "$urlcgi" 2>&1 `;
        if ($return_msg =~ /couldn't connect/){
            print "server $server could not be connected\n"; # note, better to report by email to the user
        }elsif($return_msg !~ /run_pconsc/){
            print "server $server is vacant, try to submit the job $jobID to $server\n";
            my $seq = ReadContent_chomp("$jobdir/sequence");
            my $name = ReadContent_chomp("$jobdir/name");
            $urlcgi =  "$cgibin_url/run_pconsc.cgi";
            my $str = `curl $urlcgi -d seq="$seq" -d name="$name" -d id="$jobID" | html2text`;
            print "curl $urlcgi -d seq=\"$seq\" -d name=\"$name\" -d id=\"$jobID\""."\n";
            WriteFile($str, "$jobdir/run_pconsc.ref");
            WriteDateTagFile("$jobdir/pconsc.start");
            WriteFile($server, "$jobdir/server_submitted");
            $isRun = 1;
            return 0;
        }
    }
    if (! $isRun){
        print "All servers are busy. Please wait.\n";
        return 1;
    }else{
        return 0;
    }
}#}}}

sub get_pconsc_result#{{{
{
    my $jobdir = shift;
    my $jobID = pcons_result_path_to_folder_nr($jobdir);
    my $submitted_server = ReadContent_chomp("$jobdir/server_submitted");
    chomp($submitted_server);
    my $cgibin_url = "";
    my $urlcgi = "";
    my $urlfile = "";
    if (length($submitted_server) > 0){
        my $baseurl = "";
        if ($rundir =~ /debug/){
            $baseurl = "http://$submitted_server/debug.pconsc/tmp/$jobID";
            $cgibin_url = "http://$submitted_server/debug.pconsc/cgi-bin";
        }else{
            $baseurl = "http://$submitted_server/pconsc/tmp/$jobID";
            $cgibin_url = "http://$submitted_server/pconsc/cgi-bin";
        }


        $urlfile = "$baseurl/pconsc/log.txt";
        if(head($urlfile)){
            print "curl -s $urlfile\n";
            my $logdata = `curl -s $urlfile`;
            WriteFile($logdata, "$jobdir/run_log.txt");
        }else{
            print "$urlfile does not exist.\n"
        }

        $urlcgi = "$cgibin_url/check_running_pconsc.cgi";
        my $return_msg=`curl "$urlcgi" 2>&1 `;
        if ($return_msg =~ /couldn't connect/ || $return_msg =~ /not found/){
            print "Failed to connect to $urlcgi\n";
            $cnt_failed_to_connect ++;
        }else{
            $cnt_failed_to_connect = 0;
            if($return_msg !~ /run_pconsc.*$jobID/){
                # the job is stopped, try to fetch the result
                $urlfile = "$baseurl/run_pconsc.finished";
                if(head($urlfile)){
                    my $tagdata = `curl -s $urlfile`;
                    my $url_tarball = "$baseurl/pconsc.tar.gz";
                    my $tarball = "$jobdir/pconsc.tar.gz";
                    exec_cmd("wget -o $jobdir/wget.log -O $tarball \"$url_tarball\"");
                    if (-e $tarball && -s $tarball){
                        print "Got result!\n";
                        if (! -d "$jobdir/pconsc"){
                            `mkdir -p "$jobdir/pconsc"`;
                        }
                        `tar -xzf $tarball -C $jobdir/pconsc .`;

                        my $pngfile = "$jobdir/pconsc/sequence.fasta.pconsc2.out.cm.png";
                        if (-e $pngfile && -s $pngfile){
                            WriteDateTagFile("$jobdir/pconsc.success");
                            $urlcgi = "$cgibin_url/delete_pconsc_tmpdata.cgi";
                            my $return_msg = `curl $urlcgi -d id="$jobID"` ;
                            print "tmpdata of $jobID is deleted at $submitted_server\n";
                            print "return message: $return_msg\n";
                        }
                    }
                }else{
                    print "Job $jobID stopped on $submitted_server without success!\n";
                }
                WriteDateTagFile("$jobdir/pconsc.stop");
            }
        }


        # check if pconsc is running on the VM

        if ($cnt_failed_to_connect > 50){
            # if failed to connect to the VM more than N times, the VM is most
            # likely stopped
            print "Failed to connect to $submitted_server >= 50 times. ".
                "Consider stop the job $jobID\n";
            WriteDateTagFile("$jobdir/pconsc.stop");
        }
        return 0;
    }else{
        print "Error! $jobdir/server_submitted is empty\n";
        WriteDateTagFile("$jobdir/pconsc.stop"); #the job is stopped without success
        return 1;
    }
}#}}}

