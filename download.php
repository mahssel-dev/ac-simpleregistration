<?php
declare(strict_types=1);

// ========= Konfiguration =========
$API_KEY = 'CHANGE_ME_SUPER_LONG_RANDOM';

// Whitelist: nur diese Keys sind erlaubt
$FILES = [
  'win64' => [
    'url'      => 'https://adamnhm.freeddns.org/patches/files/Updater/WowUpdater-win64.zip',
    'filename' => 'WowUpdater-win64.zip',
  ],
  'osx-x64' => [
    'url'      => 'https://adamnhm.freeddns.org/patches/files/Updater/WowUpdater-osx-x64.zip',
    'filename' => 'WowUpdater-osx-x64.zip',
  ],
  'osx-arm64' => [
    'url'      => 'https://adamnhm.freeddns.org/patches/files/Updater/WowUpdater-osx-arm64.zip',
    'filename' => 'WowUpdater-osx-arm64.zip',
  ],
];

// ========= Eingabe prüfen =========
$key = $_GET['file'] ?? '';
if (!isset($FILES[$key])) {
  http_response_code(400);
  header('Content-Type: text/plain; charset=utf-8');
  echo "Ungültige Datei. Erlaubt: " . implode(', ', array_keys($FILES)) . "\n";
  exit;
}

$targetUrl  = $FILES[$key]['url'];
$dlName     = $FILES[$key]['filename'];

// ========= Download via cURL + Header =========
$ch = curl_init($targetUrl);
curl_setopt_array($ch, [
  CURLOPT_RETURNTRANSFER => false,   // wir streamen direkt
  CURLOPT_FOLLOWLOCATION => true,
  CURLOPT_FAILONERROR    => false,
  CURLOPT_HTTPHEADER     => [
    'X-API-Key: ' . $API_KEY,
  ],
  // Optional: Timeouts
  CURLOPT_CONNECTTIMEOUT => 10,
  CURLOPT_TIMEOUT        => 0,        // 0 = kein Timeout (für große Dateien)
]);

// Status-Code vom Upstream abfangen
curl_setopt($ch, CURLOPT_HEADERFUNCTION, function($ch, $headerLine) {
  // Du könntest hier Upstream-Header filtern/weiterreichen, wir ignorieren es bewusst.
  return strlen($headerLine);
});

// Bevor wir Daten senden, setzen wir unsere Response-Header:
header('Content-Type: application/zip');
header('Content-Disposition: attachment; filename="'.$dlName.'"');
header('X-Content-Type-Options: nosniff');

curl_setopt($ch, CURLOPT_WRITEFUNCTION, function($ch, $chunk) {
  echo $chunk;
  return strlen($chunk);
});

curl_exec($ch);

if (curl_errno($ch)) {
  http_response_code(502);
  header('Content-Type: text/plain; charset=utf-8');
  echo "Download-Fehler: " . curl_error($ch) . "\n";
}

curl_close($ch);
