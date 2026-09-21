@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul

rem  AUREA · Italia Roleplay — preparazione della cartella del server (Windows)
rem
rem  Le risorse ci sono già tutte. Quelle di base — mapmanager, spawnmanager,
rem  baseevents e oxmysql — stanno in resources\[base]\ e sono incluse nel
rem  pacchetto. Il LEGGIMI lì dentro dice da dove vengono e con che licenza.
rem
rem  Quello che manca è soltanto l'ESEGUIBILE DI FXSERVER: il programma che
rem  fa girare il server. Pesa qualche centinaio di megabyte e Cfx.re ne
rem  pubblica una versione nuova quasi ogni settimana, quindi si scarica
rem  adesso invece di consegnarne una copia già vecchia.
rem
rem  GTA V non c'entra e non serve: il gioco ce l'ha ogni giocatore sul
rem  proprio computer. Un server FiveM non lo contiene.

cd /d "%~dp0"

if not exist "server.cfg" goto :postosbagliato
if not exist "resources" goto :postosbagliato

echo.
echo [1/2] Controllo delle risorse di base

set MANCANTI=
for %%R in (mapmanager spawnmanager baseevents oxmysql) do (
    if not exist "resources\[base]\%%R" set MANCANTI=!MANCANTI! %%R
)

if not "!MANCANTI!"=="" (
    echo       mancano da resources\[base]\:!MANCANTI!
    echo       il pacchetto e' incompleto. Riscarica AUREA.
    pause
    exit /b 1
)
echo       ci sono tutte.

echo.
echo [2/2] Eseguibile di FXServer

if exist "..\fxserver\FXServer.exe" (
    echo       gia' presente, salto.
    goto :fine
)

echo.
echo       Questo pezzo va scaricato a mano, ed e' un minuto di lavoro:
echo.
echo       1. apri  https://runtime.fivem.net/artifacts/fivem/build_server_windows/master/
echo       2. scarica la build piu' recente contrassegnata come consigliata
echo       3. scompatta server.zip in una cartella "fxserver" accanto a questa
echo.
echo       Non lo facciamo noi perche' su Windows servirebbe PowerShell con
echo       permessi che non e' detto tu voglia dare a uno script scaricato.
echo.

:fine
echo.
echo Restano due cose da fare a mano, e non le puo' fare uno script:
echo.
echo   1. il database:
echo        mysql -u utente -p nome_database ^< sql\01_schema.sql
echo        mysql -u utente -p nome_database ^< sql\02_dati_iniziali.sql
echo      poi metti la stringa di connessione in server.cfg.
echo.
echo   2. la chiave del server: generala su https://keymaster.fivem.net
echo      e incollala in sv_licenseKey dentro server.cfg.
echo.
echo Poi si avvia cosi', dalla cartella fxserver:
echo.
echo      FXServer.exe +exec "%~dp0server.cfg"
echo.
pause
exit /b 0

:postosbagliato
echo Questo script va lanciato dentro la cartella di AUREA (quella con server.cfg e resources\).
pause
exit /b 1
