#!/usr/bin/php
<?php

$self = array_shift($argv);
$domain = array_shift($argv);
if(!preg_match('/^([a-z0-9]+(-[a-z0-9]+)*\.)+[a-z]{2,}$/i', $domain)) die("bad domain: $domain\n");

$dir = dirname(__FILE__);

$conf = [];
$lines = file_get_contents("$dir/check.conf");
if($lines === false) die("could not open config: $dir/check.conf\n");
foreach(array_map('trim', explode("\n", $lines)) as $line) {
    if(!preg_match('/^([a-z][a-z0-9_\.]*)\s+(.+)$/i', $line, $m)) continue;
    $conf[$m[1]] = $m[2];
}

foreach(['smtp_out', 'address', 'auth_secret', 'source'] as $c) {
    if(!array_key_exists($c, $conf)) die("missing config parameter: $c\n");
}

$from = 'listmaster@'.$domain;
$to = $conf['address'].'@'.$domain;
$now = time();
$source = $conf['source'];

$signature = hash_hmac('sha1', $now.'@'.$source, $conf['auth_secret']);

$headers = [
    "X-Source: $source",
    "X-Generated: $now",
    "X-Authentication: $signature",
];

if(!mail($to, 'SMTP chain check', 'This is a SMTP chain check message', implode("\n", $headers)))
    die("could not send message\n");
