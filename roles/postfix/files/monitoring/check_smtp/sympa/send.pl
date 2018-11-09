#!/usr/bin/perl

use File::Basename;
use File::Slurp;
use Net::SMTP;
use Digest::HMAC_SHA1 qw(hmac_sha1_hex);

my $domain = shift @ARGV;
die "bad domain: $domain\n" unless $domain =~ /^([a-z0-9]+(-[a-z0-9]+)*\.)+[a-z]{2,}$/i;

my $dir = dirname(__FILE__);

my %conf;
foreach my $line (read_file("$dir/check.conf", chomp => 1)) {
    next unless $line =~ /^([a-z][a-z0-9_\.]*)\s+(.+)$/i;
    $conf{$1} = $2;
}

foreach my $c ('smtp_out', 'address', 'auth_secret', 'source') {
    die "missing config parameter: $c\n" unless defined $conf{$c};
}

my $from = 'listmaster@'.$domain;
my $to = $conf{'address'}.'@'.$domain;
my $now = time;
my $source = $conf{'source'};

my $signature = hmac_sha1_hex($now.'@'.$source, $conf{'auth_secret'});

my $smtp = Net::SMTP->new($conf{'smtp_out'});
$smtp->mail($from);

if($smtp->to($to)) {
    $smtp->data();
    $smtp->datasend("To: $to\n");
    $smtp->datasend("X-Source: $source\n");
    $smtp->datasend("X-Generated: $now\n");
    $smtp->datasend("X-Authentication: $signature\n");
    $smtp->datasend("Subject: SMTP chain check\n");
    $smtp->datasend("\n");
    $smtp->datasend("This is a SMTP chain check message\n");
    $smtp->dataend();
} else {
    die "smtp error: ".$smtp->message()."\n";
}

$smtp->quit;

0;
