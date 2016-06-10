#!/usr/bin/perl -w
# Filename: update_queue_file.pl
# Description: update job list to queue.html
# Created 2014-04-30, updated 2014-04-30, Nanjiang Shu

use POSIX qw(setsid);

use Cwd 'abs_path';
use File::Basename;
my $rundir = dirname(abs_path(__FILE__));
my $progname = basename(__FILE__);
my $basedir = "$rundir/../";
my $cgibin = "$basedir/cgi-bin";

require "$rundir/nanjianglib.pl";


$date=localtime();

my $resultdir="$basedir/result/";
my $queuefile="$resultdir/queue.html";

my $minutes=0;
my %queue=();

my $tmpstr = `$cgibin/calculate_queue.py --resultdir $resultdir`;
my @lines = split /\n/, $tmpstr;
my $numJobs = scalar @lines - 1;

# status: Queued, Running, Finished, Failed, Rerun
my %queue_info = ();
my %jobdate = ();
my $cnt_queue = 0;
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
    my $queuerank = $tokens[2];
    my $user = $tokens[3];
    my $jobdir = "$resultdir/$jobID";

    $queue_info{$jobID}{name}="";
    if ($status eq "Queued"){
        $queue_info{$jobID}{queuerank}=$queuerank;
        $cnt_queue ++;
    }else{
        $queue_info{$jobID}{queuerank}="";
    }
    $queue_info{$jobID}{name_20char}="";
    $queue_info{$jobID}{status}=$status;
    $queue_info{$jobID}{time_start}="";
    $queue_info{$jobID}{time_end}="";
    $queue_info{$jobID}{email}="";
    $queue_info{$jobID}{host}="";
    $queue_info{$jobID}{date}="";
    $jobdate{$jobID} = "";


    my $datestr = ReadContent_chomp("$jobdir/date");
    $jobdate{$jobID} = date_str_to_epoch($datestr);
    my ($str1, $str2) = split(/[\s.]/, $datestr);
    $queue_info{$jobID}{date}=$str1;
    $queue_info{$jobID}{email}=$user;

    if (-e "$jobdir/pconsc.start"){
        $queue_info{$jobID}{time_start}= ReadContent_chomp("$jobdir/pconsc.start");
    }
    if (-e "$jobdir/pconsc.stop"){
        $queue_info{$jobID}{time_end}= ReadContent_chomp("$jobdir/pconsc.stop");
    }


    $queue_info{$jobID}{name}=ReadContent_chomp("$jobdir/name");
    $queue_info{$jobID}{name}=~s/NONAME//g;

    $queue_info{$jobID}{name_20char} = substr($queue_info{$jobID}{name}, 0, 20);

    $queue_info{$jobID}{sequence}=ReadContent_chomp("$jobdir/sequence");
    $queue_info{$jobID}{len}=length($queue_info{$jobID}{sequence});
}

my $color_failed="red";
my $color_queued="black";
my $color_running="blue";
my $color_rerun="orange";
my $color_finished ="green";
$date=localtime();
# print "[$date] Updating $queuefile\n"; #debug
my $tmp_queuefile =  "$queuefile.$$";
open(QUEUE,">$tmp_queuefile");
print QUEUE "<table class=\"sortable\" cellpadding=3 >";
print QUEUE "<TR align=\"left\">";
print QUEUE "<TH NOWRAP>No.</TH>";
print QUEUE "<TH NOWRAP>ID</TH>";
print QUEUE "<TH NOWRAP><font color=green>Date</font></TH>";
print QUEUE "<TH NOWRAP>Status</TH>";
if($cnt_queue > 0){
    print QUEUE "<TH NOWRAP>QueueRank</TH>";
}
print QUEUE "<TH NOWRAP>Len</TH>";
print QUEUE "<TH NOWRAP>Name</TH>";
print QUEUE "<TH NOWRAP>User</TH>";
print QUEUE "<TH NOWRAP>Start</TH>";
print QUEUE "<TH NOWRAP>End</TH>";
print QUEUE "</TR>\n";
my $space="&nbsp;";

my $cnt = 1;
# list jobs in descending order by the submit date
foreach my $jobID(sort { $jobdate{$b} <=> $jobdate{$a} } keys %jobdate)
{
    my $folder_link="$jobID";
    my $colorstatus = "black";
    if  ($queue_info{$jobID}{status} eq "Queued"){
        $colorstatus = $color_queued;
    }elsif($queue_info{$jobID}{status} eq "Running"){
        $colorstatus = $color_running;
    }elsif($queue_info{$jobID}{status} eq "Finished"){
        $colorstatus = $color_finished;
    }elsif($queue_info{$jobID}{status} eq "Rerun"){
        $colorstatus = $color_rerun;
    }elsif($queue_info{$jobID}{status} eq "Failed"){
        $colorstatus = $color_failed;
    }
    print QUEUE "<TR>";
    print QUEUE "<TD NOWRAP><a rel=\"nofollow\" href=index.php?id=$folder_link><font color=black>$cnt</font></a></TD>"; # No
    print QUEUE "<TD NOWRAP><input type=hidden name=id value=:ID$folder:><a rel=\"nofollow\" href=index.php?id=$folder_link>$jobID</a></TD>"; # ID

    print QUEUE "<TD NOWRAP><a rel=\"nofollow\" href=index.php?id=$folder_link><font color=black>$queue_info{$jobID}{date}</font></a></TD>"; #Date

    print QUEUE "<TD ALIGN=CENTER NOWRAP><a rel=\"nofollow\" href=index.php?id=$folder_link><FONT COLOR=$colorstatus>$queue_info{$jobID}{status}</font></a></TD>"; #status
    if($cnt_queue>0){
        print QUEUE "<td nowrap><a rel=\"nofollow\" href=index.php?id=$folder_link><FONT COLOR=black>$queue_info{$jobID}{queuerank}</font></a></TD>"; #QueueRank
    }

    print QUEUE "<TD ALIGN=left NOWRAP><a rel=\"nofollow\" href=index.php?id=$folder_link><FONT COLOR=BLACK>$queue_info{$jobID}{len}</font></a></TD>"; #len

    print QUEUE "<td align=left nowrap><a rel=\"nofollow\" href=index.php?id=$folder_link><FONT COLOR=BLACK>$queue_info{$jobID}{name_20char}</font></a></TD>"; #name

    print QUEUE "<TD ALIGN=left NOWRAP><a rel=\"nofollow\" href=index.php?id=$folder_link><FONT COLOR=BLACK>$queue_info{$jobID}{email}</font></a></TD>"; #user


    print QUEUE "<TD align=left><a rel=\"nofollow\" href=index.php?id=$folder_link><FONT COLOR=BLACK>$queue_info{$jobID}{time_start}</font></a></TD>";
    print QUEUE "<TD align=left><a rel=\"nofollow\" href=index.php?id=$folder_link><FONT COLOR=BLACK>$queue_info{$jobID}{time_end}</font></a></TD>";
    print QUEUE "</TR>\n";
    $cnt ++;
}
print QUEUE "</table>\n";
close(QUEUE);
`/bin/cp -f $tmp_queuefile $queuefile`;
`rm -f $tmp_queuefile`;
