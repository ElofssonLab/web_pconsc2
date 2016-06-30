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

my $target_progname = "qd_pconsc_fe.pl";

my $auth_ip_file = "$basedir/auth_iplist.txt";#ip address which allows to run cgi script

print header();
print start_html(-title => "Restart $target_progname",
    -author => "nanjiang.shu\@scilifelab.se",
    -meta   => {'keywords'=>''});

if(!param())
{
    my $remote_host = $ENV{'REMOTE_ADDR'};
    my @auth_iplist = ();
    open(IN, "<", $auth_ip_file) or die;
    while(<IN>) {
        chomp;
        push @auth_iplist, $_;
    }
    close IN;

    if (grep { $_ eq $remote_host } @auth_iplist) {
        print "Already running daemons:<br>";
        my $username=`whoami`;
        my $already_running=`ps aux | grep  $target_progname | grep -v grep | grep -v archive_logfile | grep $username`;
        my $num_already_running = `echo "$already_running" | grep $target_progname  | wc -l`;
        chomp($num_already_running);
        print "<pre>";
        print $already_running;
        print "</pre>";
        print "num_already_running=$num_already_running<br>";
        print '<br>';
        print '<br>';
        if ($num_already_running > 0){
            my $ps_info = `ps aux | grep "$target_progname" | grep -v grep | grep -v archive_logfile | grep $username`;
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
        $already_running=`ps aux | grep  $target_progname | grep  -v vim | grep -v grep | grep -v archive_logfile | grep $username`;
        print "updated running daemons:<br>";
        print "<pre>";
        print $already_running;
        print "</pre>";
        print '<br>';
        print '<br>';
        print "$target_progname restarted";
    }else{
        print "Permission denied!\n";
    }
    print end_html();
}
