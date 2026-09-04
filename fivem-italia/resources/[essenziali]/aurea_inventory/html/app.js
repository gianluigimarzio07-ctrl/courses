/* ==========================================================================
   AUREA · Inventario — interazione
   ========================================================================== */

const RISORSA = 'aurea_inventory';
const $ = (id) => document.getElementById(id);

const invia = (endpoint, dati = {}) =>
  fetch(`https://${RISORSA}/${endpoint}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(dati),
  }).then((r) => r.json()).catch(() => null);

const escape = (s) => String(s ?? '').replace(/[&<>"']/g, (c) =>
  ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

/* Icone per categoria: nessun asset esterno da caricare. ------------------ */
const ICONE_CATEGORIA = {
  documenti: '🪪', elettronica: '📱', cibo: '🍽', bevande: '🥤', alcolici: '🍷',
  materiali: '📦', sanita: '💊', servizio: '🚔', illegale: '🚫', attrezzi: '🔧',
  contenitori: '🎒', moda: '👔', varie: '📎',
};

const ICONE_OGGETTO = {
  telefono: '📱', laptop: '💻', radio: '📻', acqua: '💧', acqua_frizzante: '🫧',
  espresso: '☕', cappuccino: '☕', spritz: '🍹', vino_rosso: '🍷', vino_docg: '🍾',
  birra: '🍺', amaro: '🥃', panino: '🥪', pizza_margherita: '🍕', pasta_carbonara: '🍝',
  cornetto: '🥐', parmigiano_dop: '🧀', mozzarella_bufala: '🧀', formaggio_fresco: '🧀',
  olio_extravergine: '🫒', olio_dop: '🫒', olive: '🫒', uva_sangiovese: '🍇',
  uva_nebbiolo: '🍇', mosto: '🍇', latte_crudo: '🥛', caffe_verde: '🌱', caffe_tostato: '☕',
  farina_00: '🌾', pomodoro_san_marzano: '🍅', kit_medico: '🧰', bendaggio: '🩹',
  antidolorifico: '💊', adrenalina: '💉', sacca_sangue: '🩸', manette: '⛓',
  etilometro: '🌬', telelaser: '📡', grimaldello: '🗝', contanti_sporchi: '💵',
  chiavi_casa: '🔑', borsone: '🎒', valigetta: '💼', tanica: '⛽', corda: '🪢',
  kit_riparazione: '🧰', biglietto_lotteria: '🎟', capo_sartoriale: '👔',
  tessuto_pregiato: '🧵', rame: '🟠', acciaio: '⚙', vetro: '🔷', plastica: '♻',
  patente: '🪪', carta_identita: '🪪', tessera_sanitaria: '💳', libretto: '📕',
  assicurazione: '📃', visura: '📜', fattura: '🧾', verbale: '📄', porto_armi: '🎯',
  tesserino: '🎫', documento_falso: '❌', targa_clonata: '🔢', sostanza_grezza: '🧪',
  sostanza_raffinata: '💠', cartuccia: '🔫', jammer: '📶', gps_tracker: '📍',
};

const icona = (item) =>
  ICONE_OGGETTO[item.nome] || ICONE_CATEGORIA[item.categoria] || '📦';

/* Stato ------------------------------------------------------------------- */
let statoPrimario = null;
let statoSecondario = null;
let selezione = null;        // { contenitore, slot }
let trascinamento = null;    // { contenitore, slot, quantita }
let divisionePendente = null;

/* --------------------------------------------------------------------------
   Rendering
   -------------------------------------------------------------------------- */
function disegna(contenitore, elementoGriglia, elementoPeso, elementoTesto) {
  if (!contenitore) return;

  const perSlot = new Map(contenitore.item.map((i) => [i.slot, i]));
  elementoGriglia.innerHTML = '';

  for (let s = 1; s <= contenitore.capienza; s++) {
    const item = perSlot.get(s);
    const el = document.createElement('div');
    el.className = `slot${item ? ' pieno' : ''}`;
    el.dataset.slot = s;
    el.dataset.contenitore = contenitore.id;

    if (item) {
      const unico = item.metadata && Object.keys(item.metadata).length > 0;
      el.innerHTML = `
        <span class="slot-numero">${s}</span>
        ${unico ? '<span class="slot-unico">◆</span>' : ''}
        <span class="slot-icona">${icona(item)}</span>
        <span class="slot-nome">${escape(item.etichetta)}</span>
        ${item.quantita > 1 ? `<span class="slot-quantita">${item.quantita}</span>` : ''}
        ${item.freschezza !== undefined && item.freschezza !== null
          ? `<span class="slot-freschezza ${item.freschezza < 25 ? 'bassa' : item.freschezza < 60 ? 'media' : ''}"
               style="width:${Math.max(2, item.freschezza)}%"></span>` : ''}`;
      el.draggable = true;
    } else {
      el.innerHTML = `<span class="slot-numero">${s}</span>`;
    }

    collegaSlot(el, contenitore, item);
    elementoGriglia.appendChild(el);
  }

  const kg = (contenitore.peso / 1000).toFixed(1);
  const kgMax = (contenitore.pesoMax / 1000).toFixed(0);
  const rapporto = (contenitore.peso / contenitore.pesoMax) * 100;
  elementoPeso.style.width = `${Math.min(100, rapporto)}%`;
  elementoPeso.classList.toggle('pieno', rapporto > 85);
  elementoTesto.textContent = `${kg} / ${kgMax} kg · ${contenitore.item.length}/${contenitore.capienza} slot`;
}

function ridisegna() {
  disegna(statoPrimario, $('griglia-primario'), $('peso-primario'), $('peso-testo-primario'));
  if (statoSecondario) {
    $('pannello-secondario').classList.remove('oculto');
    disegna(statoSecondario, $('griglia-secondario'), $('peso-secondario'), $('peso-testo-secondario'));
  } else {
    $('pannello-secondario').classList.add('oculto');
  }
  mostraDettaglio();
}

/* --------------------------------------------------------------------------
   Eventi sugli slot
   -------------------------------------------------------------------------- */
function collegaSlot(el, contenitore, item) {
  el.addEventListener('click', () => {
    if (!item) return;
    selezione = { contenitore: contenitore.id, slot: item.slot };
    document.querySelectorAll('.slot.selezionato').forEach((s) => s.classList.remove('selezionato'));
    el.classList.add('selezionato');
    mostraDettaglio();
  });

  el.addEventListener('dblclick', () => {
    if (!item || !item.usabile) return;
    if (contenitore.id !== statoPrimario.id) return;   // si usa solo ciò che si ha addosso
    invia('usa', { slot: item.slot });
  });

  el.addEventListener('contextmenu', (e) => {
    e.preventDefault();
    if (!item) return;
    apriContestuale(e.clientX, e.clientY, contenitore, item);
  });

  if (item) {
    el.addEventListener('dragstart', (e) => {
      trascinamento = {
        contenitore: contenitore.id,
        slot: item.slot,
        quantita: item.quantita,
        dividi: e.shiftKey && item.quantita > 1,
      };
      el.classList.add('trascinato');
      e.dataTransfer.effectAllowed = 'move';
    });

    el.addEventListener('dragend', () => {
      el.classList.remove('trascinato');
      document.querySelectorAll('.slot.bersaglio').forEach((s) => s.classList.remove('bersaglio'));
    });
  }

  el.addEventListener('dragover', (e) => {
    if (!trascinamento) return;
    e.preventDefault();
    el.classList.add('bersaglio');
  });

  el.addEventListener('dragleave', () => el.classList.remove('bersaglio'));

  el.addEventListener('drop', (e) => {
    e.preventDefault();
    el.classList.remove('bersaglio');
    if (!trascinamento) return;

    const destinazione = { contenitore: contenitore.id, slot: Number(el.dataset.slot) };
    if (trascinamento.contenitore === destinazione.contenitore
        && trascinamento.slot === destinazione.slot) {
      trascinamento = null;
      return;
    }

    if (trascinamento.dividi) {
      apriDivisione(trascinamento, destinazione);
    } else {
      esegui(trascinamento, destinazione, trascinamento.quantita);
    }
    trascinamento = null;
  });
}

function esegui(origine, destinazione, quantita) {
  invia('sposta', {
    da: origine.contenitore, slotDa: origine.slot,
    a: destinazione.contenitore, slotA: destinazione.slot,
    quantita,
  });
}

/* --------------------------------------------------------------------------
   Dettaglio
   -------------------------------------------------------------------------- */
function trovaItem(idContenitore, slot) {
  const c = idContenitore === statoPrimario?.id ? statoPrimario
    : idContenitore === statoSecondario?.id ? statoSecondario : null;
  if (!c) return null;
  return c.item.find((i) => i.slot === slot) || null;
}

const ETICHETTE_META = {
  numero: 'Numero', targa: 'Targa', modello: 'Modello', categorie: 'Categorie',
  intestatario: 'Intestatario', cf: 'Codice fiscale', piva: 'Partita IVA',
  ragione: 'Ragione sociale', forma: 'Forma', settore: 'Settore', regime: 'Regime',
  scadenza: 'Scadenza', classe: 'Classe', tipo: 'Tipo', kw: 'Potenza (kW)',
  qualita: 'Qualità', certificazione: 'Certificazione', lotto: 'Lotto',
  matricola: 'Matricola', corpo: 'Corpo', iban: 'IBAN', origine: 'Origine',
};

function mostraDettaglio() {
  const item = selezione && trovaItem(selezione.contenitore, selezione.slot);

  if (!item) {
    $('dettaglio-vuoto').classList.remove('oculto');
    $('dettaglio-corpo').classList.add('oculto');
    return;
  }

  $('dettaglio-vuoto').classList.add('oculto');
  $('dettaglio-corpo').classList.remove('oculto');

  $('dettaglio-icona').textContent = icona(item);
  $('dettaglio-nome').textContent = item.etichetta;
  $('dettaglio-categoria').textContent = item.categoria;
  $('dettaglio-descrizione').textContent = item.descrizione || '';

  const blocco = $('freschezza-blocco');
  if (item.freschezza !== undefined && item.freschezza !== null) {
    blocco.classList.remove('oculto');
    const barra = $('freschezza-riempimento');
    barra.style.width = `${Math.max(0, item.freschezza)}%`;
    barra.style.background = item.freschezza < 25 ? '#cf2e2e' : item.freschezza < 60 ? '#e8b53b' : '#1f9d55';
  } else {
    blocco.classList.add('oculto');
  }

  const dati = $('dettaglio-dati');
  dati.innerHTML = `
    <div><dt>Quantità</dt><dd>${item.quantita}</dd></div>
    <div><dt>Peso unitario</dt><dd>${(item.peso / 1000).toFixed(2)} kg</dd></div>
    <div><dt>Peso totale</dt><dd>${((item.peso * item.quantita) / 1000).toFixed(2)} kg</dd></div>`;

  if (item.metadata) {
    Object.entries(item.metadata).forEach(([chiave, valore]) => {
      if (chiave === 'contenitoreId' || typeof valore === 'object') return;
      dati.insertAdjacentHTML('beforeend',
        `<div><dt>${escape(ETICHETTE_META[chiave] || chiave)}</dt><dd>${escape(valore)}</dd></div>`);
    });
  }

  const nelleTasche = selezione.contenitore === statoPrimario.id;
  $('btn-usa').disabled = !item.usabile || !nelleTasche;
  $('btn-getta').disabled = !nelleTasche;
}

$('btn-usa').addEventListener('click', () => {
  if (!selezione) return;
  invia('usa', { slot: selezione.slot });
});

$('btn-getta').addEventListener('click', () => {
  if (!selezione) return;
  const item = trovaItem(selezione.contenitore, selezione.slot);
  if (!item) return;
  invia('getta', { slot: selezione.slot, quantita: item.quantita });
});

/* --------------------------------------------------------------------------
   Menu contestuale
   -------------------------------------------------------------------------- */
function apriContestuale(x, y, contenitore, item) {
  const menu = $('contestuale');
  const nelleTasche = contenitore.id === statoPrimario.id;

  const voci = [];
  if (item.usabile && nelleTasche) voci.push({ testo: 'Usa', fn: () => invia('usa', { slot: item.slot }) });
  if (nelleTasche) {
    voci.push({ testo: 'Getta tutto', fn: () => invia('getta', { slot: item.slot, quantita: item.quantita }) });
    if (item.quantita > 1) {
      voci.push({ testo: 'Getta una unità', fn: () => invia('getta', { slot: item.slot, quantita: 1 }) });
    }
  }
  if (statoSecondario) {
    const altro = nelleTasche ? statoSecondario : statoPrimario;
    voci.push({
      testo: nelleTasche ? 'Sposta nel contenitore' : 'Prendi',
      fn: () => esegui({ contenitore: contenitore.id, slot: item.slot }, { contenitore: altro.id, slot: null }, item.quantita),
    });
    if (item.quantita > 1) {
      voci.push({
        testo: 'Sposta una parte...',
        fn: () => apriDivisione(
          { contenitore: contenitore.id, slot: item.slot, quantita: item.quantita },
          { contenitore: altro.id, slot: null }),
      });
    }
  }

  if (voci.length === 0) return;

  menu.innerHTML = '';
  voci.forEach((v) => {
    const el = document.createElement('div');
    el.textContent = v.testo;
    el.addEventListener('click', () => { menu.classList.add('oculto'); v.fn(); });
    menu.appendChild(el);
  });

  menu.style.left = `${Math.min(x, window.innerWidth - 180)}px`;
  menu.style.top = `${Math.min(y, window.innerHeight - menu.children.length * 34 - 20)}px`;
  menu.classList.remove('oculto');
}

document.addEventListener('click', (e) => {
  if (!e.target.closest('#contestuale')) $('contestuale').classList.add('oculto');
});

/* --------------------------------------------------------------------------
   Divisione della pila
   -------------------------------------------------------------------------- */
function apriDivisione(origine, destinazione) {
  divisionePendente = { origine, destinazione };
  const slider = $('slider-quantita');
  slider.max = origine.quantita;
  slider.value = Math.max(1, Math.floor(origine.quantita / 2));
  $('quantita-valore').textContent = slider.value;
  $('velo-divisione').classList.remove('oculto');
}

$('slider-quantita').addEventListener('input', (e) => {
  $('quantita-valore').textContent = e.target.value;
});

$('divisione-annulla').addEventListener('click', () => {
  divisionePendente = null;
  $('velo-divisione').classList.add('oculto');
});

$('divisione-conferma').addEventListener('click', () => {
  if (!divisionePendente) return;
  const { origine, destinazione } = divisionePendente;
  esegui(origine, destinazione, Number($('slider-quantita').value));
  divisionePendente = null;
  $('velo-divisione').classList.add('oculto');
});

/* --------------------------------------------------------------------------
   Tastiera
   -------------------------------------------------------------------------- */
document.addEventListener('keydown', (e) => {
  if (!$('velo-divisione').classList.contains('oculto')) {
    if (e.key === 'Escape') { divisionePendente = null; $('velo-divisione').classList.add('oculto'); }
    if (e.key === 'Enter') $('divisione-conferma').click();
    return;
  }
  if (e.key === 'Escape' || e.key === 'Tab') {
    e.preventDefault();
    chiudi();
  }
});

function chiudi() {
  document.body.classList.add('oculto');
  selezione = null;
  invia('chiudi', {});
}

/* --------------------------------------------------------------------------
   Messaggi da Lua
   -------------------------------------------------------------------------- */
window.addEventListener('message', ({ data }) => {
  switch (data.azione) {
    case 'apri':
      statoPrimario = data.primario;
      statoSecondario = data.secondario || null;
      $('titolo-secondario').textContent = data.etichettaSecondaria || 'Contenitore';
      selezione = null;
      document.body.classList.remove('oculto');
      ridisegna();
      break;

    case 'aggiorna':
      if (data.primario) statoPrimario = data.primario;
      statoSecondario = data.secondario !== undefined ? data.secondario : statoSecondario;
      ridisegna();
      break;

    case 'chiudi':
      document.body.classList.add('oculto');
      break;
  }
});
