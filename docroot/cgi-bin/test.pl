#!/usr/bin/perl -w
use Cwd 'abs_path';
use File::Basename;

my $rundir = dirname(abs_path(__FILE__));
my $basedir = "$rundir/../";
require "$rundir/nanjianglib.pl";

my $from_email = "nanjiang.shu\@scilifelab.se";
my $to_email = "nanjiang.shu\@gmail.com";
my $subject = "sendmail by perl";
my $message = "send the mail by perl script. Just for testing";

sendmail($to_email, $from_email, $subject, $message);
