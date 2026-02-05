#!/usr/bin/env bash
set -euo pipefail

CFG_DIR="/var/www/html/application/config"
CFG_SAMPLE="$CFG_DIR/config.php.sample"
CFG_FILE="$CFG_DIR/config.php"

# Nur neu generieren wenn config.php fehlt ODER Force gesetzt ist
if [[ ! -f "$CFG_FILE" || "${FORCE_CONFIG_REGEN:-false}" == "true" ]]; then
  cp "$CFG_SAMPLE" "$CFG_FILE"
fi

php <<'PHP'
<?php
$file = '/var/www/html/application/config/config.php';
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

/**
 * Ersetzt NUR den Wert einer bestehenden $config['key'] = ...; Zeile.
 * Wenn die Zeile nicht existiert, wird nichts gemacht (kein Neuschreiben der Datei-Struktur).
 */
function set_config_value(string $cfg, string $key, $value): string {
    if ($value === null) return $cfg;
    $export = var_export($value, true);
    $pattern = '/(\$config\[\''.preg_quote($key, '/').'\']\s*=\s*)(.*?);/s';
    if (!preg_match($pattern, $cfg)) {
        return $cfg; // Key nicht vorhanden -> nicht anfassen
    }
    return preg_replace($pattern, '$1'.$export.';', $cfg, 1);
}

/**
 * Setzt Wert im Realm-Block "1" => array(...)
 * Auch hier: nur ersetzen, wenn Key im Block existiert.
 */
function set_realm1_value(string $cfg, string $key, $value): string {
    if ($value === null) return $cfg;
    $export = var_export($value, true);

    $realmBlockPattern =
        '/(\$config\[\x27realmlists\x27\]\s*=\s*array\(\s*.*?"1"\s*=>\s*array\()(.*?)(\)\s*,\s*.*?\)\s*;)/s';

    if (!preg_match($realmBlockPattern, $cfg)) {
        return $cfg; // realmlists Struktur nicht gefunden
    }

    return preg_replace_callback($realmBlockPattern, function($m) use ($key, $export) {
        $head = $m[1];
        $body = $m[2];
        $tail = $m[3];

        $keyPattern = '/(\x27'.preg_quote($key, '/').'\x27\s*=>\s*)(.*?)(,)/s';
        if (!preg_match($keyPattern, $body)) {
            return $head.$body.$tail; // Key im Realmblock nicht vorhanden
        }
        $body = preg_replace($keyPattern, '$1'.$export.'$3', $body, 1);
        return $head.$body.$tail;
    }, $cfg, 1);
}

/**
 * Mapping: deine lowercase ENV Keys aus docker-compose.yml
 */
$cfg = set_config_value($cfg, 'baseurl',   envv('baseurl'));
$cfg = set_config_value($cfg, 'realmlist', envv('realmlist'));

$cfg = set_config_value($cfg, 'smtp_host', envv('smtp_host'));
$cfg = set_config_value($cfg, 'smtp_user', envv('smtp_user'));
$cfg = set_config_value($cfg, 'smtp_pass', envv('smtp_pass'));

$cfg = set_config_value($cfg, 'db_auth_host',   envv('db_auth_host'));
$cfg = set_config_value($cfg, 'db_auth_pass',   envv('db_auth_pass'));
$cfg = set_config_value($cfg, 'db_auth_dbname', envv('db_auth_dbname'));

$cfg = set_realm1_value($cfg, 'realmname', envv('realmname'));
$cfg = set_realm1_value($cfg, 'db_host',   envv('db_host'));
$cfg = set_realm1_value($cfg, 'db_port',   envv('db_port'));
$cfg = set_realm1_value($cfg, 'db_user',   envv('db_user'));
$cfg = set_realm1_value($cfg, 'db_pass',   envv('db_pass'));
$cfg = set_realm1_value($cfg, 'db_name',   envv('db_name'));

if (file_put_contents($file, $cfg) === false) {
    fwrite(STDERR, "Could not write config file: $file\n");
    exit(1);
}
PHP

exec "$@"
