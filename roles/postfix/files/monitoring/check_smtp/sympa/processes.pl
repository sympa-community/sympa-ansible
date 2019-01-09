#!/usr/bin/perl

use File::Basename;
use File::Slurp;

my $dir = dirname(__FILE__);

my @processes = [
    'apache2',
    'mysql',
    '/usr/lib/postfix/sbin/master',
    'qmgr',
    'pickup',
    'perl /usr/local/sympa/bin/sympa_msg.pl',
    'perl /usr/local/sympa/bin/archived.pl',
    'perl /usr/local/sympa/bin/bounced.pl',
    'perl /usr/local/sympa/bin/task_manager.pl',
    'perl /usr/local/sympa/bin/bulk.pl',
    'perl /usr/local/sympa/bin/wwsympa.fcgi',
    'perl /usr/local/sympa/bin/sympa_soap_server.fcgi'
];

my @running = `ps axo args`;

my $ok = 1;
my @statuses;
foreach my $process (@processes) {
    my $runs = scalar(grep { index($_, $process) > -1 } @running) > 0;
    
    $ok = 0 unless $runs;
    
    push(@statuses, $process.' '.($runs ? 'ok' : 'ko'));
}

unshift(@statuses, 'global '.($ok ? 'ok' : 'ko'));

foreach my $domain (grep { -d "$dir/results/$_" } read_dir("$dir/results")) {
    write_file("$dir/results/$domain/processes.txt", @statuses);
}

0;
