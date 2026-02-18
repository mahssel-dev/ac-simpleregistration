<?php
declare(strict_types=1);

// ========= Konfiguration =========
$API_KEY = 'CHANGE_ME_SUPER_LONG_RANDOM';
$REMOTE_DIR = 'https://adamnhm.freeddns.org/patches/files/Updater/'; // muss mit / enden
$ALLOWED_EXT = ['zip'];

// ========= Helpers =========
function h(string $s): string {
  return htmlspecialchars($s, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
}

function curlGetHtml(string $url, string $apiKey): array {
  $ch = curl_init($url);
  curl_setopt_array($ch, [
    CURLOPT_RETURNTRANSFER => true,
    CURLOPT_FOLLOWLOCATION => true,
    CURLOPT_FAILONERROR    => false,
    CURLOPT_CONNECTTIMEOUT => 10,
    CURLOPT_TIMEOUT        => 20,
    CURLOPT_HTTPHEADER     => [
      'X-Api-Key: ' . $apiKey,
      'Accept: text/html,*/*',
      'Cache-Control: no-cache',
    ],
  ]);

  $body = curl_exec($ch);
  $err  = curl_error($ch);
  $code = (int)curl_getinfo($ch, CURLINFO_RESPONSE_CODE);
  curl_close($ch);

  return [$code, $body === false ? '' : $body, $err];
}

function extractVersionForSort(string $filename): string {
  // findet z.B. ".v1.1.9d", "-v1.2.0", "_v1.2.0-beta1"
  if (preg_match('~(?:^|[.\-_])v(\d+(?:\.\d+)*[0-9A-Za-z\-\.]*)~', $filename, $m)) {
    return strtolower($m[1]); // ohne führendes v
  }
  return '';
}

function parseNginxAutoindexGrouped(string $html, array $allowedExt): array {
  $dom = new DOMDocument();
  libxml_use_internal_errors(true);
  $dom->loadHTML($html);
  libxml_clear_errors();

  $groups = []; // version => [files...]

  foreach ($dom->getElementsByTagName('a') as $a) {
    $href = (string)$a->getAttribute('href');
    if ($href === '' || $href === '../') continue;

    // remove query/fragment
    $href = preg_replace('~[?#].*$~', '', $href);

    // skip directories
    if (str_ends_with($href, '/')) continue;

    $name = basename($href);

    // sanity
    if ($name === '' || str_contains($name, '/') || str_contains($name, "\0")) continue;

    $ext = strtolower(pathinfo($name, PATHINFO_EXTENSION));
    if (!in_array($ext, $allowedExt, true)) continue;

    $ver = extractVersionForSort($name);
    if ($ver === '') $ver = 'unversioned';

    $groups[$ver][] = $name;
  }

  // Dateien je Version alphabetisch + unique
  foreach ($groups as &$files) {
    $uniq = array_values(array_unique($files));
    natcasesort($uniq);
    $files = array_values($uniq);
  }
  unset($files);

  // Versionen absteigend sortieren (unversioned zuletzt)
  $versions = array_keys($groups);
  usort($versions, function(string $a, string $b): int {
    if ($a === 'unversioned' && $b === 'unversioned') return 0;
    if ($a === 'unversioned') return 1;
    if ($b === 'unversioned') return -1;

    $cmp = version_compare($a, $b);
    if ($cmp === 0) return 0;
    return ($cmp > 0) ? -1 : 1; // DESC
  });

  $sorted = [];
  foreach ($versions as $v) $sorted[$v] = $groups[$v];
  return $sorted;
}

function streamRemoteFile(string $url, string $apiKey, string $downloadName): void {
  $ch = curl_init($url);

  $status = 0;
  $sentHeaders = false;

  curl_setopt_array($ch, [
    CURLOPT_RETURNTRANSFER => false,
    CURLOPT_FOLLOWLOCATION => true,
    CURLOPT_FAILONERROR    => false,
    CURLOPT_CONNECTTIMEOUT => 10,
    CURLOPT_TIMEOUT        => 0, // stream until done
    CURLOPT_HTTPHEADER     => [
      'X-Api-Key: ' . $apiKey,
      'Cache-Control: no-cache',
    ],
  ]);

  // Statuscode aus HTTP-Statuszeile ziehen
  curl_setopt($ch, CURLOPT_HEADERFUNCTION, function($ch, $line) use (&$status, &$sentHeaders, $downloadName) {
    $len = strlen($line);

    if (preg_match('~^HTTP/\S+\s+(\d{3})~i', $line, $m)) {
      $status = (int)$m[1];

      // Nur bei 200 Download-Header setzen
      if ($status === 200 && !$sentHeaders) {
        header('Content-Type: application/zip');
        header('Content-Disposition: attachment; filename="' . $downloadName . '"');
        header('X-Content-Type-Options: nosniff');
        header('Cache-Control: no-store');
        $sentHeaders = true;
      }
    }
    return $len;
  });

  // Body nur bei 200 ausgeben, sonst Fehlertext (kein Fake-Zip)
  curl_setopt($ch, CURLOPT_WRITEFUNCTION, function($ch, $chunk) use (&$status, &$sentHeaders, $url) {
    if ($status !== 200) {
      if (!$sentHeaders) {
        http_response_code($status > 0 ? $status : 502);
        header('Content-Type: text/plain; charset=utf-8');
        echo "Upstream-Fehler (" . ($status ?: 0) . ") beim Abruf von:\n$url\n";
        $sentHeaders = true;
      }
      return strlen($chunk); // verwerfen
    }

    echo $chunk;
    return strlen($chunk);
  });

  curl_exec($ch);

  if (curl_errno($ch)) {
    if (!headers_sent()) {
      http_response_code(502);
      header('Content-Type: text/plain; charset=utf-8');
    }
    echo "Download-Fehler: " . curl_error($ch) . "\n";
  }

  curl_close($ch);
  exit;
}

// ========= Dateiliste remote holen =========
[$code, $html, $err] = curlGetHtml($REMOTE_DIR, $API_KEY);

if ($code !== 200 || $html === '') {
  http_response_code(502);
  header('Content-Type: text/plain; charset=utf-8');
  echo "Konnte Directory Listing nicht abrufen.\n";
  echo "URL: $REMOTE_DIR\nHTTP: $code\n";
  if ($err !== '') echo "cURL: $err\n";
  exit;
}

$groups = parseNginxAutoindexGrouped($html, $ALLOWED_EXT);

// ========= Download Mode =========
if (isset($_GET['name'])) {
  $name = (string)$_GET['name'];

  // Nur erlauben, was wirklich im Listing vorkam (in irgendeiner Gruppe)
  $allowed = false;
  foreach ($groups as $files) {
    if (in_array($name, $files, true)) { $allowed = true; break; }
  }

  if (!$allowed) {
    http_response_code(404);
    header('Content-Type: text/plain; charset=utf-8');
    echo "Datei nicht gefunden oder nicht erlaubt.\n";
    exit;
  }

  $url = $REMOTE_DIR . rawurlencode($name);
  streamRemoteFile($url, $API_KEY, $name);
}

// ========= HTML Listing =========
header('Content-Type: text/html; charset=utf-8');

echo "<!doctype html><html><head><meta charset='utf-8'>";
echo "<meta name='viewport' content='width=device-width, initial-scale=1'>";
echo "<title>Updater Downloads</title>";
echo "<style>
  body{font-family:system-ui,-apple-system,Segoe UI,Roboto,Arial,sans-serif;margin:24px;max-width:900px}
  ul{padding-left:18px}
  li{margin:10px 0}
  h2{margin-top:22px}
  code{background:#f4f4f4;padding:2px 6px;border-radius:6px}
</style></head><body>";

echo "<h1>Updater Downloads</h1>";

if (!$groups) {
  echo "<p><strong>Keine .zip Dateien gefunden.</strong></p>";
  echo "</body></html>";
  exit;
}

foreach ($groups as $ver => $files) {
  $title = ($ver === 'unversioned') ? 'Ohne Version' : ('v' . $ver);
  echo "<h2>" . h($title) . "</h2>";
  echo "<ul>";
  foreach ($files as $fn) {
    $href = "download.php?name=" . rawurlencode($fn);
    echo "<li><a href='" . h($href) . "'>" . h($fn) . "</a></li>";
  }
  echo "</ul>";
}

echo "</body></html>";
