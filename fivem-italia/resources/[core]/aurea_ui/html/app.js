/* ==========================================================================
   AUREA · Logica dell'interfaccia NUI
   Riceve messaggi dal client Lua e restituisce le risposte via fetch.
   ========================================================================== */

const RISORSA = 'aurea_ui';

const invia = (endpoint, dati = {}) =>
  fetch(`https://${RISORSA}/${endpoint}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(dati),
  }).catch(() => {});

const $ = (id) => document.getElementById(id);

/* --------------------------------------------------------------------------
   NOTIFICHE
   -------------------------------------------------------------------------- */
const ICONE = {
  successo: '✓',
  errore: '✕',
  avviso: '!',
  info: 'i',
  polizia: '⚑',
  sanita: '✚',
};

function notifica({ tipo = 'info', titolo = '', testo = '', durata = 5000, icona }) {
  const el = document.createElement('div');
  el.className = `notifica ${tipo}`;
  el.innerHTML = `
    <div class="notifica-icona">${icona || ICONE[tipo] || 'i'}</div>
    <div class="notifica-corpo">
      ${titolo ? `<div class="notifica-titolo">${escape(titolo)}</div>` : ''}
      ${testo ? `<div class="notifica-testo">${escape(testo)}</div>` : ''}
    </div>
    <div class="notifica-barra" style="animation-duration:${durata}ms"></div>`;

  const contenitore = $('notifiche');
  contenitore.appendChild(el);

  // non lasciare accumulare più di 6 notifiche a schermo
  while (contenitore.children.length > 6) contenitore.removeChild(contenitore.firstChild);

  setTimeout(() => {
    el.classList.add('uscita');
    setTimeout(() => el.remove(), 250);
  }, durata);
}

function escape(s) {
  return String(s).replace(/[&<>"']/g, (c) =>
    ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
}

/* --------------------------------------------------------------------------
   PROMPT
   -------------------------------------------------------------------------- */
function prompt(attivo, testo, tasto) {
  const el = $('prompt');
  if (!attivo) return el.classList.add('oculto');
  $('prompt-tasto').textContent = tasto || 'E';
  $('prompt-testo').textContent = testo || '';
  el.classList.remove('oculto');
}

/* --------------------------------------------------------------------------
   BARRA DI AVANZAMENTO
   -------------------------------------------------------------------------- */
let progressoTimer = null;

function progresso(dati) {
  const el = $('progresso');
  const fill = $('progresso-riempimento');

  if (!dati.attivo) {
    clearInterval(progressoTimer);
    el.classList.add('oculto');
    fill.style.width = '0%';
    return;
  }

  $('progresso-etichetta').textContent = dati.etichetta || 'Attendere...';
  el.querySelector('.progresso-annulla').style.display = dati.annullabile ? '' : 'none';
  el.classList.remove('oculto');

  const inizio = Date.now();
  const durata = dati.durata || 3000;
  clearInterval(progressoTimer);
  progressoTimer = setInterval(() => {
    const p = Math.min(100, ((Date.now() - inizio) / durata) * 100);
    fill.style.width = `${p}%`;
    if (p >= 100) clearInterval(progressoTimer);
  }, 30);
}

/* --------------------------------------------------------------------------
   MENU CONTESTUALE
   -------------------------------------------------------------------------- */
let menuVoci = [];
let indiceAttivo = 0;

function apriMenu({ titolo, sottotitolo, voci }) {
  menuVoci = voci || [];
  indiceAttivo = 0;

  $('menu-titolo').textContent = titolo || 'Menu';
  const sub = $('menu-sottotitolo');
  sub.textContent = sottotitolo || '';
  sub.style.display = sottotitolo ? '' : 'none';

  const lista = $('menu-voci');
  lista.innerHTML = '';

  menuVoci.forEach((voce, i) => {
    const el = document.createElement('div');
    el.className = `voce${voce.disattivata ? ' disattivata' : ''}${i === 0 ? ' attiva' : ''}`;
    el.innerHTML = `
      ${voce.icona ? `<div class="voce-icona">${escape(voce.icona)}</div>` : ''}
      <div class="voce-corpo">
        <div class="voce-titolo">${escape(voce.titolo || '')}</div>
        ${voce.descrizione ? `<div class="voce-desc">${escape(voce.descrizione)}</div>` : ''}
      </div>
      ${voce.valore ? `<div class="voce-valore">${escape(voce.valore)}</div>` : ''}`;

    el.addEventListener('click', () => scegli(i));
    el.addEventListener('mouseenter', () => evidenzia(i));
    lista.appendChild(el);
  });

  $('menu').classList.remove('oculto');
}

function evidenzia(i) {
  const figli = $('menu-voci').children;
  if (!figli.length) return;
  indiceAttivo = (i + figli.length) % figli.length;
  Array.from(figli).forEach((el, n) => el.classList.toggle('attiva', n === indiceAttivo));
  figli[indiceAttivo].scrollIntoView({ block: 'nearest' });
}

function scegli(i) {
  const voce = menuVoci[i];
  if (!voce || voce.disattivata) return;
  chiudiMenu();
  invia('menuScelta', { id: voce.id !== undefined ? voce.id : i });
}

function chiudiMenu(annulla = false) {
  $('menu').classList.add('oculto');
  menuVoci = [];
  if (annulla) invia('menuChiuso');
}

/* --------------------------------------------------------------------------
   DIALOGO DI INPUT
   -------------------------------------------------------------------------- */
let campiCorrenti = [];

function apriDialogo({ titolo, campi }) {
  campiCorrenti = campi || [];
  $('dialogo-titolo').textContent = titolo || 'Inserisci i dati';

  const contenitore = $('dialogo-campi');
  contenitore.innerHTML = '';

  campiCorrenti.forEach((campo, i) => {
    const wrap = document.createElement('div');
    wrap.className = 'campo';
    const idCampo = `campo-${i}`;
    let controllo;

    if (campo.tipo === 'select') {
      const opzioni = (campo.opzioni || [])
        .map((o) => `<option value="${escape(o.valore ?? o)}">${escape(o.etichetta ?? o)}</option>`)
        .join('');
      controllo = `<select id="${idCampo}">${opzioni}</select>`;
    } else if (campo.tipo === 'textarea') {
      controllo = `<textarea id="${idCampo}" placeholder="${escape(campo.segnaposto || '')}" maxlength="${campo.max || 500}">${escape(campo.valore || '')}</textarea>`;
    } else {
      controllo = `<input id="${idCampo}" type="${campo.tipo || 'text'}"
        placeholder="${escape(campo.segnaposto || '')}"
        value="${escape(campo.valore ?? '')}"
        ${campo.min !== undefined ? `min="${campo.min}"` : ''}
        ${campo.max !== undefined ? `max="${campo.max}"` : ''}
        ${campo.obbligatorio ? 'required' : ''}>`;
    }

    wrap.innerHTML = `<label for="${idCampo}">${escape(campo.etichetta || '')}</label>${controllo}`;
    contenitore.appendChild(wrap);
  });

  $('dialogo').classList.remove('oculto');
  setTimeout(() => {
    const primo = contenitore.querySelector('input, select, textarea');
    if (primo) primo.focus();
  }, 40);
}

function chiudiDialogo(risposta) {
  $('dialogo').classList.add('oculto');
  invia('dialogoRisposta', { valori: risposta });
}

$('dialogo-form').addEventListener('submit', (e) => {
  e.preventDefault();
  const valori = campiCorrenti.map((campo, i) => {
    const el = $(`campo-${i}`);
    if (!el) return null;
    if (campo.tipo === 'number') return el.value === '' ? null : Number(el.value);
    return el.value;
  });
  chiudiDialogo(valori);
});

$('dialogo-annulla').addEventListener('click', () => chiudiDialogo(null));

/* --------------------------------------------------------------------------
   TASTIERA
   -------------------------------------------------------------------------- */
document.addEventListener('keydown', (e) => {
  const menuAperto = !$('menu').classList.contains('oculto');
  const dialogoAperto = !$('dialogo').classList.contains('oculto');

  if (dialogoAperto && e.key === 'Escape') {
    e.preventDefault();
    return chiudiDialogo(null);
  }

  if (!menuAperto) return;

  switch (e.key) {
    case 'ArrowUp':   e.preventDefault(); evidenzia(indiceAttivo - 1); break;
    case 'ArrowDown': e.preventDefault(); evidenzia(indiceAttivo + 1); break;
    case 'Enter':     e.preventDefault(); scegli(indiceAttivo); break;
    case 'Escape':
    case 'Backspace': e.preventDefault(); chiudiMenu(true); break;
  }
});

/* --------------------------------------------------------------------------
   INGRESSO MESSAGGI DA LUA
   -------------------------------------------------------------------------- */
window.addEventListener('message', ({ data }) => {
  switch (data.azione) {
    case 'notifica':  notifica(data); break;
    case 'prompt':    prompt(data.attivo, data.testo, data.tasto); break;
    case 'progresso': progresso(data); break;
    case 'menu':      apriMenu(data); break;
    case 'chiudiMenu': chiudiMenu(false); break;
    case 'dialogo':   apriDialogo(data); break;
  }
});
