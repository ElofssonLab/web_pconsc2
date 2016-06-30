#!/usr/bin/perl -w
# submit_query.cgi at the computenode
# ChangeLog 2015-03-05 
#   1. the jobid is create by mktemp -d r_XXXXXX
#   2. do not submit the job to the computational node directly, but controled
#   by the qd_pconsc_fe.pl and in that case the queue order can be controlled
#   as well

use CGI qw(:standard); 
use CGI qw(:cgi-lib); 
use CGI qw(:upload); 

use Digest::MD5 qw(md5 md5_hex md5_base64);
use Net::Domain qw(hostname hostfqdn hostdomain domainname);
use POSIX qw(strftime);


use Cwd 'abs_path'; 
use File::Basename;
my $rundir = dirname(abs_path(__FILE__));
my $basedir = "$rundir/../";
my $md5dir = "$basedir/md5";
my $myemail="nanjiang.shu\@scilifelab.se";
my $resultdir= "$basedir/result/";
my $from_email = "info\@c2.pcons.net";

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
    my $folder = param('id'); # at the computenode, the same job id is used as in the frontend


    $isCASPtarget = 0;
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

    my $outfolder = $resultdir.$folder;
    mkdir($outfolder, 0755);

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

    $jobname="pconsc$folder";
    open(OUT,">$outfolder/jobname");
    print OUT $jobname;
    close(OUT);

    open(OUT, ">$outfolder/sequence.fasta");
    print OUT  ">$name\n";
    print OUT  "$seq\n";
    close(OUT);

    $date = strftime "%Y-%m-%d %H:%M:%S", localtime; 
    `echo $date > $outfolder/date`;
    print end_html();

    my $folder_nr = $folder;
    $folder_nr =~ s/-//g;
    print "new job ID = $folder_nr";
    $date = strftime "%Y-%m-%d %H:%M:%S", localtime;
    `echo $date > $resultdir/last_submission`;
}
