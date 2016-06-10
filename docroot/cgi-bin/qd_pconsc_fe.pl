#!/usr/bin/perl -w
# Filename: qd_fe_pconsc.pl 
# Description: This daemon runs at the frontend and try to retrieve data from the compute
# node periodically
# Created 2014-06-26, updated 2014-07-01, Nanjiang Shu 

# ChangeLog  2014-07-02
#   output CASP11_RR_pconsc2.txt if it is a casp target
# ChangeLog 2015-03-09
#   Change the design,
#   while (1){
#       generate_queue()
#       if (num_in_queue > 0){ 
#           @avail_node = get_avail_resource()
#           if (scalar @avail_node) > 0){
#               queue_folder_list = ReadQeueTable()
#               num = min(num_in_queue, num_avail_node)
#               for (i=0;i<num;i++){
#                   folder = queue_folder_list[$i]
#                   server = avail_node[$i]
#                   submit_job(folder, server)
#               }
#           }
#       }
#       sleep(interval)
#   }

use POSIX qw(setsid);
use POSIX qw(strftime);
use List::Util qw( sum );
use Net::Domain qw(hostname hostfqdn hostdomain domainname);


use LWP::Simple qw($ua head);
$ua->timeout(10);


use Cwd 'abs_path';
use File::Basename;
use File::Copy;
my $rundir = dirname(abs_path(__FILE__));
my $progname = basename(__FILE__);
my $basedir = "$rundir/../";
my $cgibin = "$basedir/cgi-bin";
my $progname_15char = substr $progname, 0, 15;

my $from_email = "info\@c2.pcons.net";

my $hostname_of_the_computer = hostname();
my $resultdir="$basedir/result/";
my $INTERVAL_LENGTH=60; # in seconds #the interval on the front-end should be
                        # longer than on the master node

my $projectname = "";
my $search_word = "";
if ($rundir =~ /debug/){
    $projectname = "debug.pconsc";
    $search_word = "debug";
}else{
    $projectname = "pconsc";
    $search_word = "release";
}
my $tmpstr = "";


require "$rundir/nanjianglib.pl";
# 2014-07-01, using new method to distinguish daemon file in debug and release version 
my $already_running=`ps aux | grep $progname | grep $search_word | grep -v vim | grep -v gvim | grep -v grep | grep -v archive_logfile | wc -l`;
my $date="";


my $httphost = "c2.pcons.net"; #this is not used actually in this script
my $httphostfile = "$basedir/log/httphost.txt";
if (-e $httphostfile){
    $httphost = ReadContent_chomp($httphostfile);
}

# print "already_running=$already_running\n";
chomp($already_running);
if($already_running>1)
{
    if($already_running==2) {
        print STDERR "There is one $progname already running. Exit ...\n";
        exit;
    } else {
        print STDERR "There are $already_running $progname running. Kill them all ...\n";
        my $ps_info = `ps aux | grep $progname | grep $search_word | grep -v vim | grep -v grep | grep -v archive_logfile `;
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
}

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

sub get_pconsc_result{#{{{
    my $jobID = shift;
    my $computenode = shift;
    my $jobdir = "$resultdir/$jobID";
    my $cgibin_url = "http://$computenode/$projectname/cgi-bin";
    my $urlcgi = "";
    my $urlfile = "";
    if($computenode eq ""){
        print "Error! computenode is empty\n";
        WriteDateTagFile("$jobdir/pconsc.stop");
        return 1;
    }
    my $ref_file = "$jobdir/cloud_node.ref";
    my $cloud_jobid = "";
    if(-e $ref_file && -s $ref_file){
        $cloud_jobid = `cat $ref_file | awk '/job/{print \$NF}'`;
        chomp($cloud_jobid);
    }else{
        print "Error ref_file = \"$ref_file\" does not exist"."\n";
        WriteDateTagFile("$jobdir/pconsc.stop");
        return 1;
    }
    if (length($computenode) > 0 &&
        ($cloud_jobid =~ /^\d+$/ || $cloud_jobid=~/r_/)){
        my $baseurl = "http://$computenode/$projectname/result/$cloud_jobid";
        my $rawdata = "";
        my $url_file = "";

        $url_file = "$baseurl/run_log.txt";
        if (head($url_file)) {
            print "curl -s $url_file\n";
            $rawdata = `curl -s $url_file`;
            WriteFile($rawdata, "$jobdir/run_log.txt");
        }

        if (!(-e "$jobdir/server_submitted" && -s "$jobdir/server_submitted")){
            $url_file = "$baseurl/server_submitted";
            if (head($url_file)){
                print "curl -s $url_file\n";
                $rawdata = `curl -s $url_file`;
                WriteFile($rawdata, "$jobdir/server_submitted");
            }
        }
        if (!(-e "$jobdir/pconsc.stop" )){
            $url_file = "$baseurl/pconsc.stop";
            if(head($url_file)){ # if the job is stopped on the remote server
                print "curl -s $url_file\n";
                $rawdata = `curl -s $url_file`;
                WriteFile($rawdata, "$jobdir/pconsc.stop");

                # trying to fetch the tarball only when the job is stopped on
                # the remote server
                my $url_tarball = "$baseurl/pconsc.tar.gz";
                my $tarball = "$jobdir/pconsc.tar.gz";
                exec_cmd("wget -o $jobdir/wget.log -O $tarball \"$url_tarball\"");
                if (-e $tarball && -s $tarball){
                    print "Got result!\n";
                    my $name = ReadContent_chomp("$jobdir/name");
                    my $email= ReadContent_chomp("$jobdir/email");
                    my $seq  = ReadContent_chomp("$jobdir/sequence");
                    my $isCASPtarget = 0;
                    if ($email=~/predictioncenter\.org/ && $name =~ /^T/){
                        $isCASPtarget = 1;
                    }
                    if (! -d "$jobdir/pconsc"){
                        mkdir("$jobdir/pconsc", 0755);
                    }
                    `tar -xzf $tarball -C $jobdir/pconsc .`;
                    WriteDateTagFile("$jobdir/pconsc.stop");

                    my $pngfile = "$jobdir/pconsc/sequence.fasta.pconsc2.out.cm.png";
                    if (-e $pngfile && -s $pngfile){
                        WriteDateTagFile("$jobdir/pconsc.success");
                        #after success, send email notification and delete the temporary data
                        # 1. send email notification
                        if(! $isCASPtarget && $email ne "")
                        { # do not send this informatoin to predictioncenter
                            open(MAIL,"|/usr/sbin/sendmail -t");
                            print MAIL "From: $from_email\n";
                            print MAIL "To: $email\n";
                            print MAIL "Subject: PconsC2 web server [ $name ]\n";
                            print MAIL "Dear user,\n\n";
                            print MAIL "Your job [ $name ] is finished. Please follow the link below\n";
                            print MAIL "to view the results:\n";
                            print MAIL "http://$httphost/index.php?id=$jobID\n\n";
                            print MAIL "The sequence of your job is:\n";
                            print MAIL "$seq\n\n";
                            print MAIL "Thanks for using the PconsC2 web server\n";
                            close(MAIL);
                        }

                        # 2. delete the result on the cloud node
                        $urlcgi = "$cgibin_url/delete_pconsc_result_on_cloud.cgi";
                        my $return_msg = `curl $urlcgi -d id="$cloud_jobid" | html2text` ;
                        print "result of $jobID is deleted on $computenode ($cloud_jobid)\n";
                        print "return message: $return_msg\n";
                    }


                    # in case of CASP target, produce casp format result
                    my $resultfile_pconsc2 = "$jobdir/pconsc/sequence.fasta.pconsc2.out";
                    my $fastafile = "$jobdir/sequence.fasta";
                    my $casp_outfile = "$jobdir/CASP11_RR_pconsc2.txt";
                    if ($isCASPtarget && -e $resultfile_pconsc2 && -s $resultfile_pconsc2){
                        exec_cmd("$rundir/reformat_casp.py $fastafile
                            $resultfile_pconsc2 $name $casp_outfile");
                    }
                }elsif(-s $tarball == 0){
                    unlink($tarball);
                }
            }
        }
        return 0;
    }else{
        print "Error! computenode=\"$computenode\" cloud_jobid=\"$cloud_jobid\""."\n";
        WriteDateTagFile("$jobdir/pconsc.stop");
        return 1;
    }
}#}}}
sub SubmitJob{#{{{
    my $jobID = shift;
    my $computenode = shift;
    my $jobdir = "$resultdir/$jobID";
    my $email = ReadContent_chomp("$jobdir/email");
    my $name = ReadContent_chomp("$jobdir/name");
    my $seq = ReadContent_chomp("$jobdir/sequence");
    my $host = ReadContent_chomp("$jobdir/host");
    my $url_to_post = "http://$computenode/$projectname/cgi-bin/submit_query.cgi";
    my $str = `curl $url_to_post -d email=$email -d id=$jobID -d seq=$seq -d host=$host -d httphost=$httphost -d name="$name" |html2text`;
    WriteFile($str, "$jobdir/cloud_node.ref");
    WriteDateTagFile("$jobdir/pconsc.start");
    WriteFile($computenode, "$jobdir/computenode");
}#}}}

print "Started on $date\n";
my $count_loop = 0;
while(1) #repeat the process#{{{
{
    my $urlcgi = "";
    my $urlfile = "";
    $date = strftime "%Y-%m-%d %H:%M:%S", localtime;
    if ($count_loop == 0){
        print "[$date]: $progname restarted...\n";
    }else{
        print "[$date]: $progname loop $count_loop begin...\n"
    }

    # archive logfiles if their size is over the limit
    `find $basedir/log/ -name "*.log" -print0 -o -name "*.err" -print0 | xargs -0 $rundir/archive_logfile.py -maxsize 20M`;


    print "[$date] $rundir/update_queue_file.pl\n";
    `$rundir/update_queue_file.pl`;

    my @job_folders=();
    opendir(DIR,"$resultdir");
    my @folders=readdir(DIR);
    closedir(DIR);

    # get jobID list
    foreach my $jobID(@folders) {#{{{
        if(($jobID=~/^\d+$/ || $jobID=~/r_/ ) && 
            (-d "$resultdir/$jobID" || -l "$resultdir/$jobID"))
        {
            if(age("$resultdir/$jobID") > 30 && -d "$resultdir/COMPRESSED_OLD") #Archive results older than 30 days. 
            {
                print "$resultdir/$jobID older than 30 days skipping...\n";
                if(!-e "$resultdir/$jobID/do_not_delete")
                {
                    `cd $resultdir;tar -czf COMPRESSED_OLD/$jobID.tar.gz $jobID/*; cd /`;
                    if(-e "$resultdir/COMPRESSED_OLD/$jobID.tar.gz")
                    {
                        `rm -fr $resultdir/$jobID`;
                    }
                }
            }
            push(@job_folders,$jobID);
        }
    }#}}}

    # calculate the queue
    $tmpstr = `$cgibin/calculate_queue.py --resultdir $resultdir`;
    my @lines = split /\n/, $tmpstr;
    my $numJobs = scalar @lines - 1;
    if ($numJobs < 1){
        print "No jobs in the resultdir. Ignore.\n";
        sleep($INTERVAL_LENGTH);
        $count_loop ++;
        next;
    }
    # count number the jobs in status list ["Queued", "Running", "Rerun"]
    my $cnt_queue = 0;
    my $cnt_run = 0;
    foreach my $line(@lines)
    {
        my $firstchar = substr $line, 0, 1;
        if ($firstchar eq "#"){
            next;
        }

        my @tokens = split /\s+/, $line;
        if (scalar @tokens < 8){
            next;
        }
        my $status = $tokens[1];
        if ($status eq "Queued"){
            $cnt_queue ++;
        } elsif($status eq "Running" || $status eq "Rerun" ){
            $cnt_run ++;
        }
    }

    if ($cnt_run < 1 && $cnt_queue < 1){
        print "No queued or running jobs. Ignore!\n";
        sleep($INTERVAL_LENGTH);
        $count_loop ++;
        next;
    }
    print "cnt_run=$cnt_run\n"; #debug
    print "cnt_queue=$cnt_queue\n";#debug

    # get number of available computer nodes
    my @availnodelist = ();
    my $sum_avail_node  = 0;
    if ($cnt_queue > 0){
        $tmpstr = ReadContent_chomp("$basedir/computenode.txt");
        my @computenodelist = split /\s+/,$tmpstr;
        foreach my $computenode (@computenodelist){
            my $cgibin_url = "";
            if ($rundir =~ /debug/){
                $cgibin_url = "http://$computenode/debug.pconsc/cgi-bin";
            }else{
                $cgibin_url = "http://$computenode/pconsc/cgi-bin";
            }
            $urlcgi = "$cgibin_url/get_avail_resource.cgi";
            print "curl $urlcgi 2>&1 | html2text | grep num_avail_node\n";
            my $return_msg=`curl "$urlcgi" 2>&1 | html2text | grep num_avail_node`;
            if ($return_msg =~/num_avail_node/){
                chomp($return_msg);
                my @fields = split(/\s+/, $return_msg);
                my $num_avail_node = $fields[1];
                for (my $i=0; $i < $num_avail_node; $i++){
                    push (@availnodelist, $computenode);
                }
            }
        }
        $sum_avail_node = scalar @availnodelist;
    }
    print "sum_avail_node=$sum_avail_node\n"; #debug

    # submit the queued jobs or checking result for running jobs
    my $cnt_submitted_queue = 0;
    foreach my $line(@lines)
    {
        my $firstchar = substr $line, 0, 1;
        if ($firstchar eq "#"){
            next;
        }

        my @tokens = split /\s+/, $line;
        if (scalar @tokens < 8){
            next;
        }
        my $jobID = $tokens[0];
        my $status = $tokens[1];
        my $jobdir = "$resultdir/$jobID";

        if ($status eq "Queued" && $cnt_submitted_queue < $sum_avail_node){
            my $computenode = $availnodelist[$cnt_submitted_queue];
            print "Submit job $jobID to $computenode\n";
            SubmitJob($jobID, $computenode);
            $cnt_submitted_queue ++;
        }elsif($status eq "Running" || $status eq "Rerun"){
            my $computenode = ReadContent_chomp("$jobdir/computenode");
            chomp($computenode);
            print "Try to get result for $jobID from $computenode\n";
            get_pconsc_result($jobID, $computenode);
        }
    }
    sleep($INTERVAL_LENGTH);
    $count_loop ++;
}#}}}

