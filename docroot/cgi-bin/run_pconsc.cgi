#!/usr/bin/perl -w
# filename: run_pconsc.cgi
# description: cgi to exec run_pconsc.sh
# Created 2014-06-23, updated 2014-07-01, Nanjiang Shu
# 
use CGI qw(:standard);
use CGI qw(:cgi-lib);
use CGI qw(:upload);

use Digest::MD5 qw(md5 md5_hex md5_base64);
use POSIX qw(strftime);

use Cwd 'abs_path'; 
use File::Basename;
my $rundir = dirname(abs_path(__FILE__));
my $basedir = "$rundir/../";

my $hostname_of_the_computer = `hostname` ;
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
    my $id=param('id');
    my $myemail="nanjiang.shu\@scilifelab.se";
    my $outdir= "$basedir/tmp/$id";
    print end_html();

    if ($id ne "" ){
        if (-d $outdir){# clean the tmp outdir if exist, added 2014-06-30
            `rm -rf $outdir `;
        }
        `mkdir -p $outdir/pconsc` ;
        #write fasta seq
        my $seqfile = "$outdir/sequence.fasta";
        open (OUT, ">$seqfile");
        print OUT ">$name\n";
        print OUT "$seq\n";
        close(OUT);

        my $logfile = "$outdir/pconsc/log.txt";

        $ENV{MPLCONFIGDIR} = "$basedir/tmp/"; #MPLCONFIGDIR must be a writable place for apache2, otherwise matplotlib will not load

        system("$rundir/run_pconsc.sh $seqfile $outdir > $logfile 2>&1 &");
    }
}
