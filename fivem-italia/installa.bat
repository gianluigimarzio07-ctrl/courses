@echo off
REM ===========================================================================
REM   AUREA - Italia Roleplay - preparazione della cartella del server
REM
REM   Scarica le due cose che AUREA non puo' contenere e senza le quali il
REM   server non parte: le risorse di sistema di FiveM (mapmanager, chat,
REM   spawnmanager, sessionmanager, basic-gamemode, hardcap) e oxmysql.
REM
REM   Si lancia UNA VOLTA, con doppio clic o da prompt, dentro questa cartella.
REM   Non tocca nulla di AUREA: se una risorsa esiste gia', la salta.
REM ===========================================================================

setlocal
cd /d "%~dp0"

if not exist "server.cfg" (
    echo [ERRORE] Lancia questo file dentro la cartella di AUREA, quella con server.cfg.
    pause
    exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference='Stop';" ^
  "$qui=(Get-Location).Path; $res=Join-Path $qui 'resources';" ^
  "$tmp=Join-Path $env:TEMP ('aurea_'+[guid]::NewGuid().ToString('N'));" ^
  "New-Item -ItemType Directory -Path $tmp | Out-Null;" ^
  "try {" ^
    "Write-Host '';" ^
    "Write-Host '[1/2] Risorse di sistema di FiveM (cfx-server-data)' -ForegroundColor Green;" ^
    "if ((Test-Path (Join-Path $res '[managers]')) -or (Test-Path (Join-Path $res '[system]'))) {" ^
      "Write-Host '      gia'' presenti, salto.' -ForegroundColor Yellow" ^
    "} else {" ^
      "Write-Host '      scarico...';" ^
      "Invoke-WebRequest -UseBasicParsing 'https://github.com/citizenfx/cfx-server-data/archive/refs/heads/master.zip' -OutFile (Join-Path $tmp 'cfx.zip');" ^
      "Expand-Archive -Path (Join-Path $tmp 'cfx.zip') -DestinationPath (Join-Path $tmp 'cfx') -Force;" ^
      "$src=Get-ChildItem -Path (Join-Path $tmp 'cfx') -Recurse -Directory -Filter 'resources' | Select-Object -First 1;" ^
      "if (-not $src) { throw 'archivio inatteso: non trovo la cartella resources' };" ^
      "foreach ($c in Get-ChildItem -Path $src.FullName) {" ^
        "$dest=Join-Path $res $c.Name;" ^
        "if (Test-Path $dest) { Write-Host ('      '+$c.Name+' esiste gia'', salto') -ForegroundColor Yellow }" ^
        "else { Copy-Item -Path $c.FullName -Destination $dest -Recurse; Write-Host ('      + '+$c.Name) }" ^
      "};" ^
      "Write-Host '      fatto.' -ForegroundColor Green" ^
    "};" ^
    "Write-Host '';" ^
    "Write-Host '[2/2] oxmysql' -ForegroundColor Green;" ^
    "if (Test-Path (Join-Path $res 'oxmysql')) {" ^
      "Write-Host '      gia'' presente, salto.' -ForegroundColor Yellow" ^
    "} else {" ^
      "Write-Host '      scarico l''ultima release...';" ^
      "Invoke-WebRequest -UseBasicParsing 'https://github.com/overextended/oxmysql/releases/latest/download/oxmysql.zip' -OutFile (Join-Path $tmp 'ox.zip');" ^
      "Expand-Archive -Path (Join-Path $tmp 'ox.zip') -DestinationPath (Join-Path $tmp 'ox') -Force;" ^
      "$man=Get-ChildItem -Path (Join-Path $tmp 'ox') -Recurse -Filter 'fxmanifest.lua' | Select-Object -First 1;" ^
      "if (-not $man) { throw 'archivio inatteso: non trovo fxmanifest.lua' };" ^
      "Copy-Item -Path $man.Directory.FullName -Destination (Join-Path $res 'oxmysql') -Recurse;" ^
      "Write-Host '      fatto.' -ForegroundColor Green" ^
    "};" ^
    "Write-Host '';" ^
    "Write-Host 'Verifica' -ForegroundColor Green;" ^
    "$manca=$false;" ^
    "foreach ($r in @('mapmanager','chat','spawnmanager','sessionmanager','basic-gamemode','hardcap','oxmysql')) {" ^
      "if (Get-ChildItem -Path $res -Recurse -Directory -Filter $r -ErrorAction SilentlyContinue | Select-Object -First 1) {" ^
        "Write-Host ('      OK  '+$r)" ^
      "} else { Write-Host ('      MANCA  '+$r) -ForegroundColor Red; $manca=$true }" ^
    "};" ^
    "Write-Host '';" ^
    "if ($manca) { Write-Host 'Qualcosa non e'' arrivato: controlla la connessione e rilancia.' -ForegroundColor Red; exit 1 };" ^
    "Write-Host 'Tutto a posto. Restano tre cose da fare a mano, in server.cfg:' -ForegroundColor Green;" ^
    "Write-Host '  - sv_licenseKey            la chiave da https://keymaster.fivem.net';" ^
    "Write-Host '  - mysql_connection_string  utente, password e nome del database';" ^
    "Write-Host '  - add_principal            la tua license, per i permessi da fondatore'" ^
  "} finally { Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue }"

echo.
pause
