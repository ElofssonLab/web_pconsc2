#!/usr/bin/perl -w
# filename:   get_avail_resource.cgi
# Description: get the available resource on this computational node
# Created 2015-03-05, updated 2015-03-05, Nanjiang Shu 
# output
# num_total_node N
# num_running_node N
# num_avail_node N
# num_bad_node N

use CGI qw(:standard);
use CGI qw(:cgi-lib);
use CGI qw(:upload);

use Cwd 'abs_path';
use Net::Domain qw(hostname hostfqdn hostdomain domainname);
use File::Basename;
my $rundir = dirname(abs_path(__FILE__));
my $basedir = "$rundir/../";


print header();
print start_html(-title => "Get available resource",
    -author => "nanjiang.shu\@scilifelab.se",
    -meta   => {'keywords'=>''});

my $hostname = hostname();
my $dnsdomainname = `dnsdomainname`;
chomp($dnsdomainname);

if(!param())
{
    my $serverlistfile = "";
    if ($hostname =~ /pdc/){
        $serverlistfile = "$basedir/pdc.serverlist.txt";
    }elsif ($hostname =~ /egi/){
        $serverlistfile = "$basedir/egi.serverlist.txt";
    }else{
        if ($dnsdomainname =~/smog/){
            $serverlistfile = "$basedir/smog.serverlist.txt";
        }
    }

    my @serverlist = ();
    open(my $fpin, "<", $serverlistfile);
    if ($fpin){
        foreach my $line (<$fpin>){
            chomp($line);
            if ($line and $line !~ /^#/){
                push(@serverlist, $line);
            }
        }
    }
    close($fpin);
    my $num_total_node = 0;
    my $num_avail_node = 0;
    my $num_running_node = 0;
    my $num_bad_node = 0;
    foreach my $server (@serverlist){
        $num_total_node ++;
        my $cgibin_url = "";
        if ($rundir =~ /debug/){
            $cgibin_url = "http://$server/debug.pconsc/cgi-bin";
        }else{
            $cgibin_url = "http://$server/pconsc/cgi-bin";
        }
        my $url = "$cgibin_url/check_running_pconsc.cgi";
        my $return_msg=`curl "$url" 2>&1 | html2text `;
        if ($return_msg =~ /couldn't connect/){
            $num_bad_node ++;
        }elsif($return_msg !~ /run_pconsc/){
            $num_avail_node ++;
        }else{
            $num_running_node ++;
        }
    }
    my $text = "";
    $text .= "num_total_node: $num_total_node\n";
    $text .= "num_avail_node: $num_avail_node\n";
    $text .= "num_running_node: $num_running_node\n";
    $text .= "num_bad_node: $num_bad_node\n";

    print "<pre>";
    print $text;
    print "</pre>";
    print '<br>';
    print end_html();
}
