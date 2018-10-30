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

foreach(['url', 'barn'] as $c) {
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
$stats = [];

try {
    // List wikis
    $barn = $conf['barn'];
    foreach(scandir($conf['barn']) as $domain) {
        $domain_barn = $conf['barn'].'/'.$domain
        if(!is_dir($domain_barn)) continue;
        
        $wikis = array_filter(scandir($domain_barn), function($name) use($domain_barn, $time) {
            $dir = $domain_barn.'/'.$name;
            return is_dir($dir) && (filectime($dir) <= $time) && file_exists($dir.'/conf/local.protected.php');
        });
        $created = array_filter($wikis, function($name) use($domain_barn, $time) {
            return filectime($domain_barn.'/'.$name) >= $time - 86399;
        });
        $stats[$i] = ['wikis' => count($wikis), 'created' => count($created)];
    }
    
    // Build and send csv
    
    $csv = [['time', 'scope', 'wikis', 'wikis_crees']];
    foreach($stats as $domain => $data)
        $csv[] = [$time, $pass_scope($domain), $data['wikis'], $data['created']];
    
    $push($csv);
    
} catch(Exception $e) {
    die($e->getMessage()."\n");
}
