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

$time = strtotime('yesterday 23:59:59');
$start = date('Y-m-d H:i:s', $time - 86399);
$end = date('Y-m-d H:i:s', $time);
$stats = [];

try {
    $pdo = new PDO('mysql:host=localhost;dbname=limesurvey', $conf['db_user'], $conf['db_password']);
    $pdo->setAttribute(PDO::ATTR_DEFAULT_FETCH_MODE, PDO::FETCH_ASSOC);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    
    $q = "SELECT lime_plugin_settings.value AS list, lime_surveys.active, expires";
    $q .= " FROM lime_surveys LEFT OUTER JOIN lime_plugin_settings ON (lime_plugin_settings.model = 'Survey' AND lime_plugin_settings.model_id = lime_surveys.sid) LEFT OUTER JOIN lime_plugins ON(lime_plugins.id = lime_plugin_settings.plugin_id)";
    $q .= " WHERE lime_surveys.datecreated <= '$end' AND (lime_plugins.name IS NULL OR (lime_plugins.name = 'groupwarePlugin' AND lime_plugin_settings.`key` = 'list'))";
    
    $st = $pdo->query($q);
    foreach($st->fetchAll() as $survey) {
        list($local, $domain) = explode('@', (string)$survey['list'], 2);
        if(!array_key_exists($domain, $stats))
            $stats[$domain] = ['active' => 0, 'inactive' => 0, 'created' => 0];
        
        $stats[$domain][($survey['active'] == 'Y' && !$survey['expired']) ? 'active' : 'inactive']++;
    }
    
    $q = "SELECT lime_plugin_settings.value AS list";
    $q .= " FROM lime_surveys LEFT OUTER JOIN lime_plugin_settings ON (lime_plugin_settings.model = 'Survey' AND lime_plugin_settings.model_id = lime_surveys.sid) LEFT OUTER JOIN lime_plugins ON(lime_plugins.id = lime_plugin_settings.plugin_id)";
    $q .= " WHERE lime_surveys.datecreated >= '$start' AND lime_surveys.datecreated <= '$end' AND (lime_plugins.name IS NULL OR (lime_plugins.name = 'groupwarePlugin' AND lime_plugin_settings.`key` = 'list'))";
    
    $st = $pdo->query($q);
    foreach($st->fetchAll() as $survey) {
        list($local, $domain) = explode('@', (string)$survey['list'], 2);
        if(!array_key_exists($domain, $stats))
            $stats[$domain] = ['active' => 0, 'inactive' => 0, 'created' => 0];
        
        $stats[$domain]['created']++;
    }
    
    // Build and send csv
    
    $csv = [['time', 'scope', 'sondages_actifs', 'sondages_inactifs', 'sondages_crees']];
    foreach($stats as $domain => $data)
        $csv[] = [$end, $pass_scope($domain), $data['active'], $data['inactive'], $data['created']];
    
    $push($csv);
    
} catch(Exception $e) {
    die($e->getMessage()."\n");
}
