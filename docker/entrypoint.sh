#!/usr/bin/env bash
set -euo pipefail

CFG_DIR="/var/www/html/application/config"
CFG_SAMPLE="$CFG_DIR/config.php.sample"
CFG_FILE="$CFG_DIR/config.php"

# Falls noch keine config.php existiert: aus Sample erzeugen
if [[ ! -f "$CFG_FILE" ]]; then
  cp "$CFG_SAMPLE" "$CFG_FILE"
fi

# helper: setzt $config['key'] = ...; (String/Bool/Int)
set_cfg() {
  local key="$1"
  local type="$2"   # string|bool|int
  local val="${3:-}"

  [[ -z "${val}" ]] && return 0

  case "$type" in
    string)
      # Escape für sed (\, /, &)
      local esc
      esc="$(printf '%s' "$val" | sed -e 's/[\\/&]/\\&/g')"
      sed -i -E "s|(\$config\['$key'\]\s*=\s*)(\"[^\"]*\"|'[^']*')\s*;|\1\"$esc\";|g" "$CFG_FILE"
      ;;
    bool)
      local b="false"
      [[ "$val" == "1" || "$val" == "true" || "$val" == "TRUE" ]] && b="true"
      sed -i -E "s|(\$config\['$key'\]\s*=\s*)(true|false)\s*;|\1$b;|g" "$CFG_FILE"
      ;;
    int)
      sed -i -E "s|(\$config\['$key'\]\s*=\s*)([0-9]+)\s*;|\1$val;|g" "$CFG_FILE"
      ;;
  esac
}

# Basis
set_cfg baseurl string "${WSR_BASEURL:-}"
set_cfg page_title string "${WSR_PAGE_TITLE:-}"
set_cfg realmlist string "${WSR_REALMLIST:-}"
set_cfg patch_location string "${WSR_PATCH_LOCATION:-}"
set_cfg game_version string "${WSR_GAME_VERSION:-}"
set_cfg expansion string "${WSR_EXPANSION:-}"

# Auth-DB
set_cfg db_auth_host string "${WSR_DB_AUTH_HOST:-}"
set_cfg db_auth_port string "${WSR_DB_AUTH_PORT:-}"
set_cfg db_auth_user string "${WSR_DB_AUTH_USER:-}"
set_cfg db_auth_pass string "${WSR_DB_AUTH_PASS:-}"
set_cfg db_auth_dbname string "${WSR_DB_AUTH_DBNAME:-}"

# Flags/Template
set_cfg battlenet_support bool "${WSR_BATTLENET_SUPPORT:-}"
set_cfg disable_top_players bool "${WSR_DISABLE_TOP_PLAYERS:-}"
set_cfg disable_online_players bool "${WSR_DISABLE_ONLINE_PLAYERS:-}"
set_cfg multiple_email_use bool "${WSR_MULTIPLE_EMAIL_USE:-}"
set_cfg debug_mode bool "${WSR_DEBUG_MODE:-}"
set_cfg template string "${WSR_TEMPLATE:-}"

# SMTP (optional)
set_cfg smtp_host string "${WSR_SMTP_HOST:-}"
set_cfg smtp_port int "${WSR_SMTP_PORT:-}"
set_cfg smtp_auth bool "${WSR_SMTP_AUTH:-}"
set_cfg smtp_user string "${WSR_SMTP_USER:-}"
set_cfg smtp_pass string "${WSR_SMTP_PASS:-}"
set_cfg smtp_secure string "${WSR_SMTP_SECURE:-}"
set_cfg smtp_mail string "${WSR_SMTP_MAIL:-}"

# Optional: Realm 1 DB (realmlists array) – ersetzt die Defaultwerte für den ersten Realm-Eintrag
# (einfach, aber pragmatisch: erste Vorkommen austauschen)
if [[ -n "${WSR_REALM_DB_HOST:-}" ]]; then
  sed -i -E "0,/'db_host'\s*=>\s*\"[^\"]*\"/s//\'db_host\' => \"$(printf '%s' "$WSR_REALM_DB_HOST" | sed 's/[\\/&]/\\&/g')\"/" "$CFG_FILE"
fi
if [[ -n "${WSR_REALM_DB_PORT:-}" ]]; then
  sed -i -E "0,/'db_port'\s*=>\s*\"[^\"]*\"/s//\'db_port\' => \"$(printf '%s' "$WSR_REALM_DB_PORT" | sed 's/[\\/&]/\\&/g')\"/" "$CFG_FILE"
fi
if [[ -n "${WSR_REALM_DB_USER:-}" ]]; then
  sed -i -E "0,/'db_user'\s*=>\s*\"[^\"]*\"/s//\'db_user\' => \"$(printf '%s' "$WSR_REALM_DB_USER" | sed 's/[\\/&]/\\&/g')\"/" "$CFG_FILE"
fi
if [[ -n "${WSR_REALM_DB_PASS:-}" ]]; then
  sed -i -E "0,/'db_pass'\s*=>\s*'[^']*'/s//\'db_pass\' => '$(printf '%s' "$WSR_REALM_DB_PASS" | sed "s/[\\/&]/\\\\&/g")'/" "$CFG_FILE"
fi
if [[ -n "${WSR_REALM_DB_NAME:-}" ]]; then
  sed -i -E "0,/'db_name'\s*=>\s*\"[^\"]*\"/s//\'db_name\' => \"$(printf '%s' "$WSR_REALM_DB_NAME" | sed 's/[\\/&]/\\&/g')\"/" "$CFG_FILE"
fi

exec "$@"
