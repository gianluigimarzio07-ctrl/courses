#!/usr/bin/env bash
#
#  AUREA · Italia Roleplay — preparazione della cartella del server
#
#  Scarica le due cose che AUREA non può contenere e che senza il server
#  non parte:
#
#    · le risorse di sistema di FiveM (mapmanager, chat, spawnmanager,
#      sessionmanager, basic-gamemode, hardcap) che stanno in cfx-server-data
#    · oxmysql, l'unica dipendenza esterna del framework
#
#  Va lanciato UNA VOLTA, dentro questa cartella:
#
#      chmod +x installa.sh
#      ./installa.sh
#
#  Non tocca nulla di AUREA: se una risorsa esiste già, la salta.
#
set -euo pipefail

CFX_ZIP='https://github.com/citizenfx/cfx-server-data/archive/refs/heads/master.zip'
OX_ZIP='https://github.com/overextended/oxmysql/releases/latest/download/oxmysql.zip'

qui="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
risorse="$qui/resources"

verde() { printf '\033[32m%s\033[0m\n' "$*"; }
giallo() { printf '\033[33m%s\033[0m\n' "$*"; }
rosso() { printf '\033[31m%s\033[0m\n' "$*"; }

if [[ ! -d "$risorse" ]] || [[ ! -f "$qui/server.cfg" ]]; then
    rosso "Questo script va lanciato dentro la cartella di AUREA (quella con server.cfg e resources/)."
    exit 1
fi

for strumento in curl unzip; do
    command -v "$strumento" >/dev/null 2>&1 || { rosso "Manca $strumento. Installalo e riprova."; exit 1; }
done

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# ---------------------------------------------------------------------------
#  1. Risorse di sistema di FiveM
# ---------------------------------------------------------------------------
echo
verde '[1/2] Risorse di sistema di FiveM (cfx-server-data)'

if [[ -d "$risorse/[managers]" ]] || [[ -d "$risorse/[system]" ]]; then
    giallo '      già presenti, salto.'
else
    echo '      scarico...'
    curl -fsSL "$CFX_ZIP" -o "$tmp/cfx.zip"
    unzip -q "$tmp/cfx.zip" -d "$tmp/cfx"

    sorgente="$(find "$tmp/cfx" -maxdepth 2 -type d -name resources | head -n 1)"
    if [[ -z "$sorgente" ]]; then
        rosso '      archivio inatteso: non trovo la cartella resources/.'
        exit 1
    fi

    # Si copia solo quello che non c'è già: AUREA non viene toccata
    for cartella in "$sorgente"/*; do
        nome="$(basename "$cartella")"
        if [[ -e "$risorse/$nome" ]]; then
            giallo "      $nome esiste già, salto"
        else
            cp -R "$cartella" "$risorse/"
            echo "      + $nome"
        fi
    done
    verde '      fatto.'
fi

# ---------------------------------------------------------------------------
#  2. oxmysql
# ---------------------------------------------------------------------------
echo
verde '[2/2] oxmysql'

if [[ -d "$risorse/oxmysql" ]]; then
    giallo '      già presente, salto.'
else
    echo '      scarico l ultima release...'
    curl -fsSL "$OX_ZIP" -o "$tmp/oxmysql.zip"
    unzip -q "$tmp/oxmysql.zip" -d "$tmp/ox"

    # La release può avere o non avere una cartella radice
    if [[ -f "$tmp/ox/fxmanifest.lua" ]]; then
        mv "$tmp/ox" "$risorse/oxmysql"
    else
        interna="$(find "$tmp/ox" -maxdepth 2 -name fxmanifest.lua -print -quit)"
        if [[ -z "$interna" ]]; then
            rosso '      archivio inatteso: non trovo fxmanifest.lua.'
            exit 1
        fi
        mv "$(dirname "$interna")" "$risorse/oxmysql"
    fi
    verde '      fatto.'
fi

# ---------------------------------------------------------------------------
#  Controllo finale
# ---------------------------------------------------------------------------
echo
verde 'Verifica'

manca=0
for r in mapmanager chat spawnmanager sessionmanager basic-gamemode hardcap oxmysql; do
    if find "$risorse" -maxdepth 3 -type d -name "$r" | grep -q .; then
        echo "      ✓ $r"
    else
        rosso "      ✗ $r NON trovata"
        manca=1
    fi
done

echo
if [[ $manca -eq 0 ]]; then
    verde 'Tutto a posto. Restano tre cose da fare a mano, in server.cfg:'
    echo '  · sv_licenseKey      — la chiave da https://keymaster.fivem.net'
    echo '  · mysql_connection_string — utente, password e nome del database'
    echo '  · add_principal      — la tua license, per avere i permessi da fondatore'
    echo
    echo 'E il database, se non lo hai ancora importato:'
    echo '  mysql -u root -p -e "CREATE DATABASE aurea CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"'
    echo '  mysql -u root -p aurea < sql/01_schema.sql'
    echo '  mysql -u root -p aurea < sql/02_dati_iniziali.sql'
else
    rosso 'Qualcosa non è arrivato. Controlla la connessione e rilancia lo script.'
    exit 1
fi
