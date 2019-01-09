#!/usr/bin/perl

use File::Basename;
use File::Slurp;

my $dir = dirname(__FILE__);

my %conf;
foreach my $line (read_file("$dir/check.conf", chomp => 1)) {
    next unless $line =~ /^([a-z][a-z0-9_\.]*)\s+(.+)$/i;
    $conf{$1} = $2;
}
close $ch;

foreach my $c ('max_delay') {
    die "missing config parameter: $c\n" unless defined $conf{$c};
}

my @domains = grep { -d "$dir/results/$_" } read_dir("$dir/results");
foreach my $domain (@domains) {
    my @files = grep { /^[^\.].+\.txt/ && -f "$dir/results/$domain/$_" } read_dir("$dir/results/$domain");
    foreach my $file (@files) {
        my @lines = read_file("$dir/results/$domain/$file");
        my @sent = map { /\s+(.+)$/; $1 } grep { /^sent\s/ } @lines;
        next if int shift @sent >= time - int $conf{'max_delay'};
        
        $lines[0] = "status ko\n";
        write_file("$dir/results/$domain/$file", @lines);
    }
}

0;
