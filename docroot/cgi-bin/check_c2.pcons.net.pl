#!/usr/bin/perl -w
# Filename:  check_c2.pcons.net.pl

# Description: check whether c2.pcons.net is accessable and also check the status
#              of the qd_pconsc.pl and qd_pconsc_fe.pl

# Created 2014-07-01, updated 2014-07-01, Nanjiang Shu

use File::Temp;

use Cwd 'abs_path';
use File::Basename;

use LWP::Simple qw($ua head);
$ua->timeout(10);

my $rundir = dirname(abs_path(__FILE__));
my $basedir = "$rundir/../";
require "$rundir/nanjianglib.pl";

my @to_email_list = (
    "nanjiang.shu\@gmail.com");

my $date = localtime();
print "Date: $date\n";
my $url = "http://c2.pcons.net";
my $from_email = "nanjiang.shu\@scilifelab.se";

# first: check if http://pcons.net is accessable
my $output = `lynx $url -dump 2>&1`;
if ($output !~ /Protein Residue-Residue Contact Prediction/){
    my $subject = "c2.pcons.net un-accessible";
    foreach my $to_email(@to_email_list) {
        sendmail($to_email, $from_email, $subject, $output);
    }
}

# second: check if qd_pconsc_fe.pl running at pcons1.scilifelab.se frontend
my $num_running=`curl http://c2.pcons.net/cgi-bin/check_qd_pconsc_fe.cgi 2> /dev/null | html2text | grep qd_pconsc_fe | wc -l`;
chomp($num_running);

if ($num_running < 1){
    $output=`curl http://c2.pcons.net/cgi-bin/restart_qd_pconsc_fe.cgi 2>&1 | html2text`;
    my $subject = "qd_pconsc_fe.pl restarted for c2.pcons.net";
    foreach my $to_email(@to_email_list) {
        sendmail($to_email, $from_email, $subject, $output);
    }
}

# third, check if qd_pconsc.pl is running at the main node on the PDC cloud
# shu.scilifelab.se
my $computenodefile = "$basedir/computenode.txt";

my @computenodelist = ();
open(IN, "<", $computenodefile) or die;
while(<IN>) {
    chomp;
    push @computenodelist, $_;
}
close IN;

my $target_progname = "qd_pconsc.pl";

foreach my $computenode (@computenodelist) {
    $num_running=`curl http://$computenode/pconsc/cgi-bin/check_qd_pconsc.cgi 2> /dev/null | html2text | grep $target_progname | wc -l`;
    chomp($num_running);

    if ($num_running < 1){
        $output=`curl http://$computenode/pconsc/cgi-bin/restart_qd_pconsc.cgi 2>&1 | html2text`;
        my $subject = "$target_progname restarted at $computenode ";
        foreach my $to_email(@to_email_list) {
            sendmail($to_email, $from_email, $subject, $output);
        }
    }
}
