/* ==========================================================================
   AUREA · HUD — logica di rendering
   ========================================================================== */

const $ = (id) => document.getElementById(id);

const CIRCONFERENZA = 2 * Math.PI * 19;   // r = 19 negli SVG
const ARCO = 163;                          // lunghezza dell'arco del tachimetro

/* --------------------------------------------------------------------------
   Formattazione all'italiana
   -------------------------------------------------------------------------- */
const euro = (centesimi) =>
  (Number(centesimi || 0) / 100).toLocaleString('it-IT', {
    style: 'currency', currency: 'EUR', minimumFractionDigits: 2,
  });

/* --------------------------------------------------------------------------
   Anelli di stato
   -------------------------------------------------------------------------- */
function anello(chiave, percentuale, critico) {
  const svg = document.querySelector(`.anello[data-chiave="${chiave}"]`);
  if (!svg) return;
  const cerchio = svg.querySelector('.valore');
  const p = Math.max(0, Math.min(100, percentuale));
  cerchio.style.strokeDashoffset = CIRCONFERENZA * (1 - p / 100);
  svg.classList.toggle('critico', !!critico);
}

function aggiornaStato(d) {
  $('stato').classList.toggle('oculto', !d.visibile);
  if (!d.visibile) return;

  anello('salute',   d.salute,   d.salute < 25);
  anello('armatura', d.armatura, false);
  anello('fame',     d.fame,     d.fame < 20);
  anello('sete',     d.sete,     d.sete < 20);
  anello('stress',   d.stress,   d.stress > 75);

  const ossigeno = $('anello-ossigeno');
  ossigeno.classList.toggle('oculto', !d.subacqueo);
  if (d.subacqueo) anello('ossigeno', d.ossigeno, d.ossigeno < 30);
}

/* --------------------------------------------------------------------------
   Portafoglio
   -------------------------------------------------------------------------- */
let ultimiContanti = null;
let ultimaBanca = null;

function aggiornaPortafoglio(d) {
  $('portafoglio').classList.toggle('oculto', !d.visibile);
  if (!d.visibile) return;

  if (ultimiContanti !== null && d.contanti !== ultimiContanti) {
    mostraVariazione(d.contanti - ultimiContanti);
  } else if (ultimaBanca !== null && d.banca !== ultimaBanca) {
    mostraVariazione(d.banca - ultimaBanca);
  }
  ultimiContanti = d.contanti;
  ultimaBanca = d.banca;

  $('contanti').textContent = euro(d.contanti);
  $('banca').textContent = euro(d.banca);
  if (d.lavoro) $('lavoro').textContent = d.lavoro;
  if (d.ora) $('orologio').textContent = d.ora;
}

function mostraVariazione(delta) {
  const el = $('variazione');
  el.className = 'variazione';
  void el.offsetWidth;                       // forza il reflow per riavviare l'animazione
  el.textContent = `${delta > 0 ? '+' : '−'}${euro(Math.abs(delta))}`;
  el.classList.add('mostra', delta > 0 ? 'piu' : 'meno');
}

/* --------------------------------------------------------------------------
   Cruscotto
   -------------------------------------------------------------------------- */
function aggiornaCruscotto(d) {
  $('cruscotto').classList.toggle('oculto', !d.visibile);
  $('limite').classList.toggle('oculto', !d.visibile || !d.limite);
  if (!d.visibile) return;

  $('kmh').textContent = Math.round(d.kmh);

  const rapporto = Math.min(1, d.kmh / (d.velocitaMax || 220));
  const arco = $('arco-valore');
  arco.style.strokeDashoffset = ARCO * (1 - rapporto);
  arco.style.stroke = d.eccesso ? '#e0533d' : (d.kmh > 110 ? '#e8b53b' : '#34c17b');

  $('marcia').textContent = d.marcia;

  const carb = $('carburante');
  carb.style.height = `${Math.max(0, Math.min(100, d.carburante))}%`;
  carb.classList.toggle('critico', d.carburante < 15);

  const mot = $('motore');
  mot.style.height = `${Math.max(0, Math.min(100, d.motore))}%`;
  mot.classList.toggle('critico', d.motore < 30);

  $('spia-cinture').className = `spia ${d.cinture ? 'accesa' : 'allarme'}`;
  $('spia-fari').className = `spia ${d.fari ? 'accesa' : ''}`;
  $('spia-motore').className = `spia ${d.motore < 30 ? 'allarme' : ''}`;

  if (d.limite) {
    $('limite-valore').textContent = d.limite;
    $('limite-nota').textContent = d.limiteNota || '';
    $('limite').classList.toggle('eccesso', !!d.eccesso);
  }
}

/* --------------------------------------------------------------------------
   ZTL e patente
   -------------------------------------------------------------------------- */
function aggiornaZtl(d) {
  const el = $('ztl');
  el.classList.toggle('oculto', !d.dentro);
  if (!d.dentro) return;
  el.classList.toggle('autorizzato', !!d.autorizzato);
  $('ztl-nome').textContent = d.nome || 'Zona a Traffico Limitato';
  $('ztl-stato').textContent = d.autorizzato
    ? 'Permesso valido — transito consentito'
    : (d.attiva ? 'Varco attivo — transito sanzionabile' : 'Varco non attivo in questa fascia oraria');
}

function aggiornaPatente(d) {
  const el = $('patente');
  el.classList.toggle('oculto', !d.visibile);
  if (!d.visibile) return;
  $('patente-punti').textContent = d.punti;
  el.className = `patente${d.punti <= 5 ? ' critica' : d.punti <= 10 ? ' attenzione' : ''}`;
}

/* --------------------------------------------------------------------------
   Ingresso messaggi
   -------------------------------------------------------------------------- */
window.addEventListener('message', ({ data }) => {
  switch (data.azione) {
    case 'stato':       aggiornaStato(data); break;
    case 'portafoglio': aggiornaPortafoglio(data); break;
    case 'cruscotto':   aggiornaCruscotto(data); break;
    case 'ztl':         aggiornaZtl(data); break;
    case 'patente':     aggiornaPatente(data); break;
    case 'nascondiTutto':
      ['stato', 'portafoglio', 'cruscotto', 'limite', 'ztl', 'patente']
        .forEach((id) => $(id).classList.add('oculto'));
      break;
  }
});
