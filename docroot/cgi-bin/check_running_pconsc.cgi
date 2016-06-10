#!/usr/bin/perl -w
# filename:  check_running_pconsc.cgi
# Description: check if there are pconsc running 
# Created 2014-06-25, updated 2014-06-25, Nanjiang Shu 

use CGI qw(:standard); 
use CGI qw(:cgi-lib); 
use CGI qw(:upload); 

use Cwd 'abs_path';
use File::Basename;
my $rundir = dirname(abs_path(__FILE__));
my $basedir = "$rundir/../";


print header();
print start_html(-title => "Check if pconsc is running",
    -author => "nanjiang.shu\@scilifelab.se",
    -meta   => {'keywords'=>''});

if(!param())
{
    #my $username=`whoami`;
    my $already_running=`ps aux | grep  run_pconsc.sh | grep -v grep`;
    print "<pre>";
    print $already_running;
    print "</pre>";
    print '<br>';
    print end_html();
}
