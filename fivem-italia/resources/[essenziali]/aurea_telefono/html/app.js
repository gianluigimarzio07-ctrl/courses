/* ==========================================================================
   AUREA · Telefono

   Questo file non conosce nessuna app. Conosce cinque forme di schermata —
   lista, saldo, tessera, testo, griglia — più la chat, e le disegna.

   È la ragione per cui aggiungere un'app al telefono non richiede di
   toccare né questo file né l'HTML né il CSS: la si descrive in Lua sul
   server e arriva qui già pronta.
   ========================================================================== */

const RISORSA = 'aurea_telefono';
const $ = (id) => document.getElementById(id);

const invia = (endpoint, dati = {}) =>
  fetch(`https://${RISORSA}/${endpoint}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(dati),
  }).then((r) => r.json()).catch(() => null);

const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) =>
  ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

/* --------------------------------------------------------------------------
   Stato
   -------------------------------------------------------------------------- */
let stato = {
  pg: null,
  app: [],
  schermata: null,      // quella aperta adesso
  pila: [],             // per il tasto indietro
  chiamata: null,
};

/* --------------------------------------------------------------------------
   Navigazione
   -------------------------------------------------------------------------- */
function mostraVista(id) {
  document.querySelectorAll('.vista').forEach((v) => v.classList.toggle('attiva', v.id === id));
}

function vaiHome() {
  stato.pila = [];
  stato.schermata = null;
  mostraVista('vista-home');
  disegnaHome();
}

async function apriApp(app, argomenti, impila = true) {
  const schermata = await invia('schermata', { app, argomenti });
  if (!schermata || !schermata.tipo) return;

  if (impila && stato.schermata) {
    stato.pila.push({ app: stato.schermata.app, argomenti: stato.schermata.argomentiUsati });
  }

  schermata.argomentiUsati = argomenti;
  stato.schermata = schermata;
  mostraVista('vista-app');
  disegnaSchermata(schermata);
}

async function ricarica() {
  if (!stato.schermata) return;
  const s = await invia('schermata', {
    app: stato.schermata.app,
    argomenti: stato.schermata.argomentiUsati,
  });
  if (!s || !s.tipo) return;
  s.argomentiUsati = stato.schermata.argomentiUsati;
  stato.schermata = s;
  disegnaSchermata(s);
}

$('app-indietro').addEventListener('click', () => {
  const precedente = stato.pila.pop();
  if (precedente) {
    apriApp(precedente.app, precedente.argomenti, false);
  } else {
    vaiHome();
  }
});

$('barra-home').addEventListener('click', vaiHome);

/* --------------------------------------------------------------------------
   Home
   -------------------------------------------------------------------------- */
function disegnaHome() {
  $('home-nome').textContent = stato.pg?.nome || '—';
  $('home-numero').textContent = stato.pg?.numero || '—';

  const griglia = $('app-griglia');
  griglia.innerHTML = '';

  stato.app.forEach((app) => {
    const el = document.createElement('div');
    el.className = 'app';
    el.innerHTML = `
      <div class="app-icona" style="background:${esc(app.colore)}">${esc(app.icona)}</div>
      ${app.badge > 0 ? `<span class="app-pastiglia">${app.badge > 99 ? '99+' : app.badge}</span>` : ''}
      <span>${esc(app.nome)}</span>`;
    el.addEventListener('click', () => apriApp(app.id, null, false));
    griglia.appendChild(el);
  });
}

/* --------------------------------------------------------------------------
   Le cinque forme di schermata
   -------------------------------------------------------------------------- */
function disegnaSchermata(s) {
  $('app-titolo').textContent = s.titolo || '';
  $('app-sottotitolo').textContent = s.sottotitolo || '';

  /* Barra delle azioni in testata */
  const barra = $('app-barra');
  barra.innerHTML = '';
  (s.barra || []).forEach((b) => {
    const bottone = document.createElement('button');
    bottone.className = 'azione';
    bottone.textContent = `${b.icona || ''} ${b.etichetta || ''}`.trim();
    bottone.addEventListener('click', () => eseguiAzione(s.app, b.id, b.dati));
    barra.appendChild(bottone);
  });

  const corpo = $('app-corpo');
  corpo.innerHTML = '';
  $('form-chat').classList.toggle('oculto', s.tipo !== 'chat');

  if (s.tipo === 'saldo') {
    corpo.appendChild(cartaSaldo(s));
  } else if (s.tipo === 'tessera') {
    corpo.appendChild(cartaTessera(s.tessera || {}));
  } else if (s.tipo === 'testo') {
    const p = document.createElement('div');
    p.className = 'testo-lungo';
    p.textContent = s.corpo || '';
    corpo.appendChild(p);
    return;
  } else if (s.tipo === 'griglia') {
    corpo.appendChild(griglia(s));
    if (s.nota) {
      const nota = document.createElement('p');
      nota.className = 'nota-piede';
      nota.textContent = s.nota;
      corpo.appendChild(nota);
    }
    return;
  } else if (s.tipo === 'chat') {
    disegnaChat(s, corpo);
    return;
  }

  /* lista, e la coda di saldo/tessera */
  const voci = s.voci || [];
  if (voci.length === 0) {
    const vuoto = document.createElement('p');
    vuoto.className = 'vuoto';
    vuoto.textContent = 'Niente da mostrare.';
    corpo.appendChild(vuoto);
    return;
  }

  voci.forEach((v) => corpo.appendChild(riga(s.app, v)));
}

function riga(app, v) {
  const el = document.createElement('div');
  el.className = `riga${v.inerte ? ' inerte' : ''}${v.tono ? ' tono-' + v.tono : ''}`;

  el.innerHTML = `
    ${v.icona ? `<div class="riga-icona">${esc(v.icona)}</div>` : ''}
    <div class="riga-corpo">
      <div class="riga-titolo">${esc(v.titolo)}</div>
      ${v.sottotitolo ? `<div class="riga-sotto">${esc(v.sottotitolo)}</div>` : ''}
    </div>
    ${v.badge ? `<span class="riga-badge">${v.badge > 99 ? '99+' : v.badge}</span>` : ''}
    ${v.valore ? `<div class="riga-valore">${esc(v.valore)}</div>` : ''}`;

  if (!v.inerte) {
    el.addEventListener('click', () => {
      if (v.apri) return apriApp(app, v.apri);
      if (v.azione) return eseguiAzione(app, v.azione, v.dati);
    });
  }

  return el;
}

function cartaSaldo(s) {
  const el = document.createElement('div');
  el.className = 'saldo-card';
  el.innerHTML = `
    <span>${esc(s.etichetta || '')}</span>
    <strong>${esc(s.valore || '')}</strong>
    <small>${esc(s.nota || '')}</small>`;
  return el;
}

function cartaTessera(t) {
  const el = document.createElement('div');
  el.className = 'tessera';
  el.innerHTML = `
    <div class="tessera-etichetta">${esc(t.etichetta || 'Documento')}</div>
    <h3>${esc(t.nome || '—')}</h3>
    <dl>${(t.righe || []).map((r) =>
      `<div><dt>${esc(r.chiave)}</dt><dd>${esc(r.valore)}</dd></div>`).join('')}</dl>`;
  return el;
}

function griglia(s) {
  const el = document.createElement('div');
  el.className = 'riquadri';

  (s.voci || []).forEach((v) => {
    const b = document.createElement('div');
    b.className = `riquadro${v.tono ? ' tono-' + v.tono : ''}`;
    b.innerHTML = `<strong>${esc(v.titolo)}</strong><span>${esc(v.sottotitolo || '')}</span>`;
    if (!v.inerte) {
      b.addEventListener('click', () => eseguiAzione(s.app, v.azione, v.dati));
    }
    el.appendChild(b);
  });

  return el;
}

/* --------------------------------------------------------------------------
   Chat
   -------------------------------------------------------------------------- */
function disegnaChat(s, corpo) {
  (s.bolle || []).forEach((b) => {
    const el = document.createElement('div');
    el.className = `bolla ${b.mio ? 'mia' : 'sua'}${b.sistema ? ' sistema' : ''}`;
    el.innerHTML = `${esc(b.testo)}<span class="bolla-ora">${esc(b.quando)}</span>`;
    corpo.appendChild(el);
  });

  if ((s.bolle || []).length === 0) {
    const vuoto = document.createElement('p');
    vuoto.className = 'vuoto';
    vuoto.textContent = 'Nessun messaggio.\nScrivi qui sotto per iniziare.';
    corpo.appendChild(vuoto);
  }

  corpo.scrollTop = corpo.scrollHeight;
  $('chat-testo').focus();
}

$('form-chat').addEventListener('submit', async (e) => {
  e.preventDefault();
  const campo = $('chat-testo');
  const testo = campo.value.trim();
  if (!testo || !stato.schermata || !stato.schermata.numero) return;

  campo.value = '';
  await invia('azione', {
    app: stato.schermata.app,
    azione: 'invia',
    dati: { numero: stato.schermata.numero, testo },
  });
  ricarica();
});

/* --------------------------------------------------------------------------
   Azioni
   -------------------------------------------------------------------------- */
async function eseguiAzione(app, azione, dati) {
  if (!azione) return;

  const r = await invia('azione', { app, azione, dati });
  if (!r) return;

  /* Un'app può chiedere un modulo prima di procedere */
  if (r.dialogo) {
    const risposta = await invia('dialogo', {
      titolo: r.dialogo.titolo,
      campi: r.dialogo.campi,
    });
    if (!risposta || !risposta.valori) return;

    const payload = {};
    const chiavi = r.dialogo.chiavi || (r.dialogo.chiave ? [r.dialogo.chiave] : []);
    chiavi.forEach((k, i) => { payload[k] = risposta.valori[i]; });

    return eseguiAzione(app, r.dialogo.azione, Object.assign({}, dati, payload));
  }

  /* …oppure un foglio di scelta */
  if (r.scelta) {
    return apriFoglio(app, r.scelta);
  }

  if (r.messaggio) avviso(r.messaggio, r.ok);

  if (r.vaiA) return apriApp(r.vaiA.app, r.vaiA.argomenti);
  if (r.ricarica) return ricarica();
}

/* --------------------------------------------------------------------------
   Foglio di scelta
   -------------------------------------------------------------------------- */
function apriFoglio(app, scelta) {
  $('foglio-titolo').textContent = scelta.titolo || '';

  const contenitore = $('foglio-voci');
  contenitore.innerHTML = '';

  (scelta.voci || []).forEach((v) => {
    const el = document.createElement('div');
    el.className = 'riga';
    el.innerHTML = `
      ${v.icona ? `<div class="riga-icona">${esc(v.icona)}</div>` : ''}
      <div class="riga-corpo"><div class="riga-titolo">${esc(v.titolo)}</div></div>`;
    el.addEventListener('click', () => {
      chiudiFoglio();
      eseguiAzione(app, v.id, v.dati);
    });
    contenitore.appendChild(el);
  });

  $('foglio').classList.remove('oculto');
}

function chiudiFoglio() { $('foglio').classList.add('oculto'); }
$('foglio-annulla').addEventListener('click', chiudiFoglio);

/* --------------------------------------------------------------------------
   Avviso a scomparsa
   -------------------------------------------------------------------------- */
let timerAvviso = null;

function avviso(testo, ok) {
  const el = $('brindisi');
  el.textContent = testo;
  el.className = `brindisi ${ok ? 'ok' : 'no'}`;

  clearTimeout(timerAvviso);
  timerAvviso = setTimeout(() => el.classList.add('oculto'), 4200);
}

/* --------------------------------------------------------------------------
   Chiamate
   -------------------------------------------------------------------------- */
function disegnaChiamata() {
  const c = stato.chiamata;
  const vista = $('chiamata');

  if (!c) {
    vista.classList.add('oculto');
    return;
  }

  vista.classList.remove('oculto');
  $('chiamata-iniziale').textContent = (c.nome || '?').charAt(0).toUpperCase();
  $('chiamata-nome').textContent = c.nome || c.numero || '—';
  $('chiamata-numero').textContent = c.numero || '';
  $('chiamata-stato').textContent = c.attiva
    ? 'In conversazione'
    : (c.entrante ? 'Chiamata in arrivo…' : 'Sta squillando…');

  const tasti = $('chiamata-tasti');
  tasti.innerHTML = '';

  if (c.entrante && !c.attiva) {
    const rifiuta = document.createElement('button');
    rifiuta.className = 'tasto-chiamata rifiuta';
    rifiuta.textContent = '✕';
    rifiuta.addEventListener('click', () => invia('rispondiChiamata', { accetta: false }));

    const accetta = document.createElement('button');
    accetta.className = 'tasto-chiamata accetta';
    accetta.textContent = '📞';
    accetta.addEventListener('click', () => invia('rispondiChiamata', { accetta: true }));

    tasti.append(rifiuta, accetta);
  } else {
    const chiudi = document.createElement('button');
    chiudi.className = 'tasto-chiamata rifiuta';
    chiudi.textContent = '✕';
    chiudi.addEventListener('click', () => invia('riaggancia'));
    tasti.appendChild(chiudi);
  }
}

/* --------------------------------------------------------------------------
   Messaggi dal client
   -------------------------------------------------------------------------- */
window.addEventListener('message', (evento) => {
  const d = evento.data;

  if (d.azione === 'apri') {
    stato.pg = d.pg;
    stato.app = d.app || [];
    stato.pila = [];
    stato.schermata = null;

    $('ora').textContent = d.ora || '';
    $('operatore').textContent = d.aspetto?.operatore || 'AUREA';
    document.body.dataset.tema = d.aspetto?.tema || 'scuro';
    if (d.aspetto?.sfondo) {
      document.documentElement.style.setProperty('--sfondo', d.aspetto.sfondo);
    }

    document.body.classList.remove('oculto');
    vaiHome();
  }

  if (d.azione === 'soloChiamata') {
    document.body.classList.remove('oculto');
  }

  if (d.azione === 'chiudi') {
    document.body.classList.add('oculto');
    chiudiFoglio();
  }

  if (d.azione === 'ora') $('ora').textContent = d.ora;

  if (d.azione === 'badge') {
    stato.app.forEach((a) => { a.badge = (d.badge || {})[a.id] || 0; });
    if (!stato.schermata) disegnaHome();
  }

  if (d.azione === 'chiamata') {
    stato.chiamata = d.chiamata;
    disegnaChiamata();
  }

  if (d.azione === 'chiamataAttiva') {
    if (stato.chiamata) stato.chiamata.attiva = true;
    disegnaChiamata();
  }

  if (d.azione === 'chiamataChiusa') {
    stato.chiamata = null;
    disegnaChiamata();
  }
});

document.addEventListener('keyup', (e) => {
  if (e.key !== 'Escape') return;

  if (!$('foglio').classList.contains('oculto')) return chiudiFoglio();
  if (stato.chiamata) return;             /* dalla chiamata non si esce con ESC */

  invia('chiudi');
});
