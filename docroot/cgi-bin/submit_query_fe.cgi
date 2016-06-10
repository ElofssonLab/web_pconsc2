#!/usr/bin/perl -w
#
# ChangeLog 2015-03-05 
#   1. the jobid is create by mktemp -d r_XXXXXX
#   2. do not submit the job to the computational node directly, but controled
#   by the qd_pconsc_fe.pl and in that case the queue order can be controlled
#   as well

use warnings;
use strict;
use CGI qw(:standard); 
use CGI qw(:cgi-lib); 
use CGI qw(:upload); 

use Digest::MD5 qw(md5 md5_hex md5_base64);
use Net::Domain qw(hostname hostfqdn hostdomain domainname);
use POSIX qw(strftime);


use Cwd 'abs_path'; 
use Time::Local;
use File::Basename;
my $rundir = dirname(abs_path(__FILE__));
my $progname = basename(__FILE__);

my $dnsdomainname = `dnsdomainname`;
chomp($dnsdomainname);

my $basedir = "$rundir/../";
my $md5dir = "$basedir/md5";
my $myemail="nanjiang.shu\@scilifelab.se";
my $resultdir= "$basedir/result/";
my $from_email = "info\@c2.pcons.net";

my $logfile = "$basedir/log/$progname.log";
my $date = "";

my $projectname = "";
if ($rundir =~ /debug/){
    $projectname = "debug.pconsc";
}else{
    $projectname = "pconsc";
}

my $hostname_of_the_computer = hostname();
my $date = strftime "%Y-%m-%d %H:%M:%S", localtime;

print header();
print start_html(-title => "PconsC Submission Script",
    -author => "nanjiang.shu\@scilifelab.se",
    -meta   => {'keywords'=>''});

if(!param())
{
    print 'Give me something to work on instead...';
    print end_html();
}

if (param())
{
    my $seq=param('seq');
    $seq=~s/\n//g;
    $seq=~s/\s+//g;
    my $name=param('name');
    my $email=param('email');
    my $host=param('host');
    my $httphost=param('httphost'); #http_host of this server e.g. c2.pcons.net


    my $isCASPtarget = 0;
    if  ($email=~/predictioncenter\.org/ || $name=~/CASP/){
        $isCASPtarget = 1;
    }

    if(length($seq)<10)
    {
        print 'Error: Sequence shorter than 10!';
        exit; 
    }
    if(length($seq)>1000)
    {
        print 'Error: Sequence longer than 1000!';
        exit; 
    }
    #check if sequence was submitted before
    my $digest = md5_hex($seq);
    my $subfolder = substr $digest, 0, 2;
    my $submd5dir = "$md5dir/$subfolder";
#     print "$digest";  #debug nanjiang
    my $isNew = 0;
    my $folder = "";
    if(-e "$submd5dir/$digest")
    {
        #mail notification to user.
        #print $digest;
        $folder = basename(readlink("$submd5dir/$digest"));

        if(! $isCASPtarget && $email ne "")
        { # do not send this informatoin to predictioncenter
            open(MAIL,"|/usr/sbin/sendmail -t");
            print MAIL "From: $from_email\n";
            print MAIL "To: $email\n";
            print MAIL "Subject: PconsC2 web server [ $name ]\n";
            print MAIL "Dear user,\n\n";
            print MAIL "Your sequence [ $name ] was already submitted. Please follow the link below\n";
            print MAIL "to view the results:\n";
            print MAIL "http://$httphost/index.php?id=$folder\n\n";
            print MAIL "Sequence:\n";
            print MAIL "$seq\n\n";
            print MAIL "Thanks for using the PconsC2 web server\n";
            close(MAIL);
        }

        if ($isCASPtarget){
            #send sequence to micro
        }

        `touch $resultdir/$folder`;
        $folder="-$folder";
        $isNew = 0;
    }
    else
    {
        # create a new job id
        if (defined(param('id'))){ #the outfolder is either specified by the argument or find the first free folder number
            $folder = param('id');
        }else{
            $folder = `mktemp -d $resultdir/r_XXXXXX`;
            chomp($folder);
            $folder = basename($folder);
        }
        my $outfolder = "$resultdir/$folder";
        if (! -d $outfolder){
            mkdir($outfolder, 0755);
        }else{
            chmod  0755, $outfolder;
        }
        # create the link
        if (! -d $submd5dir){
            mkdir($submd5dir, 0755);
        }else{
            chmod 0755, $submd5dir;
        }
        chdir($submd5dir);
        if (-l $digest){ # delete the broken symbolic link
            `rm -f $digest`;
        }
        $date = strftime "%Y-%m-%d %H:%M:%S", localtime;
        `echo "[$date] ln -s ../../result/$folder $digest" >> $logfile`;
        `ln -s ../../result/$folder $digest`;
        chdir($resultdir);

        open(OUT,">$outfolder/sequence");
        print OUT $seq;
        close(OUT);

        open(OUT,">$outfolder/name");
        print OUT $name;
        close(OUT);

        open(OUT,">$outfolder/email");
        print OUT $email;
        close(OUT);

        open(OUT,">$outfolder/host");
        print OUT $host;
        close(OUT);

        my $jobname="pconsc$folder";
        open(OUT,">$outfolder/jobname");
        print OUT $jobname;
        close(OUT);

        open(OUT, ">$outfolder/sequence.fasta");
        print OUT  ">$name\n";
        print OUT  "$seq\n";
        close(OUT);

        $date = strftime "%Y-%m-%d %H:%M:%S", localtime; 
        `echo $date > $outfolder/date`;
        $isNew = 1;
    }

    print end_html();

    my $folder_nr = $folder;
    $folder_nr =~ s/-//g;
    if($isNew){
        print "new job ID = $folder_nr";
    }else{
        print "job ID = $folder_nr";
    }
    $date = strftime "%Y-%m-%d %H:%M:%S", localtime;
    `echo $date > $resultdir/last_submission`;
    # Do not run the front end daemon on the computational node
    if ($dnsdomainname !~ /smog/ && $dnsdomainname !~ /egi/ && $dnsdomainname !~ /pdc/){
        system("$rundir/qd_pconsc_fe.pl"); #run the daemon at the front end to retrieve data
    }
}
