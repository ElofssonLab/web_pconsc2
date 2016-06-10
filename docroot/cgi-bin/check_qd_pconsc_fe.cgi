#!/usr/bin/perl -w
# filename:  check_qd_pconsc_fe.cgi
# Description: check if the script qd_pconsc_fe.pl is running
# Created 2014-06-25, updated 2014-07-01, Nanjiang Shu 

use CGI qw(:standard);
use CGI qw(:cgi-lib);
use CGI qw(:upload);

use Cwd 'abs_path';
use File::Basename;
my $rundir = dirname(abs_path(__FILE__));
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
print start_html(-title => "Check if $target_progname is running",
    -author => "nanjiang.shu\@scilifelab.se",
    -meta   => {'keywords'=>''});

if(!param())
{
    my $username=`whoami`;
    #print "username=$username";
    #print "<br>";
    my $already_running=`ps aux | grep  $target_progname | grep "$search_word" | grep -v grep |grep -v archive_logfile |  grep $username`;
    print "<pre>";
    print $already_running;
    print "</pre>";
    print '<br>';
    print end_html();
}
