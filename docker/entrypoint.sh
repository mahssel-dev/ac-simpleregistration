#!/usr/bin/env bash
set -euo pipefail

CFG_DIR="/var/www/html/application/config"
CFG_SAMPLE="$CFG_DIR/config.php.sample"
CFG_FILE="$CFG_DIR/config.php"

# Wenn keine config.php existiert, aus sample erzeugen
if [[ ! -f "$CFG_FILE" ]]; then
  cp "$CFG_SAMPLE" "$CFG_FILE"
fi

escape_sed() {
  # escapes \ / &
  printf '%s' "$1" | sed -e 's/[\\/&]/\\&/g'
}

set_php_string() {
  # ersetzt: $config['key'] = "..."
  local key="$1"
  local val="${2:-}"
  [[ -z "$val" ]] && return 0
  local esc; esc="$(escape_sed "$val")"
  sed -i -E "s|(\$config\['$key'\]\s*=\s*)(\"[^\"]*\"|'[^']*')\s*;|\1\"$esc\";|g" "$CFG_FILE"
}

# für realmlists["1"] innerhalb des ersten Realm-Blocks
set_realm1_string() {
  local key="$1"
  local val="${2:-}"
  [[ -z "$val" ]] && return 0
  local esc; esc="$(escape_sed "$val")"
  # innerhalb des "1" => array( ... ) nur erstes Vorkommen ersetzen
  sed -i -E "0,/\"1\"\s*=>\s*array\(/{
    /\"1\"\s*=>\s*array\(/,/\),/ s|('$key'\s*=>\s*)(\"[^\"]*\"|'[^']*')|\1\"$esc\"|
  }" "$CFG_FILE"
}

set_realm1_intlike() {
  local key="$1"
  local val="${2:-}"
  [[ -z "$val" ]] && return 0
  local esc; esc="$(escape_sed "$val")"
  sed -i -E "0,/\"1\"\s*=>\s*array\(/{
    /\"1\"\s*=>\s*array\(/,/\),/ s|('$key'\s*=>\s*)(\"[^\"]*\"|'[^']*'|[0-9]+)|\1\"$esc\"|
  }" "$CFG_FILE"
}

# ---- Map deiner gewünschten ENV keys -> config.php ----
# Achtung: env_file Keys sind lowercase; Compose setzt sie exakt so.
set_php_string baseurl   "${baseurl:-}"
set_php_string realmlist "${realmlist:-}"

set_php_string smtp_host "${smtp_host:-}"
set_php_string smtp_user "${smtp_user:-}"
set_php_string smtp_pass "${smtp_pass:-}"

set_php_string db_auth_host   "${db_auth_host:-}"
set_php_string db_auth_pass   "${db_auth_pass:-}"
set_php_string db_auth_dbname "${db_auth_dbname:-}"

# Realm 1 (realmlists)
set_realm1_string realmname "${realmname:-}"
set_realm1_string db_host   "${db_host:-}"
set_realm1_intlike db_port  "${db_port:-}"
set_realm1_string db_user   "${db_user:-}"
set_realm1_string db_pass   "${db_pass:-}"
set_realm1_string db_name   "${db_name:-}"

exec "$@"
