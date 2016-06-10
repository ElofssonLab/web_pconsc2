#!/usr/bin/perl -w
# filename:  delete_pconsc_tmpdata.cgi
# description: delete temporary data on each cloud VM after retrieving of the
# result
# Created 2015-03-06, updated 2015-03-06, Nanjiang Shu
# 
use CGI qw(:standard);
use CGI qw(:cgi-lib);
use CGI qw(:upload);

use Digest::MD5 qw(md5 md5_hex md5_base64);
use POSIX qw(strftime);
use Net::Domain qw(hostname hostfqdn hostdomain domainname);

use Cwd 'abs_path'; 
use File::Basename;
my $rundir = dirname(abs_path(__FILE__));
my $basedir = "$rundir/../";

my $hostname_of_the_computer = hostname();
my $date = strftime "%Y-%m-%d %H:%M:%S", localtime;

print header();
print start_html(-title => "PconsC script to delete temporary data",
    -author => "nanjiang.shu\@scilifelab.se",
    -meta   => {'keywords'=>''});

if(!param())
{
    print 'Give me something to work on instead...';
    print end_html();
}

if (param())
{
    my $id=param('id');
    my $myemail="nanjiang.shu\@scilifelab.se";
    my $outdir= "$basedir/tmp/$id";

    if (-d $outdir){
        `rm -rf $outdir `;
        print "rm -rf $outdir";
        print '<br>';
    }
    print end_html();
}
