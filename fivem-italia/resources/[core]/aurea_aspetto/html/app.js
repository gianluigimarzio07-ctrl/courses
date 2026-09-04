/* ==========================================================================
   AUREA · Editor dell'aspetto
   Il pannello è solo una tastiera: ogni modifica viene applicata subito al
   ped dal lato Lua, così quello che vedi è già il risultato finale.
   ========================================================================== */

const RISORSA = 'aurea_aspetto';
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

/* Tavolozza dei colori per capelli e trucco (indici nativi 0-63) */
const COLORI_CAPELLI = [
  '#221a17','#2f2620','#453329','#5b4030','#6f4e35','#87603f','#9c7448','#b08a55',
  '#c2a06a','#d4b782','#e0cb9d','#eddfc0','#f0e6cf','#d8c9a8','#b8a17c','#96784f',
  '#7d5c3a','#63452b','#4c3221','#3a2418','#8b1e1e','#a33232','#6b2d5c','#4a2a6b',
  '#2d4a6b','#2d6b5a','#4a6b2d','#6b5a2d','#8a8a8a','#a8a8a8','#c6c6c6','#e4e4e4',
];

let stato = {
  modalita: 'creazione',
  dati: null,
  schedaAttiva: null,
  schede: [],
  costo: 0,
};

/* --------------------------------------------------------------------------
   Costruzione delle schede
   -------------------------------------------------------------------------- */
function disegnaSchede() {
  const nav = $('schede');
  nav.innerHTML = '';

  stato.schede.forEach((s) => {
    const el = document.createElement('button');
    el.className = `scheda${s.id === stato.schedaAttiva ? ' attiva' : ''}`;
    el.textContent = s.nome;
    el.addEventListener('click', () => {
      stato.schedaAttiva = s.id;
      disegnaSchede();
      disegnaControlli();
    });
    nav.appendChild(el);
  });
}

/* --------------------------------------------------------------------------
   Costruzione dei controlli
   -------------------------------------------------------------------------- */
function selettore({ etichetta, valore, minimo, massimo, onChange, mostraValore }) {
  const wrap = document.createElement('div');
  wrap.className = 'controllo';

  const testo = mostraValore ? mostraValore(valore) : `${valore} / ${massimo}`;
  wrap.innerHTML = `
    <div class="controllo-etichetta"><span>${escape(etichetta)}</span></div>
    <div class="selettore">
      <button type="button" data-passo="-1">‹</button>
      <div class="valore">${escape(testo)}</div>
      <button type="button" data-passo="1">›</button>
    </div>`;

  wrap.querySelectorAll('button').forEach((b) => {
    b.addEventListener('click', () => {
      const passo = Number(b.dataset.passo);
      let nuovo = valore + passo;
      if (nuovo > massimo) nuovo = minimo;
      if (nuovo < minimo) nuovo = massimo;
      onChange(nuovo);
    });
  });

  return wrap;
}

function cursore({ etichetta, valore, onChange }) {
  const wrap = document.createElement('div');
  wrap.className = 'controllo';
  wrap.innerHTML = `
    <div class="controllo-etichetta">
      <span>${escape(etichetta)}</span><b>${valore.toFixed(2)}</b>
    </div>
    <input type="range" class="slider" min="-1" max="1" step="0.05" value="${valore}">`;

  const input = wrap.querySelector('input');
  const label = wrap.querySelector('b');
  input.addEventListener('input', () => {
    const v = Number(input.value);
    label.textContent = v.toFixed(2);
    onChange(v);
  });

  return wrap;
}

function tavolozza({ etichetta, valore, onChange }) {
  const wrap = document.createElement('div');
  wrap.className = 'controllo';
  wrap.innerHTML = `<div class="controllo-etichetta"><span>${escape(etichetta)}</span></div>`;

  const griglia = document.createElement('div');
  griglia.className = 'tavolozza';

  COLORI_CAPELLI.forEach((colore, i) => {
    const c = document.createElement('div');
    c.className = `colore${i === valore ? ' attivo' : ''}`;
    c.style.background = colore;
    c.addEventListener('click', () => {
      griglia.querySelectorAll('.colore').forEach((x) => x.classList.remove('attivo'));
      c.classList.add('attivo');
      onChange(i);
    });
    griglia.appendChild(c);
  });

  wrap.appendChild(griglia);
  return wrap;
}

function gruppo(titolo) {
  const g = document.createElement('div');
  g.className = 'gruppo';
  if (titolo) {
    const t = document.createElement('div');
    t.className = 'gruppo-titolo';
    t.textContent = titolo;
    g.appendChild(t);
  }
  return g;
}

/* --------------------------------------------------------------------------
   Disegno della scheda attiva
   -------------------------------------------------------------------------- */
function disegnaControlli() {
  const box = $('controlli');
  box.innerHTML = '';

  const scheda = stato.schede.find((s) => s.id === stato.schedaAttiva);
  if (!scheda) return;

  if (scheda.id === 'eredita') return disegnaEredita(box);
  if (scheda.id === 'tratti') return disegnaTratti(box);
  if (scheda.id === 'volto') return disegnaVolto(box);
  if (scheda.id === 'capelli') return disegnaCapelli(box);
  if (scheda.id === 'tatuaggi') return disegnaTatuaggi(box);

  // Abbigliamento e accessori
  disegnaVestiario(box, scheda);
}

function disegnaEredita(box) {
  const e = stato.dati.eredita;
  const g = gruppo('Genitori');

  g.appendChild(selettore({
    etichetta: 'Padre', valore: e.padre, minimo: 0, massimo: 45,
    onChange: (v) => { e.padre = v; applica(); disegnaControlli(); },
  }));
  g.appendChild(selettore({
    etichetta: 'Madre', valore: e.madre, minimo: 21, massimo: 45,
    onChange: (v) => { e.madre = v; applica(); disegnaControlli(); },
  }));
  box.appendChild(g);

  const g2 = gruppo('Somiglianza');
  g2.appendChild(cursoreZeroUno('Tratti del volto', e.mix, (v) => { e.mix = v; applica(); }));
  g2.appendChild(cursoreZeroUno('Tono della pelle', e.mixPelle, (v) => { e.mixPelle = v; applica(); }));
  box.appendChild(g2);
}

function cursoreZeroUno(etichetta, valore, onChange) {
  const wrap = document.createElement('div');
  wrap.className = 'controllo';
  wrap.innerHTML = `
    <div class="controllo-etichetta">
      <span>${escape(etichetta)}</span><b>${Math.round(valore * 100)}%</b>
    </div>
    <input type="range" class="slider" min="0" max="1" step="0.05" value="${valore}">`;

  const input = wrap.querySelector('input');
  const label = wrap.querySelector('b');
  input.addEventListener('input', () => {
    const v = Number(input.value);
    label.textContent = `${Math.round(v * 100)}%`;
    onChange(v);
  });
  return wrap;
}

function disegnaTratti(box) {
  const g = gruppo('Tratti somatici');
  Object.entries(stato.tratti || {}).forEach(([indice, nome]) => {
    const valore = Number(stato.dati.tratti[indice] ?? 0);
    g.appendChild(cursore({
      etichetta: nome, valore,
      onChange: (v) => { stato.dati.tratti[indice] = v; applica(); },
    }));
  });
  box.appendChild(g);
}

function disegnaVolto(box) {
  const g = gruppo('Volto');

  (stato.sovrapposizioni || []).forEach((s) => {
    const corrente = stato.dati.sovrapposizioni[String(s.id)] || { indice: 255, opacita: 1, colore: 0 };

    g.appendChild(selettore({
      etichetta: s.nome,
      valore: corrente.indice === 255 ? -1 : corrente.indice,
      minimo: -1, massimo: s.massimo ?? 30,
      mostraValore: (v) => (v < 0 ? 'nessuno' : `${v + 1}`),
      onChange: (v) => {
        corrente.indice = v < 0 ? 255 : v;
        stato.dati.sovrapposizioni[String(s.id)] = corrente;
        applica(); disegnaControlli();
      },
    }));

    if (corrente.indice !== 255 && s.colore > 0) {
      g.appendChild(tavolozza({
        etichetta: `Colore — ${s.nome.toLowerCase()}`,
        valore: corrente.colore ?? 0,
        onChange: (v) => {
          corrente.colore = v;
          corrente.coloreSecondario = v;
          stato.dati.sovrapposizioni[String(s.id)] = corrente;
          applica();
        },
      }));
    }
  });

  box.appendChild(g);
}

function disegnaCapelli(box) {
  const g = gruppo('Capelli');
  const c = stato.dati.capelli;

  g.appendChild(selettore({
    etichetta: 'Taglio', valore: c.drawable, minimo: 0, massimo: stato.massimi?.capelli ?? 40,
    onChange: (v) => { c.drawable = v; c.texture = 0; applica(); disegnaControlli(); },
  }));
  g.appendChild(tavolozza({
    etichetta: 'Colore', valore: c.colore ?? 0,
    onChange: (v) => { c.colore = v; applica(); },
  }));
  g.appendChild(tavolozza({
    etichetta: 'Riflessi', valore: c.coloreSecondario ?? 0,
    onChange: (v) => { c.coloreSecondario = v; applica(); },
  }));

  box.appendChild(g);
}

function disegnaVestiario(box, scheda) {
  const g = gruppo(scheda.nome);
  const elenco = scheda.id === 'accessori' ? stato.accessori : stato.componenti;
  const contenitore = scheda.id === 'accessori' ? stato.dati.accessori : stato.dati.componenti;

  (elenco || []).forEach((c) => {
    const corrente = contenitore[String(c.id)] || { drawable: 0, texture: 0 };
    const massimo = (stato.massimi?.[`${scheda.id}_${c.id}`] ?? 30);

    g.appendChild(selettore({
      etichetta: c.nome,
      valore: corrente.drawable,
      minimo: scheda.id === 'accessori' ? -1 : 0,
      massimo,
      mostraValore: (v) => (v < 0 ? 'nessuno' : `${v + 1} / ${massimo + 1}`),
      onChange: (v) => {
        corrente.drawable = v;
        corrente.texture = 0;
        contenitore[String(c.id)] = corrente;
        segnaModifica(c.id, scheda.id);
        applica(); disegnaControlli();
      },
    }));

    if (corrente.drawable >= 0) {
      const massimoTex = stato.massimi?.[`tex_${scheda.id}_${c.id}_${corrente.drawable}`] ?? 0;
      if (massimoTex > 0) {
        g.appendChild(selettore({
          etichetta: `Variante — ${c.nome.toLowerCase()}`,
          valore: corrente.texture, minimo: 0, massimo: massimoTex,
          onChange: (v) => {
            corrente.texture = v;
            contenitore[String(c.id)] = corrente;
            segnaModifica(c.id, scheda.id);
            applica();
          },
        }));
      }
    }
  });

  box.appendChild(g);
}

function disegnaTatuaggi(box) {
  if (!stato.tatuaggiDisponibili || stato.tatuaggiDisponibili.length === 0) {
    box.innerHTML = '<p class="vuoto">Nessun tatuaggio disponibile per questa zona.</p>';
    return;
  }

  stato.zoneTatuaggi.forEach((zona) => {
    const disponibili = stato.tatuaggiDisponibili.filter((t) => t.zona === zona.chiave);
    if (disponibili.length === 0) return;

    const g = gruppo(zona.nome);
    disponibili.forEach((t) => {
      const scelto = (stato.dati.tatuaggi || []).some((x) => x.nome === t.nome);
      const el = document.createElement('div');
      el.className = `tatuaggio${scelto ? ' scelto' : ''}`;
      el.innerHTML = `
        <span class="tatuaggio-nome">${escape(t.etichetta)}</span>
        <span class="tatuaggio-segno">${scelto ? '✓' : ''}</span>`;

      el.addEventListener('click', () => {
        stato.dati.tatuaggi = stato.dati.tatuaggi || [];
        const i = stato.dati.tatuaggi.findIndex((x) => x.nome === t.nome);
        if (i >= 0) {
          stato.dati.tatuaggi.splice(i, 1);
        } else {
          stato.dati.tatuaggi.push({ collezione: t.collezione, nome: t.nome, zona: t.zona });
        }
        aggiornaCosto();
        applica(); disegnaControlli();
      });

      g.appendChild(el);
    });
    box.appendChild(g);
  });
}

/* --------------------------------------------------------------------------
   Costo
   -------------------------------------------------------------------------- */
const modificati = new Set();

function segnaModifica(id, scheda) {
  modificati.add(`${scheda}:${id}`);
  aggiornaCosto();
}

function aggiornaCosto() {
  if (stato.modalita === 'creazione') {
    stato.costo = 0;
  } else if (stato.modalita === 'tatuatore') {
    const iniziali = stato.tatuaggiIniziali || 0;
    const attuali = (stato.dati.tatuaggi || []).length;
    const nuovi = Math.max(0, attuali - iniziali);
    const rimossi = Math.max(0, iniziali - attuali);
    stato.costo = nuovi * (stato.prezzi.tatuaggio || 0)
                + rimossi * (stato.prezzi.rimozioneTatuaggio || 0);
  } else if (stato.modalita === 'barbiere') {
    stato.costo = modificati.size > 0 ? (stato.prezzi.taglioCapelli || 0) : 0;
  } else {
    let totale = 0;
    modificati.forEach((chiave) => {
      totale += chiave.startsWith('accessori')
        ? (stato.prezzi.accessorio || 0)
        : (stato.prezzi.capo || 0);
    });
    stato.costo = totale;
  }

  $('costo').textContent = euro(stato.costo);
}

/* --------------------------------------------------------------------------
   Applicazione live
   -------------------------------------------------------------------------- */
let attesaApplica = null;
function applica() {
  clearTimeout(attesaApplica);
  attesaApplica = setTimeout(() => invia('anteprima', { dati: stato.dati }), 40);
}

/* --------------------------------------------------------------------------
   Azioni
   -------------------------------------------------------------------------- */
$('conferma').addEventListener('click', () => {
  invia('conferma', { dati: stato.dati, costo: stato.costo });
  document.body.classList.add('oculto');
});

$('annulla').addEventListener('click', () => {
  invia('annulla', {});
  document.body.classList.add('oculto');
});

document.addEventListener('keydown', (e) => {
  if (document.body.classList.contains('oculto')) return;
  if (e.key === 'Escape') $('annulla').click();
});

/* --------------------------------------------------------------------------
   Ingresso
   -------------------------------------------------------------------------- */
window.addEventListener('message', ({ data }) => {
  if (data.azione === 'apri') {
    stato = {
      modalita: data.modalita,
      dati: data.dati,
      schede: data.schede,
      schedaAttiva: data.schede[0]?.id,
      componenti: data.componenti,
      accessori: data.accessori,
      sovrapposizioni: data.sovrapposizioni,
      tratti: data.tratti,
      zoneTatuaggi: data.zoneTatuaggi,
      tatuaggiDisponibili: data.tatuaggiDisponibili,
      tatuaggiIniziali: (data.dati.tatuaggi || []).length,
      massimi: data.massimi,
      prezzi: data.prezzi,
      costo: 0,
    };
    modificati.clear();

    $('titolo').textContent = data.titolo || 'Aspetto';
    $('sottotitolo').textContent = data.sottotitolo || '';
    $('costo').textContent = euro(0);

    disegnaSchede();
    disegnaControlli();
    document.body.classList.remove('oculto');

  } else if (data.azione === 'chiudi') {
    document.body.classList.add('oculto');

  } else if (data.azione === 'massimi') {
    stato.massimi = data.massimi;
    disegnaControlli();
  }
});
