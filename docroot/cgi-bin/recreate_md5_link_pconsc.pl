#!/usr/bin/perl -w
# Filename:  recreate_md5_link_pconsc.pl 
use Digest::MD5 qw(md5 md5_hex md5_base64);
use Net::Domain qw(hostname hostfqdn hostdomain domainname);

use Cwd 'abs_path'; 
use File::Basename;
my $rundir = dirname(abs_path(__FILE__));
my $basedir = "$rundir/../";
my $resultpath = "$basedir/result";
my $progname = basename(__FILE__);
my $progname_15char = substr $progname, 0, 15;

my $hostname_of_the_computer = hostname();
my $date = localtime();

my $usage ="
usage: $progname

Created 2014-07-02, updated 2014-07-02, Nanjiang Shu
";

my $numArgs = $#ARGV+1;

my @job_folders=();
opendir(DIR,"$resultpath");
my @folders=readdir(DIR);
closedir(DIR);

foreach my $folder(@folders)
{
    if(($folder=~/^\d+$/ || $folder=~/r_/ ) && 
        (-d "$resultpath/$folder" || -l "$resultpath/$folder"))
    {
        push(@job_folders,$folder);
    }
}

my $md5dir="$basedir/md5";
if (! -d $md5dir){
    `mkdir -p $md5dir`;
}

foreach my $folder(@job_folders)
{
    #print "folder: $folder"."\n";
    my $seqfile = "$resultpath/$folder/sequence";
    my $tagfile_failed = "$resultpath/$folder/pconsc.failed";
    if (-e $tagfile_failed){
        next; #do not cache failed jobs
    }
    if (! -s $seqfile){
        print "$seqfile does not exist or empty. Skip $folder\n";
        next;
    }
    my $seq = ReadSeq($seqfile);
    my $digest = md5_hex($seq);
    my $subfolder = substr $digest, 0, 2;
    my $submd5dir = "$md5dir/$subfolder";
    if (! -d $submd5dir){
        `mkdir -p $submd5dir`;
    }

    my $linkfile = "$submd5dir/$digest";
    if (! -l $linkfile){
        chdir("$submd5dir");
        exec_cmd("ln -s ../../result/$folder $digest");
    }
}

sub ReadSeq#{{{
{
    my $file=shift;
    my $seq=`grep -v '>' $file`;
    $seq=~s/\n//g;
    return $seq;
}#}}}
sub exec_cmd{#{{{ #debug nanjiang
    # print the date and content of the command and then execute the command
    my $date = localtime();
    print "[$date] @_"."\n";
    system( "@_");
}#}}}
