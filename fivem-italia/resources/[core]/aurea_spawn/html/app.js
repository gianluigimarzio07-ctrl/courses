/* ==========================================================================
   AUREA · Selezione personaggio
   ========================================================================== */

const RISORSA = 'aurea_spawn';
const $ = (id) => document.getElementById(id);

const invia = (endpoint, dati = {}) =>
  fetch(`https://${RISORSA}/${endpoint}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(dati),
  }).then((r) => r.json()).catch(() => null);

const escape = (s) => String(s ?? '').replace(/[&<>"']/g, (c) =>
  ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

const euro = (c) => (Number(c || 0) / 100).toLocaleString('it-IT', { style: 'currency', currency: 'EUR' });

const SUGGERIMENTI = [
  'Il codice fiscale che generi è reale nella struttura: lo useranno banca, fisco e forze dell\'ordine.',
  'Le multe arrivano per posta: controlla il telefono, hanno una scadenza.',
  'La patente parte da 20 punti. A zero scatta la revisione e devi rifare l\'esame.',
  'Il bollo e l\'assicurazione scadono davvero: senza, il veicolo può essere sequestrato.',
  'In ZTL i varchi sono attivi a fasce orarie. Il permesso si chiede al Comune.',
  'Un prodotto DOP vale fino a tre volte un prodotto senza certificazione.',
  'Il 112 smista la chiamata all\'ente giusto: descrivi bene l\'emergenza.',
];

let slotMassimi = 2;

/* --------------------------------------------------------------------------
   Elenco personaggi
   -------------------------------------------------------------------------- */
function mostraElenco({ personaggi, slot }) {
  slotMassimi = slot || 2;
  $('pannello-elenco').classList.remove('oculto');
  $('pannello-creazione').classList.add('oculto');

  const contenitore = $('schede');
  contenitore.innerHTML = '';

  personaggi.forEach((pg) => {
    const el = document.createElement('div');
    el.className = 'scheda';
    const ore = Math.floor((pg.minuti_gioco || 0) / 60);
    el.innerHTML = `
      <div class="iniziali">${escape((pg.nome[0] || '') + (pg.cognome[0] || ''))}</div>
      <div class="scheda-corpo">
        <div class="scheda-nome">${escape(pg.nome)} ${escape(pg.cognome)}</div>
        <div class="scheda-meta">
          <span>${escape(pg.citizenid)}</span>
          <span><b>${escape(pg.lavoroEtichetta || 'Disoccupato')}</b></span>
          <span>${euro(pg.contanti)} in tasca</span>
          <span>${ore} h di gioco</span>
        </div>
      </div>
      <button class="elimina" data-id="${escape(pg.citizenid)}">Elimina</button>`;

    el.addEventListener('click', (e) => {
      if (e.target.classList.contains('elimina')) return;
      invia('seleziona', { citizenid: pg.citizenid });
      document.body.classList.add('oculto');
    });

    el.querySelector('.elimina').addEventListener('click', async (e) => {
      e.stopPropagation();
      const bottone = e.target;
      if (bottone.dataset.conferma !== '1') {
        bottone.dataset.conferma = '1';
        bottone.textContent = 'Confermi?';
        setTimeout(() => {
          bottone.dataset.conferma = '0';
          bottone.textContent = 'Elimina';
        }, 4000);
        return;
      }
      await invia('elimina', { citizenid: pg.citizenid });
      const aggiornato = await invia('ricarica', {});
      if (aggiornato) mostraElenco(aggiornato);
    });

    contenitore.appendChild(el);
  });

  if (personaggi.length < slotMassimi) {
    const vuota = document.createElement('div');
    vuota.className = 'scheda vuota';
    vuota.innerHTML = `<span>+ Crea un nuovo personaggio (${personaggi.length}/${slotMassimi})</span>`;
    vuota.addEventListener('click', apriCreazione);
    contenitore.appendChild(vuota);
  }
}

/* --------------------------------------------------------------------------
   Creazione
   -------------------------------------------------------------------------- */
const COMUNI = ['Roma', 'Milano', 'Napoli', 'Torino', 'Palermo', 'Bologna',
                'Firenze', 'Bari', 'Venezia', 'Genova', 'Catania', 'Cagliari'];

function apriCreazione() {
  $('pannello-elenco').classList.add('oculto');
  $('pannello-creazione').classList.remove('oculto');
  $('errore').classList.add('oculto');

  const select = $('comune');
  if (!select.options.length) {
    COMUNI.forEach((c) => select.add(new Option(c, c)));
  }

  const oggi = new Date();
  const maxData = new Date(oggi.getFullYear() - 18, oggi.getMonth(), oggi.getDate());
  const minData = new Date(oggi.getFullYear() - 80, oggi.getMonth(), oggi.getDate());
  $('nascita').max = maxData.toISOString().slice(0, 10);
  $('nascita').min = minData.toISOString().slice(0, 10);
  if (!$('nascita').value) $('nascita').value = `${oggi.getFullYear() - 26}-06-15`;

  invia('anteprimaCamera', {});
  aggiornaAnteprimaCF();
}

/* Calcolo del codice fiscale lato interfaccia: è solo un'anteprima, il valore
   autorevole lo produce il server alla creazione. */
const CATASTALE = {
  Roma: 'H501', Milano: 'F205', Napoli: 'F839', Torino: 'L219', Palermo: 'G273',
  Bologna: 'A944', Firenze: 'D612', Bari: 'A662', Venezia: 'L736', Genova: 'D969',
  Catania: 'C351', Cagliari: 'B354',
};
const MESI = ['A', 'B', 'C', 'D', 'E', 'H', 'L', 'M', 'P', 'R', 'S', 'T'];

function terna(s, isCognome) {
  s = (s || '').toUpperCase().normalize('NFD').replace(/[̀-ͯ]/g, '').replace(/[^A-Z]/g, '');
  const cons = s.replace(/[AEIOU]/g, '');
  const voc = s.replace(/[^AEIOU]/g, '');
  if (!isCognome && cons.length >= 4) return cons[0] + cons[2] + cons[3];
  return (cons + voc + 'XXX').slice(0, 3);
}

function aggiornaAnteprimaCF() {
  const nome = $('nome').value.trim();
  const cognome = $('cognome').value.trim();
  const nascita = $('nascita').value;
  const sesso = $('sesso').value;
  const comune = $('comune').value;

  if (nome.length < 2 || cognome.length < 2 || !nascita) {
    $('cf-anteprima').textContent = '— — —';
    return;
  }

  const [anno, mese, giorno] = nascita.split('-').map(Number);
  const gg = sesso === 'F' ? giorno + 40 : giorno;
  const parziale = terna(cognome, true) + terna(nome, false)
    + String(anno % 100).padStart(2, '0')
    + MESI[mese - 1]
    + String(gg).padStart(2, '0')
    + (CATASTALE[comune] || 'H501');

  $('cf-anteprima').textContent = `${parziale}·`;
}

['nome', 'cognome', 'nascita', 'sesso', 'comune'].forEach((id) => {
  const el = $(id);
  if (el) el.addEventListener('input', aggiornaAnteprimaCF);
});

$('form-creazione').addEventListener('submit', async (e) => {
  e.preventDefault();
  const errore = $('errore');
  errore.classList.add('oculto');

  const dati = {
    nome: $('nome').value.trim(),
    cognome: $('cognome').value.trim(),
    sesso: $('sesso').value,
    dataNascita: $('nascita').value,
    luogoNascita: $('comune').value,
  };

  const risposta = await invia('crea', dati);
  if (!risposta || !risposta.ok) {
    errore.textContent = (risposta && risposta.errore) || 'Creazione non riuscita. Riprova.';
    errore.classList.remove('oculto');
    return;
  }
  document.body.classList.add('oculto');
});

$('annulla-creazione').addEventListener('click', async () => {
  const dati = await invia('ricarica', {});
  if (dati) mostraElenco(dati);
});

/* --------------------------------------------------------------------------
   Messaggi da Lua
   -------------------------------------------------------------------------- */
window.addEventListener('message', ({ data }) => {
  if (data.azione === 'apri') {
    document.body.classList.remove('oculto');
    $('suggerimento').textContent = SUGGERIMENTI[Math.floor(Math.random() * SUGGERIMENTI.length)];
    $('stagione').textContent = data.stagione || '';
    mostraElenco(data);
  } else if (data.azione === 'chiudi') {
    document.body.classList.add('oculto');
  }
});
