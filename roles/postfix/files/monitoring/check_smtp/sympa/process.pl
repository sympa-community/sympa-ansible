#!/usr/bin/perl

use File::Basename;
use File::Slurp;
use Digest::HMAC_SHA1 qw(hmac_sha1_hex);

my $domain = shift @ARGV;
die "bad domain: $domain\n" unless $domain =~ /^([a-z0-9]+(-[a-z0-9]+)*\.)+[a-z]{2,}$/i;

my $dir = dirname(__FILE__);

my %conf;
foreach my $line (read_file("$dir/check.conf", chomp => 1)) {
    next unless $line =~ /^([a-z][a-z0-9_\.]*)\s+(.+)$/i;
    $conf{$1} = $2;
}

foreach my $c ('auth_secret', 'max_delay') {
    die "missing config parameter: $c\n" unless defined $conf{$c};
}

my %data;
foreach my $line (<STDIN>) {
    chomp $line;
    last if $line =~ /^\s*$/;
    next unless $line =~ /^(To|X-Source|X-Generated|X-Authentication):\s*(.+)$/;
    my ($key, $value) = ($1, $2);
    $key =~ s/^X-//;
    $data{lc $key} = $value;
}

foreach my $c ('to', 'source', 'generated', 'authentication') {
    exit 0 unless defined $data{$c}; # Ignores incomplete pings
}

my $signature = hmac_sha1_hex($data{'generated'}.'@'.$data{'source'}, $conf{'auth_secret'});
exit 0 unless $data{'authentication'} eq $signature;

my ($local, $domain) = split(/@/, $data{'to'});
$domain = $conf{$domain} if defined $conf{$domain};

my $sent = int $data{'generated'};
my $received = time;
my $delay = $received - $sent;

write_file("$dir/results/$domain/".$data{'source'}.".txt", [
    "status ok\n",
    "sent $sent\n",
    "received $received\n",
    "delay $delay\n"
]);

0;
