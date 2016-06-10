#!/usr/bin/perl -w
# Filename:   restart_qd_pconsc_fe.cgi
# Description: restart qd_pconsc_fe.pl
use CGI qw(:standard);
use CGI qw(:cgi-lib);
use CGI qw(:upload);

use Cwd 'abs_path';
use File::Basename;
my $rundir = dirname(abs_path(__FILE__));
my $progname = basename(__FILE__);
my $basedir = "$rundir/../";

my $projectname = "";
my $search_word = "";
if ($rundir =~ /debug/){
    $projectname = "debug.pconsc";
    $search_word = "debug";
}else{
    $projectname = "pconsc";
    $search_word = "release";
}
my $target_progname = "qd_pconsc_fe.pl";


print header();
print start_html(-title => "Restart $target_progname",
    -author => "nanjiang.shu\@scilifelab.se",
    -meta   => {'keywords'=>''});

if(!param())
{
    print "Already running daemons:<br>";
    my $username=`whoami`;
    my $already_running=`ps aux | grep  $target_progname | grep "$search_word" | grep -v grep | grep -v archive_logfile | grep $username`;
    my $num_already_running = `echo "$already_running" | grep $target_progname  | wc -l`;
    chomp($num_already_running);
    print "<pre>";
    print $already_running;
    print "</pre>";
    print "num_already_running=$num_already_running<br>";
    print '<br>';
    print '<br>';
    if ($num_already_running > 0){
        my $ps_info = `ps aux | grep "$target_progname" | grep "$search_word" | grep -v grep | grep -v archive_logfile | grep $username`;
        my @lines = split('\n', $ps_info);
        my @pidlist = ();
        foreach my $line  (@lines){
            chomp($line);
            my @fields = split(/\s+/, $line);
#             print "scalar \@fields =". scalar @fields . "<br>\$fields[1]=" . $fields[1]. "<br>line=".$line . "<br>"; #debug
            if (scalar @fields > 2 && $fields[1] =~ /[0-9]+/){
                push (@pidlist, $fields[1]);
            }
        }
#         print "scalar \@pidlist=".scalar @pidlist."<br>"; #debug
        print 'killing.... <br>';
        foreach my $pid (@pidlist){
            print "kill -9 $pid<br>";
            system("kill -9 $pid");
        }
        print '<BR>';
        print '<BR>';
    }
    print 'Starting up...<br>';
    my $logfile = "$basedir/log/$progname.log";
    system("$rundir/$target_progname >> $logfile 2>&1 &");
    $already_running=`ps aux | grep  $target_progname | grep "$search_word" | grep -v vim | grep -v grep | grep -v archive_logfile | grep $username`;
    print "updated running daemons:<br>";
    print "<pre>";
    print $already_running;
    print "</pre>";
    print '<br>';
    print '<br>';
    print "$target_progname restarted";
    print end_html();
}

