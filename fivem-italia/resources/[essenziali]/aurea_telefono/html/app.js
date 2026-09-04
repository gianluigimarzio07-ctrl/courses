/* ==========================================================================
   AUREA · Telefono
   ========================================================================== */

const RISORSA = 'aurea_telefono';
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

const APP = [
  { id: 'vista-contatti',  nome: 'Rubrica',    icona: '📇', sfondo: 'linear-gradient(150deg,#3d8bfd,#2a5fb0)' },
  { id: 'vista-messaggi',  nome: 'Messaggi',   icona: '💬', sfondo: 'linear-gradient(150deg,#1f9d55,#157040)', badge: 'messaggi' },
  { id: 'vista-spid',      nome: 'Identità',   icona: '🪪', sfondo: 'linear-gradient(150deg,#d4af37,#9d7f21)' },
  { id: 'vista-banca',     nome: 'Banca',      icona: '🏦', sfondo: 'linear-gradient(150deg,#2f7d5f,#1b4a38)' },
  { id: 'vista-fisco',     nome: 'Fisco',      icona: '🧾', sfondo: 'linear-gradient(150deg,#6b6f7d,#3f434e)', badge: 'fisco' },
  { id: 'vista-annunci',   nome: 'Annunci',    icona: '📢', sfondo: 'linear-gradient(150deg,#c26a2a,#8a4718)' },
  { id: 'vista-112',       nome: 'Emergenze',  icona: '🆘', sfondo: 'linear-gradient(150deg,#cf2e2e,#8d1c1c)' },
];

let stato = { pg: null, conversazioni: [], contatti: [], badge: {} };
let conversazioneAperta = null;

/* --------------------------------------------------------------------------
   Navigazione
   -------------------------------------------------------------------------- */
function vaiA(idVista) {
  document.querySelectorAll('.vista').forEach((v) => v.classList.remove('attiva'));
  $(idVista).classList.add('attiva');

  if (idVista === 'vista-contatti') caricaContatti();
  if (idVista === 'vista-messaggi') caricaConversazioni();
  if (idVista === 'vista-banca') caricaBanca();
  if (idVista === 'vista-fisco') caricaFisco();
  if (idVista === 'vista-annunci') caricaAnnunci();
}

document.querySelectorAll('.indietro').forEach((b) => {
  b.addEventListener('click', () => vaiA(b.dataset.torna || 'vista-home'));
});

function disegnaHome() {
  const griglia = $('app-griglia');
  griglia.innerHTML = '';

  APP.forEach((app) => {
    const conteggio = app.badge ? (stato.badge[app.badge] || 0) : 0;
    const el = document.createElement('div');
    el.className = 'app';
    el.innerHTML = `
      <div class="app-icona" style="background:${app.sfondo}">${app.icona}</div>
      ${conteggio > 0 ? `<span class="app-pastiglia">${conteggio > 99 ? '99+' : conteggio}</span>` : ''}
      <span>${app.nome}</span>`;
    el.addEventListener('click', () => vaiA(app.id));
    griglia.appendChild(el);
  });
}

/* --------------------------------------------------------------------------
   Rubrica
   -------------------------------------------------------------------------- */
async function caricaContatti() {
  const dati = await invia('contatti');
  stato.contatti = (dati && dati.contatti) || [];

  const lista = $('lista-contatti');
  lista.innerHTML = '';

  if (stato.contatti.length === 0) {
    lista.innerHTML = '<p class="vuoto">Rubrica vuota.<br>Tocca ＋ per aggiungere un contatto.</p>';
    return;
  }

  stato.contatti.forEach((c) => {
    const el = document.createElement('div');
    el.className = 'riga';
    el.innerHTML = `
      <div class="riga-avatar">${escape(c.nome[0] || '?')}</div>
      <div class="riga-corpo">
        <div class="riga-titolo">${escape(c.nome)}</div>
        <div class="riga-sotto">${escape(c.numero)}</div>
      </div>`;
    el.addEventListener('click', () => apriConversazione(c.numero, c.nome));
    lista.appendChild(el);
  });
}

$('nuovo-contatto').addEventListener('click', async () => {
  const risposta = await invia('dialogo', {
    titolo: 'Nuovo contatto',
    campi: [
      { etichetta: 'Nome', tipo: 'text', obbligatorio: true },
      { etichetta: 'Numero', tipo: 'text', segnaposto: '3401234567', obbligatorio: true },
    ],
  });
  if (risposta && risposta.valori) {
    await invia('salvaContatto', { nome: risposta.valori[0], numero: risposta.valori[1] });
    caricaContatti();
  }
});

/* --------------------------------------------------------------------------
   Messaggi
   -------------------------------------------------------------------------- */
async function caricaConversazioni() {
  const dati = await invia('conversazioni');
  stato.conversazioni = (dati && dati.conversazioni) || [];

  const lista = $('lista-conversazioni');
  lista.innerHTML = '';

  if (stato.conversazioni.length === 0) {
    lista.innerHTML = '<p class="vuoto">Nessun messaggio.<br>Tocca ✎ per scriverne uno.</p>';
    return;
  }

  stato.conversazioni.forEach((c) => {
    const el = document.createElement('div');
    el.className = 'riga';
    el.innerHTML = `
      <div class="riga-avatar">${escape((c.nome || c.numero)[0])}</div>
      <div class="riga-corpo">
        <div class="riga-titolo">${escape(c.nome || c.numero)}</div>
        <div class="riga-sotto">${escape(c.ultimo)}</div>
      </div>
      ${c.nonLetti > 0 ? `<span class="app-pastiglia" style="position:static;margin:0">${c.nonLetti}</span>` : ''}`;
    el.addEventListener('click', () => apriConversazione(c.numero, c.nome));
    lista.appendChild(el);
  });
}

async function apriConversazione(numero, nome) {
  conversazioneAperta = numero;
  $('titolo-conversazione').textContent = nome || numero;
  vaiA('vista-conversazione');

  const dati = await invia('messaggi', { numero });
  const bolle = $('bolle');
  bolle.innerHTML = '';

  ((dati && dati.messaggi) || []).forEach((m) => {
    const el = document.createElement('div');
    const classe = m.sistema ? 'sistema' : (m.mio ? 'mia' : 'loro');
    el.className = `bolla ${classe}`;
    el.innerHTML = `${escape(m.testo)}<span class="bolla-ora">${escape(m.quando)}</span>`;
    bolle.appendChild(el);
  });

  bolle.scrollTop = bolle.scrollHeight;
}

$('form-messaggio').addEventListener('submit', async (e) => {
  e.preventDefault();
  const campo = $('testo-messaggio');
  const testo = campo.value.trim();
  if (!testo || !conversazioneAperta) return;

  campo.value = '';
  await invia('inviaMessaggio', { numero: conversazioneAperta, testo });
  apriConversazione(conversazioneAperta, $('titolo-conversazione').textContent);
});

$('nuovo-messaggio').addEventListener('click', async () => {
  const risposta = await invia('dialogo', {
    titolo: 'Nuovo messaggio',
    campi: [{ etichetta: 'Numero del destinatario', tipo: 'text', segnaposto: '3401234567', obbligatorio: true }],
  });
  if (risposta && risposta.valori) apriConversazione(risposta.valori[0], null);
});

/* --------------------------------------------------------------------------
   SPID
   -------------------------------------------------------------------------- */
function disegnaSpid() {
  if (!stato.pg) return;
  $('spid-nome').textContent = `${stato.pg.nome} ${stato.pg.cognome}`;
  $('spid-cf').textContent = stato.pg.cf;
  $('spid-nascita').textContent = stato.pg.dataNascita;
  $('spid-luogo').textContent = stato.pg.luogoNascita;
  $('spid-citizenid').textContent = stato.pg.citizenid;

  const lista = $('spid-documenti');
  lista.innerHTML = '';
  (stato.pg.documenti || []).forEach((d) => {
    const el = document.createElement('div');
    el.className = 'riga';
    el.innerHTML = `
      <div class="riga-avatar">${escape(d.icona || '📄')}</div>
      <div class="riga-corpo">
        <div class="riga-titolo">${escape(d.titolo)}</div>
        <div class="riga-sotto">${escape(d.dettaglio)}</div>
      </div>
      ${d.valore ? `<span class="riga-valore">${escape(d.valore)}</span>` : ''}`;
    lista.appendChild(el);
  });
}

/* --------------------------------------------------------------------------
   Banca
   -------------------------------------------------------------------------- */
async function caricaBanca() {
  const dati = await invia('banca');
  if (!dati) return;

  $('banca-saldo').textContent = euro(dati.saldo);
  $('banca-iban').textContent = dati.iban || '';

  const lista = $('banca-movimenti');
  lista.innerHTML = '';

  if (!dati.movimenti || dati.movimenti.length === 0) {
    lista.innerHTML = '<p class="vuoto">Nessun movimento registrato.</p>';
    return;
  }

  dati.movimenti.forEach((m) => {
    const el = document.createElement('div');
    el.className = 'riga';
    el.innerHTML = `
      <div class="riga-avatar">${m.importo > 0 ? '⬆' : '⬇'}</div>
      <div class="riga-corpo">
        <div class="riga-titolo">${escape(m.causale)}</div>
        <div class="riga-sotto">${escape(m.quando)}</div>
      </div>
      <span class="riga-valore ${m.importo > 0 ? 'positivo' : 'negativo'}">${m.importo > 0 ? '+' : ''}${euro(m.importo)}</span>`;
    lista.appendChild(el);
  });
}

/* --------------------------------------------------------------------------
   Fisco
   -------------------------------------------------------------------------- */
async function caricaFisco() {
  const dati = await invia('fisco');
  const lista = $('fisco-lista');
  lista.innerHTML = '';

  const voci = (dati && dati.voci) || [];
  if (voci.length === 0) {
    lista.innerHTML = '<p class="vuoto">Posizione regolare.<br>Nessun tributo o verbale pendente.</p>';
    return;
  }

  voci.forEach((v) => {
    const el = document.createElement('div');
    el.className = 'riga';
    el.innerHTML = `
      <div class="riga-avatar">${escape(v.icona)}</div>
      <div class="riga-corpo">
        <div class="riga-titolo">${escape(v.titolo)}</div>
        <div class="riga-sotto">${escape(v.dettaglio)}</div>
      </div>
      <span class="riga-valore negativo">${euro(v.importo)}</span>`;
    lista.appendChild(el);
  });
}

/* --------------------------------------------------------------------------
   Annunci
   -------------------------------------------------------------------------- */
async function caricaAnnunci() {
  const dati = await invia('annunci');
  const lista = $('lista-annunci');
  lista.innerHTML = '';

  const annunci = (dati && dati.annunci) || [];
  if (annunci.length === 0) {
    lista.innerHTML = '<p class="vuoto">Nessun annuncio pubblicato.<br>Tocca ＋ per pubblicarne uno.</p>';
    return;
  }

  annunci.forEach((a) => {
    const el = document.createElement('div');
    el.className = 'riga';
    el.innerHTML = `
      <div class="riga-avatar">📢</div>
      <div class="riga-corpo">
        <div class="riga-titolo">${escape(a.titolo)}</div>
        <div class="riga-sotto">${escape(a.testo)} — ${escape(a.numero)}</div>
      </div>
      ${a.prezzo > 0 ? `<span class="riga-valore">${euro(a.prezzo)}</span>` : ''}`;
    el.addEventListener('click', () => apriConversazione(a.numero, a.titolo));
    lista.appendChild(el);
  });
}

$('nuovo-annuncio').addEventListener('click', async () => {
  const risposta = await invia('dialogo', {
    titolo: 'Pubblica un annuncio',
    campi: [
      { etichetta: 'Titolo', tipo: 'text', obbligatorio: true },
      { etichetta: 'Testo', tipo: 'textarea', obbligatorio: true },
      { etichetta: 'Prezzo in euro (0 se non applicabile)', tipo: 'text', valore: '0' },
      { etichetta: 'Categoria', tipo: 'select', opzioni: [
        { valore: 'generale', etichetta: 'Generale' },
        { valore: 'lavoro', etichetta: 'Offerte di lavoro' },
        { valore: 'veicoli', etichetta: 'Veicoli' },
        { valore: 'immobili', etichetta: 'Immobili' },
        { valore: 'servizi', etichetta: 'Servizi' },
      ] },
    ],
  });
  if (risposta && risposta.valori) {
    await invia('pubblicaAnnuncio', {
      titolo: risposta.valori[0], testo: risposta.valori[1],
      prezzo: risposta.valori[2], categoria: risposta.valori[3],
    });
    caricaAnnunci();
  }
});

/* --------------------------------------------------------------------------
   Emergenze
   -------------------------------------------------------------------------- */
document.querySelectorAll('.emergenza').forEach((b) => {
  b.addEventListener('click', () => {
    invia('chiamaEmergenza', { numero: b.dataset.numero });
    chiudi();
  });
});

/* --------------------------------------------------------------------------
   Chiusura e messaggi da Lua
   -------------------------------------------------------------------------- */
function chiudi() {
  document.body.classList.add('oculto');
  invia('chiudi', {});
}

document.addEventListener('keydown', (e) => {
  if (document.body.classList.contains('oculto')) return;
  if (e.key === 'Escape') {
    const attiva = document.querySelector('.vista.attiva');
    if (attiva && attiva.id !== 'vista-home') vaiA('vista-home');
    else chiudi();
  }
});

window.addEventListener('message', ({ data }) => {
  switch (data.azione) {
    case 'apri':
      stato.pg = data.pg;
      stato.badge = data.badge || {};
      $('home-nome').textContent = `${data.pg.nome} ${data.pg.cognome}`;
      $('home-numero').textContent = data.pg.telefono;
      $('ora').textContent = data.ora || '08:00';
      disegnaHome();
      disegnaSpid();
      vaiA('vista-home');
      document.body.classList.remove('oculto');
      break;

    case 'chiudi':
      document.body.classList.add('oculto');
      break;

    case 'ora':
      $('ora').textContent = data.ora;
      break;

    case 'badge':
      stato.badge = data.badge || {};
      if (!document.body.classList.contains('oculto')) disegnaHome();
      break;
  }
});
