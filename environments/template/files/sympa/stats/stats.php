#!/usr/bin/php
<?php

$dir = dirname(__FILE__);

$conf = [];
$lines = file_get_contents("$dir/stats.conf");
if($lines === false) die("could not open config: $dir/stats.conf\n");
foreach(array_map('trim', explode("\n", $lines)) as $line) {
    if(!preg_match('/^([a-z][a-z0-9_\.]*)\s+(.+)$/i', $line, $m)) continue;
    $conf[$m[1]] = $m[2];
}

foreach(['url', 'db_user', 'db_password'] as $c) {
    if(!array_key_exists($c, $conf)) die("missing config parameter: $c\n");
}

if($conf['url'] === 'disabled') exit;

$pass_scope  = function($domain) use($conf) {
    $id = (array_key_exists($domain, $conf) && (int)$conf[$domain]) ? $conf[$domain] : 'unknown';
    return 'pass://institution/'.$id;
};

$push = function($csv) use($conf) {
    $delim = '--------'.uniqid();
    
    $data = "--$delim\r\n";
    $data .= "Content-Disposition: form-data; name=stats.csv; filename=stats.csv\r\n";
    $data .= "Content-Type: text/csv\r\n";
    $data .= "\r\n";
    foreach($csv as $line)
        $data .= implode(',' ,$line)."\r\n";
    $data .= "\r\n--$delim--\r\n";
    
    $curl = curl_init();
    curl_setopt($curl, CURLOPT_URL, $conf['url']);
    curl_setopt($curl, CURLOPT_POST, true);
    curl_setopt($curl, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($curl, CURLOPT_HTTPHEADER, [
        'Content-Type: multipart/form-data; boundary='.$delim,
        'Content-Length: '.strlen($data),
    ]);
    curl_setopt($curl, CURLOPT_POSTFIELDS, $data);
    
    $res = curl_exec($curl);
    $error = curl_error($curl);
    
    if(!$error) {
        $code = (int)curl_getinfo($curl, CURLINFO_HTTP_CODE);
        $header_len = curl_getinfo($curl, CURLINFO_HEADER_SIZE);
        $header = substr($res, 0, $header_len);
        $res = substr($res, $header_len);
    }
    
    curl_close($curl);
    
    if($error) throw new Exception('cUrl error : '.$error);
    
    if($code != 201) throw new Exception('didn\'t get 201 Created : '.$code.' '.$res);
    
    return (int)$res;
};

$monday = date('N') == 1;

$sympa_log = '/var/log/sympa'.($monday ? '.1' : '');
$postfix_log = '/var/log/mail.log'.($monday ? '.1' : '');

$start = strtotime('yesterday 00:00:00');
$end = strtotime('yesterday 23:59:59');
$stats = [];

try {
    $pdo = new PDO('mysql:host=localhost;dbname=sympa', $conf['db_user'], $conf['db_password']);
    $pdo->setAttribute(PDO::ATTR_DEFAULT_FETCH_MODE, PDO::FETCH_ASSOC);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    
    // Init domains
    $etc = '/usr/local/sympa/etc/';
    foreach(scandir($etc) as $i) {
        if(!is_dir($etc.$i) || !file_exists($etc.$i.'/robot.conf')) continue;
        $stats[$i] = ['listes' => 0, 'abonnes' => 0, 'abonnements' => 0, 'messages_entrants' => 0, 'messages_sortants' => 0, 'logins' => []];
    }
    
    $st = $pdo->query("SELECT DISTINCT robot_list AS domain, COUNT(*) AS lists FROM list_table WHERE status_list='open' AND creation_epoch_list <= $end GROUP BY robot_list");
    foreach($st->fetchAll() as $robot)
        if(array_key_exists($robot['domain'], $stats))
            $stats[$robot['domain']]['listes'] = (int)$robot['lists'];
    
    
    // #lists
    $st = $pdo->query("SELECT robot_list AS domain, COUNT(*) AS lists FROM list_table WHERE status_list='open' AND creation_epoch_list <= $end GROUP BY robot_list");
    foreach($st->fetchAll() as $robot)
        if(array_key_exists($robot['domain'], $stats))
            $stats[$robot['domain']]['listes'] = (int)$robot['lists'];
    
    // #subscribers
    $st = $pdo->query("SELECT robot_subscriber AS domain, COUNT(DISTINCT user_subscriber) AS subs FROM subscriber_table INNER JOIN list_table ON (list_subscriber = name_list AND robot_subscriber = robot_list) WHERE status_list='open' AND creation_epoch_list <= $end GROUP BY robot_subscriber");
    foreach($st->fetchAll() as $robot)
        if(array_key_exists($robot['domain'], $stats))
            $stats[$robot['domain']]['abonnes'] = (int)$robot['subs'];
    
    // #subscriptions
    $st = $pdo->query("SELECT robot_subscriber AS domain, COUNT(*) AS subs FROM subscriber_table INNER JOIN list_table ON (list_subscriber = name_list AND robot_subscriber = robot_list) WHERE status_list='open' AND creation_epoch_list <= $end GROUP BY robot_subscriber");
    foreach($st->fetchAll() as $robot)
        if(array_key_exists($robot['domain'], $stats))
            $stats[$robot['domain']]['abonnements'] = (int)$robot['subs'];
    
    // #received
    $st = $pdo->query("SELECT robot_counter AS domain, SUM(count_counter) AS sent FROM stat_counter_table WHERE beginning_date_counter >= $start AND end_date_counter <= $end AND data_counter = 'send_mail' GROUP BY robot_counter");
    foreach($st->fetchAll() as $robot)
        if(array_key_exists($robot['domain'], $stats))
            $stats[$robot['domain']]['messages_entrants'] = (int)$robot['sent'];
    
    $day = sprintf('%s %2d', date('M', $end), date('j', $end));
    
    // #sent
    $log = `grep "$day" $postfix_log |grep nrcpt |grep -v "from=<sympa-request@" |awk '{print $7 " " $9}'`;
    foreach(array_filter(array_map('trim', explode("\n", $log))) as $line) {
        if(preg_match('`^from=<[^@]+@([^>]+)>, nrcpt=([1-9][0-9]*)$`', $line, $m)) {
            if(!array_key_exists($m[1], $stats)) continue;
            $stats[$m[1]]['messages_sortants'] += (int)$m[2];
        }
    }
    
    // #users
    $log = `grep "$day" $sympa_log |grep "main::do_sso_login()" |grep "User identified as" |awk '{print $9 " " \$NF}'`;
    foreach(array_filter(array_map('trim', explode("\n", $log))) as $line) {
        if(preg_match('`^([^\]]+)\] (.+)$`', $line, $m)) {
            $uid = md5($m[2]);
            if(!array_key_exists($m[1], $stats)) continue;
            if(!array_key_exists($uid, $stats[$m[1]]['logins'])) $stats[$m[1]]['logins'][$uid] = 0;
            $stats[$m[1]]['logins'][$uid]++;
        }
    }
    
    // Build and send csvs
    
    $csv = [['time', 'scope', 'listes', 'abonnes', 'abonnements', 'messages_entrants', 'messages_sortants']];
    foreach($stats as $domain => $data)
        $csv[] = [$end, $pass_scope($domain), $data['listes'], $data['abonnes'], $data['abonnements'], $data['messages_entrants'], $data['messages_sortants']];
    
    $push($csv);
    
    foreach($stats as $domain => $data) {
        $csv = [['time', 'scope'], [$end, $pass_scope($domain)]];
        foreach($data['logins'] as $uid => $cnt) {
            $csv[0][] = "logins/$uid";
            $csv[1][] = $cnt;
        }
        $push($csv);
    }
    
} catch(Exception $e) {
    die($e->getMessage()."\n");
}
