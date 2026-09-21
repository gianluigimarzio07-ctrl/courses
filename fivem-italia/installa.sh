#!/usr/bin/env bash
#
#  AUREA · Italia Roleplay — preparazione della cartella del server
#
#  Le risorse ci sono già tutte. Quelle di base — mapmanager, spawnmanager,
#  baseevents e oxmysql — stanno in resources/[base]/ e sono incluse nel
#  pacchetto: vedi il LEGGIMI lì dentro per da dove vengono, con che licenza
#  e perché pma-voice e screenshot-basic non ci sono.
#
#  Quello che manca, e che questo script scarica, è una cosa sola:
#  l'ESEGUIBILE DI FXSERVER. È il programma che fa girare il server, pesa
#  qualche centinaio di megabyte e Cfx.re ne pubblica una versione nuova
#  quasi ogni settimana. Congelarne una copia qui dentro vorrebbe dire
#  consegnare qualcosa di già vecchio.
#
#  GTA V non c'entra e non serve: il gioco ce l'ha ogni giocatore sul
#  proprio computer. Un server FiveM non lo contiene.
#
#  Uso:
#      chmod +x installa.sh
#      ./installa.sh
#
set -euo pipefail

ARTEFATTI='https://runtime.fivem.net/artifacts/fivem/build_proot_linux/master/'

qui="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

verde()  { printf '\033[32m%s\033[0m\n' "$*"; }
giallo() { printf '\033[33m%s\033[0m\n' "$*"; }
rosso()  { printf '\033[31m%s\033[0m\n' "$*"; }

if [[ ! -d "$qui/resources" ]] || [[ ! -f "$qui/server.cfg" ]]; then
    rosso "Questo script va lanciato dentro la cartella di AUREA (quella con server.cfg e resources/)."
    exit 1
fi

# ---------------------------------------------------------------------------
#  Controllo di quello che dovrebbe già esserci
# ---------------------------------------------------------------------------
echo
verde '[1/2] Controllo delle risorse di base'

mancanti=()
for r in mapmanager spawnmanager baseevents oxmysql; do
    [[ -d "$qui/resources/[base]/$r" ]] || mancanti+=("$r")
done

if (( ${#mancanti[@]} )); then
    rosso "      mancano da resources/[base]/: ${mancanti[*]}"
    rosso '      il pacchetto è incompleto. Riscarica AUREA.'
    exit 1
fi
verde '      ci sono tutte.'

# ---------------------------------------------------------------------------
#  L'eseguibile di FXServer
# ---------------------------------------------------------------------------
echo
verde '[2/2] Eseguibile di FXServer'

if [[ -f "$qui/../run.sh" ]] || [[ -f "$qui/run.sh" ]] || [[ -f "$qui/FXServer" ]]; then
    giallo '      già presente, salto.'
    echo
    verde 'Tutto pronto.'
    exit 0
fi

for strumento in curl tar; do
    command -v "$strumento" >/dev/null 2>&1 || { rosso "Manca $strumento. Installalo e riprova."; exit 1; }
done

echo "      cerco l'ultima build su Cfx.re..."

pagina="$(curl -fsSL "$ARTEFATTI" 2>/dev/null || true)"
if [[ -z "$pagina" ]]; then
    rosso '      non riesco a raggiungere runtime.fivem.net.'
    echo
    echo '      Scaricalo a mano: apri'
    echo "          $ARTEFATTI"
    echo '      prendi la build più recente contrassegnata come consigliata,'
    echo '      scompatta fx.tar.xz in una cartella accanto a questa e avvia'
    echo '      il server da lì con:'
    echo
    echo "          ./run.sh +exec $qui/server.cfg"
    exit 1
fi

percorso="$(printf '%s' "$pagina" | grep -oE '\./[0-9]+-[0-9a-f]+/fx\.tar\.xz' | head -n 1 || true)"
if [[ -z "$percorso" ]]; then
    rosso '      la pagina degli artefatti non ha il formato atteso.'
    echo "      Scaricalo a mano da $ARTEFATTI"
    exit 1
fi

destinazione="$qui/../fxserver"
mkdir -p "$destinazione"

echo "      scarico ${percorso#./}"
curl -fL --progress-bar "${ARTEFATTI}${percorso#./}" -o "$destinazione/fx.tar.xz"

echo '      scompatto...'
tar -xJf "$destinazione/fx.tar.xz" -C "$destinazione"
rm -f "$destinazione/fx.tar.xz"
chmod +x "$destinazione/run.sh" 2>/dev/null || true

echo
verde 'Tutto pronto.'
echo
echo 'Restano due cose da fare a mano, e non le può fare uno script:'
echo
echo '  1. il database:'
echo '       mysql -u utente -p nome_database < sql/01_schema.sql'
echo '       mysql -u utente -p nome_database < sql/02_dati_iniziali.sql'
echo '     poi metti la stringa di connessione in server.cfg.'
echo
echo '  2. la chiave del server: generala su https://keymaster.fivem.net'
echo '     e incollala in sv_licenseKey dentro server.cfg.'
echo
echo 'Poi si avvia così:'
echo
echo "     cd $(cd "$destinazione" 2>/dev/null && pwd || echo '../fxserver')"
echo "     ./run.sh +exec $qui/server.cfg"
echo
