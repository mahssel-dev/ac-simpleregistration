#!/usr/bin/env bash
set -euo pipefail

CFG_DIR="/var/www/html/application/config"
CFG_SAMPLE="$CFG_DIR/config.php.sample"
CFG_FILE="$CFG_DIR/config.php"

# Wenn keine config.php existiert, aus sample erzeugen
if [[ ! -f "$CFG_FILE" ]]; then
  cp "$CFG_SAMPLE" "$CFG_FILE"
fi

php -d detect_unicode=0 <<'PHP'
<?php
$file = getenv('CFG_FILE') ?: '/var/www/html/application/config/config.php';
$cfg  = file_get_contents($file);
if ($cfg === false) {
    fwrite(STDERR, "Could not read config file: $file\n");
    exit(1);
}

function envv(string $k): ?string {
    $v = getenv($k);
    if ($v === false) return null;
    $v = trim($v);
    return ($v === '') ? null : $v;
}

function set_config_value(string $cfg, string $key, $value): string {
    if ($value === null) return $cfg;
    $export = var_export($value, true);
    $pattern = '/(\$config\[\''.preg_quote($key, '/').'\']\s*=\s*)(.*?);/s';
    $replacement = '$1' . $export . ';';
    // Nur erstes Vorkommen ersetzen (damit wir nicht aus Versehen mehrere Stellen treffen)
    return preg_replace($pattern, $replacement, $cfg, 1);
}

function set_realm1_value(string $cfg, string $key, $value): string {
    if ($value === null) return $cfg;
    $export = var_export($value, true);

    // Realm "1" Block finden und darin key ersetzen
    $patternRealm = '/(\$config\[\x27realmlists\x27\]\s*=\s*array\(\s*'
        . '.*?'
        . '"1"\s*=>\s*array\()(.*?)(\)\s*,\s*.*?\)\s*;)/s';

    return preg_replace_callback($patternRealm, function($m) use ($key, $export) {
        $head = $m[1];
        $body = $m[2];
        $tail = $m[3];

        $patternKey = '/(\x27'.preg_quote($key, '/').'\x27\s*=>\s*)(.*?)(,)/s';
        $replacementKey = '$1' . $export . '$3';

        // Nur erstes Vorkommen im Realm1-Body ersetzen
        $body2 = preg_replace($patternKey, $replacementKey, $body, 1);
        return $head . $body2 . $tail;
    }, $cfg, 1);
}

/**
 * Mapping: deine gewünschten Compose-ENV-Keys (lowercase)
 * -> Config Keys in PHP
 */
$cfg = set_config_value($cfg, 'baseurl',   envv('baseurl'));
$cfg = set_config_value($cfg, 'realmlist', envv('realmlist'));

$cfg = set_config_value($cfg, 'smtp_host', envv('smtp_host'));
$cfg = set_config_value($cfg, 'smtp_user', envv('smtp_user'));
$cfg = set_config_value($cfg, 'smtp_pass', envv('smtp_pass'));

$cfg = set_config_value($cfg, 'db_auth_host',   envv('db_auth_host'));
$cfg = set_config_value($cfg, 'db_auth_pass',   envv('db_auth_pass'));
$cfg = s
