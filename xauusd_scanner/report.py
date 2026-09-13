"""Generazione della heatmap HTML.

Il report e' un singolo file autonomo: dati incorporati come JSON, nessuna
dipendenza esterna, nessuna chiamata di rete. Si apre con un doppio click e
funziona anche offline.
"""

from __future__ import annotations

import html
import json
from datetime import datetime
from typing import Dict, List, Sequence

from .backtest import Costs
from .data import Series
from .scanner import ScanRow, summarize

_CSS = """
:root{
  --bg:#0b0f16; --panel:#121826; --panel-2:#0f1522; --line:#1f2a3c;
  --text:#e6edf7; --muted:#8ba0bd; --accent:#f2b53a;
  --pos:#16c47f; --neg:#ef4a5a;
}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--text);
  font:14px/1.45 ui-sans-serif,-apple-system,"Segoe UI",Roboto,Helvetica,Arial,sans-serif;}
a{color:var(--accent)}
.wrap{padding:20px 18px 64px;max-width:1800px;margin:0 auto}
header h1{margin:0 0 4px;font-size:22px;letter-spacing:.2px}
header h1 span{color:var(--accent)}
.sub{color:var(--muted);font-size:13px;margin-bottom:14px}
.warn{background:#3a2a08;border:1px solid #6b4d0d;color:#ffd77a;
  padding:8px 12px;border-radius:8px;font-size:12.5px;margin:10px 0 16px}
.cards{display:grid;grid-template-columns:repeat(auto-fit,minmax(150px,1fr));gap:10px;margin-bottom:16px}
.card{background:var(--panel);border:1px solid var(--line);border-radius:10px;padding:10px 12px}
.card .k{color:var(--muted);font-size:11px;text-transform:uppercase;letter-spacing:.06em}
.card .v{font-size:19px;font-weight:650;margin-top:3px}
.toolbar{display:flex;flex-wrap:wrap;gap:10px;align-items:center;
  background:var(--panel-2);border:1px solid var(--line);border-radius:10px;padding:10px 12px;margin-bottom:14px}
.toolbar label{color:var(--muted);font-size:12px;display:flex;gap:6px;align-items:center}
select,input[type=search],input[type=number]{background:#0b1220;color:var(--text);
  border:1px solid var(--line);border-radius:7px;padding:6px 8px;font-size:13px;min-width:0}
input[type=search]{flex:1 1 180px;min-width:140px}
.legend{display:flex;align-items:center;gap:8px;color:var(--muted);font-size:12px;margin-left:auto}
.bar{width:150px;height:10px;border-radius:5px;
  background:linear-gradient(90deg,#8b1b27,#ef4a5a,#2a3446,#16c47f,#0c7a53)}
h2{font-size:15px;margin:18px 0 8px;color:var(--muted);font-weight:600;
  text-transform:uppercase;letter-spacing:.08em}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(180px,1fr));gap:8px}
.tile{border:1px solid var(--line);border-radius:9px;padding:9px 10px;cursor:pointer;
  min-height:86px;display:flex;flex-direction:column;justify-content:space-between;
  transition:transform .08s ease,border-color .08s ease}
.tile:hover{transform:translateY(-2px);border-color:#3c526f}
.tile .nm{font-size:12px;font-weight:650;line-height:1.25;
  overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.tile .ex{font-size:10.5px;color:#a9bdd8;opacity:.85;margin-top:1px}
.tile .big{font-size:19px;font-weight:750;letter-spacing:-.3px;margin:4px 0 1px}
.tile .cash{font-size:11.5px;opacity:.85}
.tile .meta{font-size:10px;opacity:.72;margin-top:3px;
  overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.tile .flag{font-size:9.5px;font-weight:700;letter-spacing:.05em;
  border-radius:4px;padding:1px 5px;display:inline-block;margin-top:4px}
.flag.long{background:rgba(22,196,127,.18);color:#5ef0b4;border:1px solid rgba(22,196,127,.45)}
.flag.short{background:rgba(239,74,90,.18);color:#ff93a0;border:1px solid rgba(239,74,90,.45)}
.flag.fresh{box-shadow:0 0 0 1px rgba(255,255,255,.25) inset}
/* le tabelle sono le uniche a poter eccedere in larghezza: scorrono da sole */
.tbl{overflow-x:auto;-webkit-overflow-scrolling:touch}
table{border-collapse:collapse;width:100%;font-size:12.5px}
th,td{padding:5px 8px;border-bottom:1px solid var(--line);text-align:right;white-space:nowrap}
th:first-child,td:first-child{text-align:left}
th{color:var(--muted);font-weight:600;font-size:11px;text-transform:uppercase;letter-spacing:.05em}
.pos{color:var(--pos)} .neg{color:var(--neg)}
.drawer{position:fixed;top:0;right:0;height:100%;width:min(520px,100%);background:var(--panel);
  border-left:1px solid var(--line);padding:18px;overflow:auto;transform:translateX(102%);
  transition:transform .18s ease;z-index:20;box-shadow:-20px 0 40px rgba(0,0,0,.45)}
.drawer.open{transform:none}
.drawer h3{margin:0 0 2px;font-size:16px}
.drawer .close{position:absolute;top:12px;right:14px;background:none;border:none;
  color:var(--muted);font-size:22px;cursor:pointer;line-height:1}
.kv{display:grid;grid-template-columns:1fr 1fr;gap:6px 14px;margin:12px 0}
.kv div{display:flex;justify-content:space-between;border-bottom:1px solid var(--line);padding:3px 0;font-size:12.5px}
.kv span:first-child{color:var(--muted)}
footer{margin-top:30px;color:var(--muted);font-size:12px;border-top:1px solid var(--line);padding-top:14px}
footer code{background:#0b1220;padding:1px 5px;border-radius:4px}
.empty{color:var(--muted);padding:26px;text-align:center;border:1px dashed var(--line);border-radius:10px}
@media (max-width:640px){.wrap{padding:14px 12px 48px}.grid{grid-template-columns:repeat(auto-fill,minmax(150px,1fr))}}
"""

_JS = """
const MET = {
  total_r:{label:'R totale', fmt:v=>(v>=0?'+':'')+v.toFixed(1)+'R', scale:14},
  score:{label:'Robustness score', fmt:v=>v.toFixed(0), scale:50, mid:50},
  oos_r:{label:'R fuori campione', fmt:v=>(v>=0?'+':'')+v.toFixed(1)+'R', scale:6},
  expectancy_r:{label:'Aspettativa (R/trade)', fmt:v=>(v>=0?'+':'')+v.toFixed(2)+'R', scale:0.35},
  profit_factor:{label:'Profit factor', fmt:v=>v.toFixed(2), scale:1, mid:1},
  net_pnl:{label:'P&L netto', fmt:v=>(v>=0?'+$':'-$')+Math.abs(v).toFixed(0), scale:1400},
};
const state = {metric:'total_r', family:'*', minTrades:MIN_TRADES, q:'', sort:'metric', signals:'*'};

const val = (r,m) => m==='oos_r' ? (r.oos.total_r||0) : (m==='score' ? r.score : (r.stats[m]||0));

function color(v, m){
  const cfg = MET[m], mid = cfg.mid||0;
  let t = Math.max(-1, Math.min(1, (v-mid)/cfg.scale));
  if (!isFinite(t)) t = 1;
  const a = Math.abs(t);
  // verde in profitto, rosso in perdita, grigio-blu vicino allo zero
  const hue = t>=0 ? 152 : 352;
  const sat = 18 + 52*a, light = 15 + 26*a;
  return {bg:`hsl(${hue} ${sat}% ${light}%)`, bd:`hsl(${hue} ${sat+10}% ${light+14}%)`,
          fg: a>0.55 ? '#ffffff' : '#dbe6f5'};
}

function passes(r){
  if (state.family!=='*' && r.family!==state.family) return false;
  if (r.stats.trades < state.minTrades) return false;
  if (state.signals==='live' && !r.signal_now) return false;
  if (state.signals==='fresh' && r.bars_since_signal!==0) return false;
  if (state.q && !(r.key.toLowerCase().includes(state.q))) return false;
  return true;
}

function render(){
  const rows = ROWS.filter(passes);
  rows.sort((a,b)=>{
    if (state.sort==='trades') return b.stats.trades-a.stats.trades;
    if (state.sort==='score') return b.score-a.score;
    return val(b,state.metric)-val(a,state.metric);
  });
  const grid = document.getElementById('grid');
  document.getElementById('count').textContent =
    rows.length+' varianti mostrate · '+rows.filter(r=>val(r,state.metric)>0).length+' in positivo';
  if (!rows.length){ grid.innerHTML = '<div class="empty">Nessuna variante supera i filtri.</div>'; return; }
  grid.innerHTML = rows.map((r,i)=>{
    const v = val(r, state.metric), c = color(v, state.metric);
    const wr = r.stats.win_rate.toFixed(0), n = r.stats.trades.toFixed(0);
    const pf = isFinite(r.stats.profit_factor) ? r.stats.profit_factor.toFixed(2) : '∞';
    const side = r.signal_now>0 ? 'long' : 'short';
    const age = r.bars_since_signal;
    const txt = age===0 ? (r.signal_now>0?'LONG ora':'SHORT ora')
                        : (r.signal_now>0?'LONG da '+age+'b':'SHORT da '+age+'b');
    const flag = r.signal_now ? `<div class="flag ${side}${age===0?' fresh':''}">${txt}</div>` : '';
    return `<div class="tile" data-i="${ROWS.indexOf(r)}" style="background:${c.bg};border-color:${c.bd};color:${c.fg}">
      <div>
        <div class="nm" title="${r.key}">${r.name}</div>
        <div class="ex">${r.exits}</div>
      </div>
      <div>
        <div class="big">${MET[state.metric].fmt(v)}</div>
        <div class="cash">${r.stats.net_pnl>=0?'+':'-'}$${Math.abs(r.stats.net_pnl).toFixed(0)} · score ${r.score.toFixed(0)}</div>
        <div class="meta">${wr}% win · ${n} trade · PF ${pf}</div>
        ${flag}
      </div>
    </div>`;
  }).join('');
}

function spark(values, w=460, h=90){
  if (!values.length) return '';
  const min = Math.min(...values), max = Math.max(...values), span = (max-min)||1;
  const pts = values.map((v,i)=>[ (i/(values.length-1||1))*w, h - ((v-min)/span)*(h-8) - 4 ]);
  const d = pts.map((p,i)=>(i?'L':'M')+p[0].toFixed(1)+' '+p[1].toFixed(1)).join(' ');
  const up = values[values.length-1] >= values[0];
  const stroke = up ? '#16c47f' : '#ef4a5a';
  return `<svg viewBox="0 0 ${w} ${h}" width="100%" height="${h}" role="img" aria-label="curva equity">
    <path d="${d}" fill="none" stroke="${stroke}" stroke-width="2"/>
  </svg>`;
}

function openDrawer(i){
  const r = ROWS[i], d = document.getElementById('drawer');
  const s = r.stats, o = r.oos||{};
  const num = (v,dec=2)=> (v===undefined||v===null||!isFinite(v)) ? '—' : v.toFixed(dec);
  const cls = v => v>=0 ? 'pos' : 'neg';
  d.innerHTML = `<button class="close" onclick="document.getElementById('drawer').classList.remove('open')">×</button>
    <h3>${r.name}</h3>
    <div class="sub">Uscita: ${r.exits} · famiglia ${r.family}</div>
    ${spark(r.equity_curve)}
    <div class="kv">
      <div><span>R totale</span><b class="${cls(s.total_r)}">${num(s.total_r,1)}R</b></div>
      <div><span>P&L netto</span><b class="${cls(s.net_pnl)}">$${num(s.net_pnl,0)}</b></div>
      <div><span>Trade</span><b>${num(s.trades,0)}</b></div>
      <div><span>Trade / anno</span><b>${num(s.trades_per_year,1)}</b></div>
      <div><span>Win rate</span><b>${num(s.win_rate,1)}%</b></div>
      <div><span>Profit factor</span><b>${num(s.profit_factor,2)}</b></div>
      <div><span>Aspettativa</span><b class="${cls(s.expectancy_r)}">${num(s.expectancy_r,3)}R</b></div>
      <div><span>Sharpe (sui trade)</span><b>${num(s.sharpe,2)}</b></div>
      <div><span>Media vinc.</span><b class="pos">${num(s.avg_win_r,2)}R</b></div>
      <div><span>Media perd.</span><b class="neg">${num(s.avg_loss_r,2)}R</b></div>
      <div><span>Max drawdown</span><b class="neg">${num(s.max_dd_r,1)}R (${num(s.max_dd_pct,1)}%)</b></div>
      <div><span>Perdite di fila</span><b>${num(s.max_loss_streak,0)}</b></div>
      <div><span>Recovery factor</span><b>${num(s.recovery_factor,2)}</b></div>
      <div><span>Durata media</span><b>${num(s.avg_bars,1)} bar</b></div>
      <div><span>Robustness score</span><b>${num(r.score,0)}/100</b></div>
      <div><span>Esposizione</span><b>${num(s.exposure,0)}%</b></div>
    </div>
    <h2>Fuori campione (ultimo ${OOS_PCT}% dello storico)</h2>
    <div class="kv">
      <div><span>Trade</span><b>${num(o.trades,0)}</b></div>
      <div><span>R totale</span><b class="${cls(o.total_r||0)}">${num(o.total_r,1)}R</b></div>
      <div><span>Aspettativa</span><b class="${cls(o.expectancy_r||0)}">${num(o.expectancy_r,3)}R</b></div>
      <div><span>Win rate</span><b>${num(o.win_rate,1)}%</b></div>
    </div>
    <h2>Ultimi trade</h2>
    <div class="tbl"><table><thead><tr><th>Entrata</th><th>Lato</th><th>R</th><th>Uscita</th><th>Bar</th></tr></thead><tbody>
      ${(r.last_trades||[]).slice().reverse().map(t=>`<tr>
        <td>${t.entry_time}</td><td>${t.side}</td>
        <td class="${cls(t.r)}">${t.r>=0?'+':''}${t.r.toFixed(2)}R</td>
        <td>${t.reason}</td><td>${t.bars}</td></tr>`).join('')}
    </tbody></table></div>`;
  d.classList.add('open');
}

document.addEventListener('click', e=>{
  const tile = e.target.closest('.tile');
  if (tile) openDrawer(+tile.dataset.i);
});
document.addEventListener('keydown', e=>{ if(e.key==='Escape') document.getElementById('drawer').classList.remove('open'); });
for (const [id, key, cast] of [['metric','metric',String],['family','family',String],
    ['sortby','sort',String],['signals','signals',String],['minTrades','minTrades',Number]]){
  const el = document.getElementById(id);
  el.addEventListener('input', ()=>{ state[key]=cast(el.value); render(); });
}
document.getElementById('q').addEventListener('input', e=>{ state.q=e.target.value.toLowerCase(); render(); });
render();
"""


def _fmt_dt(value) -> str:
    return value.strftime("%Y-%m-%d") if isinstance(value, datetime) else str(value)


def build_html(
    series: Series,
    rows: Sequence[ScanRow],
    costs: Costs,
    risk: float,
    min_trades: int,
    oos_fraction: float,
    title: str = "XAUUSD — trade scanner",
) -> str:
    info = summarize(rows, min_trades)
    families = sorted({r.family for r in rows})
    live = [r for r in rows if r.signal_now and r.stats.get("trades", 0) >= min_trades]
    live.sort(key=lambda r: (r.bars_since_signal or 0, -r.score))
    fresh = [r for r in live if (r.bars_since_signal or 0) == 0]
    best = max(rows, key=lambda r: r.score, default=None)
    synthetic_data = "synthetic" in (series.source or "")

    fam_rows = "".join(
        f"<tr><td>{html.escape(name)}</td><td>{b['n']}</td>"
        f"<td class=\"{'pos' if b['avg_r']>=0 else 'neg'}\">{b['avg_r']:+.2f}R</td>"
        f"<td class=\"{'pos' if b['best']>=0 else 'neg'}\">{b['best']:+.1f}R</td>"
        f"<td>{b['hit']:.0f}%</td></tr>"
        for name, b in sorted(info["by_family"].items(), key=lambda kv: kv[1]["avg_r"], reverse=True)
    )

    def _age(row: ScanRow) -> str:
        return "sull&rsquo;ultimo bar" if row.bars_since_signal == 0 else f"attivo da {row.bars_since_signal} bar"

    live_rows = "".join(
        f"<tr><td>{html.escape(r.name)}</td><td>{html.escape(r.exits)}</td>"
        f"<td class=\"{'pos' if r.signal_now>0 else 'neg'}\">{'LONG' if r.signal_now>0 else 'SHORT'}</td>"
        f"<td>{_age(r)}</td><td>{r.score:.0f}</td>"
        f"<td class=\"{'pos' if r.stats['total_r']>=0 else 'neg'}\">{r.stats['total_r']:+.1f}R</td></tr>"
        for r in live[:15]
    ) or "<tr><td colspan='6'>Nessun segnale attivo sull&rsquo;ultimo bar.</td></tr>"

    payload = []
    for r in rows:  # la serie di R serve solo via API: fuori dal JSON del report
        item = r.as_dict()
        item.pop("r_series", None)
        payload.append(item)
    data_json = json.dumps(payload, separators=(",", ":"), default=str)
    warn = (
        "<div class='warn'><b>Dati sintetici.</b> Questa scansione gira su una serie generata "
        "da seed, non su oro reale: serve solo a verificare il motore. Rilancia con "
        "<code>--csv tuo_export.csv</code> per risultati veri.</div>"
        if synthetic_data else
        "<div class='warn'>Risultati di <b>backtest</b> su dati storici, al netto di spread, "
        "slippage e commissioni indicati sopra. La performance passata non prevede quella futura: "
        "una tessera verde e' un'ipotesi da validare in demo, non un segnale operativo.</div>"
    )

    return f"""<!doctype html>
<html lang="it"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>{html.escape(title)}</title>
<style>{_CSS}</style></head>
<body><div class="wrap">
<header>
  <h1>{html.escape(series.symbol)} <span>— trade scanner</span></h1>
  <div class="sub">
    {len(rows)} varianti · {html.escape(series.timeframe)} · {len(series)} bar ·
    {_fmt_dt(series.start)} → {_fmt_dt(series.end)} · sorgente {html.escape(series.source)}<br>
    rischio 1R = ${risk:,.0f} per trade · spread ${costs.spread:g} · slippage ${costs.slippage:g} ·
    commissioni ${costs.commission_per_lot:g}/lotto · out-of-sample ultimo {oos_fraction*100:.0f}% ·
    generato il {datetime.now().strftime('%Y-%m-%d %H:%M')}
  </div>
</header>
{warn}
<div class="cards">
  <div class="card"><div class="k">Varianti in positivo</div><div class="v">{info['profitable']}/{info['eligible']} <span class="sub">({info['profitable_pct']:.0f}%)</span></div></div>
  <div class="card"><div class="k">Robuste (score ≥ 55)</div><div class="v">{info['robust']}</div></div>
  <div class="card"><div class="k">Migliore per score</div><div class="v">{best.score:.0f}<span class="sub"> — {html.escape(best.name) if best else ''}</span></div></div>
  <div class="card"><div class="k">R totale migliore</div><div class="v pos">{max((r.stats['total_r'] for r in rows), default=0):+.1f}R</div></div>
  <div class="card"><div class="k">R totale peggiore</div><div class="v neg">{min((r.stats['total_r'] for r in rows), default=0):+.1f}R</div></div>
  <div class="card"><div class="k">Scattati sull'ultimo bar</div><div class="v">{len(fresh)}<span class="sub"> / {len(live)} attivi</span></div></div>
</div>

<div class="toolbar">
  <label>Metrica
    <select id="metric">
      <option value="total_r">R totale</option>
      <option value="score">Robustness score</option>
      <option value="oos_r">R fuori campione</option>
      <option value="expectancy_r">Aspettativa per trade</option>
      <option value="profit_factor">Profit factor</option>
      <option value="net_pnl">P&amp;L netto</option>
    </select></label>
  <label>Famiglia
    <select id="family"><option value="*">tutte</option>
      {''.join(f'<option value="{html.escape(f)}">{html.escape(f)}</option>' for f in families)}
    </select></label>
  <label>Ordina
    <select id="sortby">
      <option value="metric">per metrica</option>
      <option value="score">per score</option>
      <option value="trades">per n. trade</option>
    </select></label>
  <label>Mostra
    <select id="signals"><option value="*">tutte</option><option value="fresh">scattate sull'ultimo bar</option><option value="live">segnale attivo</option></select></label>
  <label>Min trade <input id="minTrades" type="number" min="0" step="5" value="{min_trades}" style="width:72px"></label>
  <input id="q" type="search" placeholder="cerca: donchian, 2ATR, trail…">
  <div class="legend"><span>perde</span><div class="bar"></div><span>guadagna</span></div>
</div>

<h2 id="count"></h2>
<div class="grid" id="grid"></div>

<h2>Segnali attivi sull'ultimo bar</h2>
<div class="tbl"><table><thead><tr><th>Strategia</th><th>Uscita</th><th>Lato</th><th>Quando</th><th>Score</th><th>R storico</th></tr></thead>
<tbody>{live_rows}</tbody></table></div>

<h2>Rendimento per famiglia</h2>
<div class="tbl"><table><thead><tr><th>Famiglia</th><th>Varianti</th><th>R medio</th><th>Migliore</th><th>% in positivo</th></tr></thead>
<tbody>{fam_rows}</tbody></table></div>

<footer>
  <p><b>Come leggerlo.</b> Ogni tessera e' una strategia completa: famiglia + parametri + regole di uscita.
  Il colore segue la metrica scelta nella toolbar. 1R = la perdita che si subisce se lo stop viene colpito,
  quindi +7R significa sette volte il rischio di un singolo trade, indipendentemente dalla size.
  Clicca una tessera per curva equity, statistiche complete e ultimi trade.</p>
  <p><b>Regole del motore.</b> Segnale alla chiusura del bar, ingresso all'apertura del bar successivo.
  Se stop e target cadono nello stesso bar si assume colpito lo stop. I gap oltre lo stop sono eseguiti
  all'apertura. Costi applicati a ogni entrata e uscita.</p>
  <p><b>Attenzione all'overfitting.</b> Con {len(rows)} varianti testate, alcune risultano verdi per solo caso.
  Per questo la colonna fuori campione e il <i>robustness score</i> contano piu' del solo R totale.</p>
</footer>
</div>
<div class="drawer" id="drawer"></div>
<script>
const ROWS = {data_json};
const MIN_TRADES = {min_trades};
const OOS_PCT = {oos_fraction*100:.0f};
{_JS}
</script>
</body></html>"""


def write_report(path: str, **kwargs) -> str:
    html_text = build_html(**kwargs)
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(html_text)
    return path
